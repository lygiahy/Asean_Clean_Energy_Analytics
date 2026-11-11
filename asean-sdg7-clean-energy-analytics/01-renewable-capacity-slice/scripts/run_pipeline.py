"""
Rebuild the renewable-capacity slice end to end with Python's built-in sqlite3.

Equivalent to the manual sqlite3 CLI steps documented in sql/01_create_tables.sql,
but runnable with a single command and no extra install:

    python scripts/run_pipeline.py            # build DB, export CSVs, print checks
    python scripts/run_pipeline.py --check    # also diff exports against data/processed/

Steps
  1. Create schema                  (sql/01_create_tables.sql)
  2. Load raw IRENA + World Bank    (data/raw/*.csv -> staging tables)
  3. Clean and unpivot              (sql/02_data_cleaning.sql)
  4. Aggregate and compute growth   (sql/03_analysis_queries.sql)
  5. Bridge queries                 (sql/04_bridge_query.sql)
  6. Export clean tables            (output/*.csv)
"""
from __future__ import annotations

import argparse
import csv
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
RAW_DIR = ROOT / "data" / "raw"
PROCESSED_DIR = ROOT / "data" / "processed"
OUT_DIR = ROOT / "output"
DB_PATH = OUT_DIR / "sdg7_renewable.db"

EXPORTS = {
    "renewable_capacity_clean.csv": (
        "SELECT iso_code, country_name, year, technology, technology_group, "
        "capacity_mw, capacity_gw FROM renewable_capacity ORDER BY iso_code, year, technology"
    ),
    "renewable_summary.csv": (
        "SELECT iso_code, country_name, year, total_renewable_mw, total_renewable_gw, "
        "solar_mw, wind_mw, hydro_mw, other_mw, solar_share_pct, wind_share_pct, "
        "hydro_share_pct FROM renewable_summary ORDER BY iso_code, year"
    ),
    "renewable_growth.csv": (
        "SELECT iso_code, country_name, year, total_renewable_mw, prev_year_mw, "
        "absolute_growth_mw, yoy_growth_pct, cumulative_growth_since_2015_pct "
        "FROM renewable_growth ORDER BY iso_code, year"
    ),
    "worldbank_indicators_clean.csv": (
        "SELECT iso_code, country_name, year, population, electrification_rate_pct, "
        "renewable_elec_share_pct, elec_consumption_kwh_pc "
        "FROM worldbank_context ORDER BY iso_code, year"
    ),
}


def read_irena(path: Path) -> list[list[str]]:
    """IRENA exports carry a title line and a blank line before the header."""
    with path.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))
    header_idx = next(i for i, r in enumerate(rows) if r and r[0] == "Country/area")
    return [r for r in rows[header_idx + 1:] if len(r) == 6]


def read_worldbank(path: Path) -> list[list[str]]:
    """World Bank DataBank exports end with blank rows and a metadata footer."""
    with path.open(newline="", encoding="utf-8-sig") as f:
        rows = list(csv.reader(f))
    return [r for r in rows[1:] if len(r) >= 14 and len(r[1]) == 3]


def run_script(conn: sqlite3.Connection, path: Path, show: bool) -> None:
    """Run a SQL file statement by statement so validation SELECTs are printed."""
    sql = path.read_text(encoding="utf-8")
    buffer = ""
    for line in sql.splitlines(keepends=True):
        buffer += line
        if sqlite3.complete_statement(buffer):
            stmt = buffer.strip()
            buffer = ""
            cur = conn.execute(stmt)
            rows = cur.fetchall() if cur.description else []
            if show and rows and "validation" in [d[0] for d in cur.description]:
                for (msg,) in rows:
                    print(f"    {msg}")
            elif show and rows and cur.description[0][0] == "status":
                print(f"    {rows[0][0]}")
    conn.commit()


def export(conn: sqlite3.Connection) -> None:
    for name, query in EXPORTS.items():
        cur = conn.execute(query)
        with (OUT_DIR / name).open("w", newline="", encoding="utf-8") as f:
            w = csv.writer(f)
            w.writerow([d[0] for d in cur.description])
            w.writerows(cur.fetchall())
        print(f"  exported output/{name}")


def _same(a: str, b: str, tol: float) -> bool:
    if a == b:
        return True
    try:
        return abs(float(a) - float(b)) <= tol
    except ValueError:
        return False


def compare(tolerance: float = 0.011) -> bool:
    """Compare fresh exports with the committed data/processed/ files."""
    ok = True
    for name in EXPORTS:
        with (OUT_DIR / name).open() as f:
            new = list(csv.reader(f))[1:]
        with (PROCESSED_DIR / name).open() as f:
            old = list(csv.reader(f))[1:]
        n_key = 4 if name.startswith("renewable_capacity") else 3
        new_rows = {tuple(r[:n_key]): r for r in new}
        old_rows = {tuple(r[:n_key]): r for r in old}
        diffs = len(new_rows.keys() ^ old_rows.keys())
        for k in new_rows.keys() & old_rows.keys():
            diffs += sum(not _same(a, b, tolerance) for a, b in zip(new_rows[k], old_rows[k]))
        print(f"  {name}: {len(new_rows)} rows, " + ("match" if diffs == 0 else f"{diffs} differences"))
        ok &= diffs == 0
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[1])
    parser.add_argument("--check", action="store_true",
                        help="compare exports with data/processed/ and exit non-zero on mismatch")
    args = parser.parse_args()

    OUT_DIR.mkdir(exist_ok=True)
    DB_PATH.unlink(missing_ok=True)
    conn = sqlite3.connect(DB_PATH)

    print("[1/6] Creating schema")
    run_script(conn, SQL_DIR / "01_create_tables.sql", show=True)

    print("[2/6] Loading raw CSVs")
    irena = read_irena(RAW_DIR / "irena_electricity_statistics.csv")
    conn.executemany("INSERT INTO raw_electricity_stats VALUES (?,?,?,?,?,?)", irena)
    wb = read_worldbank(RAW_DIR / "worldbank_wdi_asean.csv")
    conn.executemany(f"INSERT INTO raw_worldbank_wdi VALUES ({','.join('?' * 14)})",
                     [r[:14] for r in wb])
    conn.commit()
    print(f"    raw_electricity_stats: {len(irena)} rows | raw_worldbank_wdi: {len(wb)} rows")

    for step, script in [("3/6", "02_data_cleaning.sql"),
                         ("4/6", "03_analysis_queries.sql"),
                         ("5/6", "04_bridge_query.sql")]:
        print(f"[{step}] Running {script}")
        run_script(conn, SQL_DIR / script, show=True)

    print("[6/6] Exporting tables")
    export(conn)
    conn.close()
    print(f"Database written to {DB_PATH.relative_to(ROOT)}")

    if args.check:
        print("Comparing with data/processed/")
        return 0 if compare() else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
