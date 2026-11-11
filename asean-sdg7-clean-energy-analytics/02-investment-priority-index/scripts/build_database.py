"""
Build the integrated SQLite database and the Clean Energy Investment Priority Index
from the cleaned slice CSVs in data/processed/.

    python scripts/build_database.py            # build DB, export CSVs, print QC
    python scripts/build_database.py --check    # also diff exports against data/processed/

Pipeline
  1. sql/01_create_tables.sql   dim_country, fact_spine, four staging tables
  2. import clean_slice*.csv    -> raw_* tables
  3. sql/02_load_data.sql       raw_* -> dim/spine/staging
  4. sql/03_integration.sql     v_integrated_master (56 rows = 8 countries x 2015-2021)
  5. sql/05_priority_index.sql  v_index_normalised, v_priority_index + sensitivity checks
  6. sql/04_qc_checks.sql       15 QC checks (needs the index views, so it runs last)
  7. export                     output/integrated_master_*.csv

This replaces the build stage of the original 00_clean_raw_data.py, which ran
02_load_data.sql before the raw_* tables existed and stopped with
"no such table: raw_income".
"""
from __future__ import annotations

import argparse
import sqlite3
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
SQL_DIR = ROOT / "sql"
DATA_DIR = ROOT / "data" / "processed"
OUT_DIR = ROOT / "output"
DB_PATH = OUT_DIR / "team3_sdg7.db"

RAW_IMPORTS = {
    "raw_income": "clean_slice4_income_classification.csv",
    "raw_renewable": "clean_slice1_renewable.csv",
    "raw_grid": "clean_slice3_grid.csv",
    "raw_economic": "clean_slice4_economic.csv",
    "raw_access": "clean_slice2_access.csv",
}
INDEX_COLS = ["component_impact", "component_readiness", "component_viability", "priority_index"]


def statements(path: Path):
    buffer = ""
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        buffer += line
        if sqlite3.complete_statement(buffer):
            yield buffer.strip()
            buffer = ""


def run_script(conn: sqlite3.Connection, path: Path, show_results: bool = False) -> None:
    for stmt in statements(path):
        body = "\n".join(l for l in stmt.splitlines() if not l.strip().startswith("--")).strip()
        if show_results and body.upper().startswith("SELECT"):
            df = pd.read_sql_query(body, conn)
            label = df.iloc[0, 0] if "check_id" in df.columns else None
            print(f"\n  -- {label or 'result'}")
            print(df.to_string(index=False))
        else:
            conn.execute(stmt).fetchall()
    conn.commit()


def compare() -> bool:
    ok = True
    for name in ["integrated_master_from_sql.csv", "integrated_master_with_index.csv"]:
        new = pd.read_csv(OUT_DIR / name)
        old = pd.read_csv(DATA_DIR / name)
        try:
            pd.testing.assert_frame_equal(new, old, check_dtype=False, atol=0.051)
            print(f"  {name}: {new.shape[0]} rows x {new.shape[1]} cols, match")
        except AssertionError as e:
            ok = False
            print(f"  {name}: MISMATCH\n{e}")
    return ok


def main() -> int:
    parser = argparse.ArgumentParser(description="Build Team 3 SDG7 database and index")
    parser.add_argument("--check", action="store_true",
                        help="compare exports with data/processed/ and exit non-zero on mismatch")
    parser.add_argument("--quiet", action="store_true", help="do not print QC tables")
    args = parser.parse_args()

    OUT_DIR.mkdir(exist_ok=True)
    DB_PATH.unlink(missing_ok=True)
    conn = sqlite3.connect(DB_PATH)

    print("[1/7] Creating tables")
    run_script(conn, SQL_DIR / "01_create_tables.sql")

    print("[2/7] Importing cleaned slices")
    for table, csv_name in RAW_IMPORTS.items():
        df = pd.read_csv(DATA_DIR / csv_name)
        df.to_sql(table, conn, if_exists="replace", index=False)
        print(f"    {csv_name} -> {table} ({len(df)} rows)")

    print("[3/7] Loading staging tables")
    run_script(conn, SQL_DIR / "02_load_data.sql", show_results=not args.quiet)

    print("\n[4/7] Building integrated view")
    run_script(conn, SQL_DIR / "03_integration.sql")

    print("[5/7] Computing priority index")
    run_script(conn, SQL_DIR / "05_priority_index.sql", show_results=not args.quiet)

    print("\n[6/7] Running QC checks")
    run_script(conn, SQL_DIR / "04_qc_checks.sql", show_results=not args.quiet)

    print("\n[7/7] Exporting")
    master = pd.read_sql_query("SELECT * FROM v_integrated_master", conn)
    master.to_csv(OUT_DIR / "integrated_master_from_sql.csv", index=False)
    index = pd.read_sql_query("SELECT * FROM v_priority_index", conn)
    final = master.merge(index[["country_code", "year", *INDEX_COLS]],
                         on=["country_code", "year"], how="left")
    final.to_csv(OUT_DIR / "integrated_master_with_index.csv", index=False)
    conn.close()
    print(f"    output/integrated_master_from_sql.csv ({master.shape[0]} x {master.shape[1]})")
    print(f"    output/integrated_master_with_index.csv ({final.shape[0]} x {final.shape[1]})")
    print(f"    database: {DB_PATH.relative_to(ROOT)}")

    if args.check:
        print("Comparing with data/processed/")
        return 0 if compare() else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
