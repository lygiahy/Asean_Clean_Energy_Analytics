"""
Clean the raw source files for all four SDG 7 data slices (Team 3).

Usage:
    python scripts/clean_raw_data.py                      # clean every slice whose raw files exist
    python scripts/clean_raw_data.py --slices 1 3         # clean selected slices only
    python scripts/clean_raw_data.py --out output/clean   # write somewhere else

Expected raw layout (see data/raw/README.md):
    data/raw/slice1/  worldbank_wdi_asean.csv, irena_electricity_statistics.csv,
                      irena_renewable_share.csv
    data/raw/slice2/  Electricity_access.csv, Clean_cooking.csv
    data/raw/slice3/  Dataset 1/aa915b1f-affa-4a9b-bfd8-a6d531c801ff_Data.csv
    data/raw/slice4/  raw_gdp_growth.csv, raw_gdp_per_capita.csv, raw_fdi.csv,
                      raw_regulatory_quality.csv, raw_income_classification.csv

Outputs (default: data/processed/):
    clean_slice1_renewable.csv              (56 rows)
    clean_slice2_access.csv                 (8 rows, IEA snapshot)
    clean_slice3_grid.csv                   (56 rows)
    clean_slice4_economic.csv               (56 rows)
    clean_slice4_income_classification.csv  (8 rows)

The cleaning logic is unchanged from the team's original 00_clean_raw_data.py.
Building the SQLite database is now a separate step: scripts/build_database.py.
"""
import argparse
import io
import os
import sys

import numpy as np
import pandas as pd

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RAW_DIR = os.path.join(ROOT, 'data', 'raw')
OUT_DIR = os.path.join(ROOT, 'data', 'processed')

# ------------------------------------------------------------------
# MASTER REFERENCE: ISO country code mapping
# Every source uses different country name spellings.
# All variants map to ISO 3166-1 alpha-3 code.
# ------------------------------------------------------------------
ISO_MAP = {
    'Cambodia':                                    'KHM',
    'Indonesia':                                   'IDN',
    'Lao PDR':                                     'LAO',
    'Lao P.D.R.':                                  'LAO',
    "Lao People's Democratic Republic (the)":      'LAO',
    'Laos':                                        'LAO',
    'Malaysia':                                    'MYS',
    'Myanmar':                                     'MMR',
    'Philippines':                                 'PHL',
    'Philippines (the)':                           'PHL',
    'Thailand':                                    'THA',
    'Viet Nam':                                    'VNM',
    'Vietnam':                                     'VNM',
}

COUNTRY_NAMES = {
    'KHM': 'Cambodia',
    'IDN': 'Indonesia',
    'LAO': 'Lao PDR',
    'MYS': 'Malaysia',
    'MMR': 'Myanmar',
    'PHL': 'Philippines',
    'THA': 'Thailand',
    'VNM': 'Vietnam',
}

TARGET_CODES = list(COUNTRY_NAMES.keys())
TARGET_YEARS = list(range(2015, 2022))  # 2015 to 2021 inclusive
WDI_YEAR_COLS = [f'{y} [YR{y}]' for y in TARGET_YEARS]


# ------------------------------------------------------------------
# SLICE 1: Renewable Energy
# Sources: worldbank_wdi_asean.csv, irena_electricity_statistics.csv,
#          irena_renewable_share.csv
# ------------------------------------------------------------------
def clean_slice1():
    print("Cleaning Slice 1: Renewable Energy...")

    # --- World Bank WDI ---
    df_wdi = pd.read_csv(
        os.path.join(RAW_DIR, 'slice1', 'worldbank_wdi_asean.csv')
    )
    # Remove embedded metadata footer rows (Country Code must be 3 chars)
    df_wdi = df_wdi[df_wdi['Country Code'].str.len() == 3].copy()
    df_wdi['country_code'] = df_wdi['Country Code']
    df_wdi = df_wdi[df_wdi['country_code'].isin(TARGET_CODES)]

    # Keep these four series only
    WDI_SERIES = {
        'EG.ELC.RNEW.ZS':   'renewable_output_pct_wdi',
        'SP.POP.TOTL':       'population_total_count',
        'EG.USE.ELEC.KH.PC': 'electricity_consumption_kwh_pc',
        'EG.ELC.ACCS.ZS':    'elec_access_pct_wdi_annual',
    }
    df_wdi = df_wdi[df_wdi['Series Code'].isin(WDI_SERIES.keys())]
    year_cols = [c for c in WDI_YEAR_COLS if c in df_wdi.columns]
    df_wdi_long = df_wdi.melt(
        id_vars=['country_code', 'Series Code'],
        value_vars=year_cols,
        var_name='year_col', value_name='value'
    )
    df_wdi_long['year'] = df_wdi_long['year_col'].str.extract(r'(\d{4})').astype(int)
    df_wdi_long['value'] = pd.to_numeric(
        df_wdi_long['value'].replace('..', np.nan), errors='coerce'
    )
    df_wdi_long['metric'] = df_wdi_long['Series Code'].map(WDI_SERIES)
    df_wdi_pivot = df_wdi_long.pivot_table(
        index=['country_code', 'year'], columns='metric',
        values='value', aggfunc='first'
    ).reset_index()

    # --- IRENA Electricity Statistics (installed capacity MW) ---
    with open(os.path.join(RAW_DIR, 'slice1', 'irena_electricity_statistics.csv')) as f:
        lines = f.readlines()
    df_irena_cap = pd.read_csv(io.StringIO(''.join(lines[2:])))
    df_irena_cap.columns = [
        'country_raw', 'technology', 'data_type', 'grid_connection', 'year', 'value'
    ]
    df_irena_cap['country_code'] = df_irena_cap['country_raw'].map(ISO_MAP)
    df_irena_cap = df_irena_cap[df_irena_cap['country_code'].isin(TARGET_CODES)].copy()
    df_irena_cap['year'] = pd.to_numeric(df_irena_cap['year'], errors='coerce').astype('Int64')
    df_irena_cap = df_irena_cap[df_irena_cap['year'].isin(TARGET_YEARS)]
    df_irena_cap = df_irena_cap[
        (df_irena_cap['data_type'] == 'Electricity Installed Capacity (MW)') &
        (df_irena_cap['grid_connection'] == 'On-grid')
    ]

    TECH_MAP = {
        'Solar photovoltaic':   'solar_capacity_mw',
        'Renewable hydropower': 'hydro_capacity_mw',
        'Onshore wind energy':  'wind_capacity_mw',
        'Biogas':               'biogas_capacity_mw',
        'Geothermal energy':    'geothermal_capacity_mw',
        'Offshore wind energy': 'offshore_wind_capacity_mw',
    }
    df_irena_cap['metric'] = df_irena_cap['technology'].map(TECH_MAP)
    df_irena_cap['value'] = pd.to_numeric(df_irena_cap['value'], errors='coerce').round(2)
    df_irena_pivot = df_irena_cap.pivot_table(
        index=['country_code', 'year'], columns='metric',
        values='value', aggfunc='sum'
    ).reset_index()

    # Fill missing technologies with 0 (absent technology = 0 MW, not unknown)
    for col in TECH_MAP.values():
        if col not in df_irena_pivot.columns:
            df_irena_pivot[col] = 0.0
        else:
            df_irena_pivot[col] = df_irena_pivot[col].fillna(0.0)

    df_irena_pivot['total_re_capacity_mw'] = (
        df_irena_pivot[list(TECH_MAP.values())].sum(axis=1).round(2)
    )

    # --- IRENA Renewable Share ---
    with open(os.path.join(RAW_DIR, 'slice1', 'irena_renewable_share.csv')) as f:
        lines = f.readlines()
    df_irena_share = pd.read_csv(io.StringIO(''.join(lines[2:])))
    df_irena_share.columns = ['country_raw', 'indicator', 'year', 'value']
    df_irena_share['country_code'] = df_irena_share['country_raw'].map(ISO_MAP)
    df_irena_share = df_irena_share[df_irena_share['country_code'].isin(TARGET_CODES)]
    df_irena_share['year'] = pd.to_numeric(
        df_irena_share['year'], errors='coerce'
    ).astype('Int64')
    df_irena_share = df_irena_share[
        (df_irena_share['year'].isin(TARGET_YEARS)) &
        (df_irena_share['indicator'] == 'RE share of electricity capacity (%)')
    ][['country_code', 'year', 'value']].rename(
        columns={'value': 're_capacity_share_pct'}
    )
    df_irena_share['re_capacity_share_pct'] = pd.to_numeric(
        df_irena_share['re_capacity_share_pct'], errors='coerce'
    ).round(2)

    # --- Merge Slice 1 ---
    s1 = df_wdi_pivot.merge(df_irena_pivot, on=['country_code', 'year'], how='left')
    s1 = s1.merge(df_irena_share, on=['country_code', 'year'], how='left')
    s1 = s1.sort_values(['country_code', 'year']).reset_index(drop=True)
    assert len(s1) == 56, f"Slice 1 expected 56 rows, got {len(s1)}"
    s1.to_csv(os.path.join(OUT_DIR, 'clean_slice1_renewable.csv'), index=False)
    print(f"  Saved clean_slice1_renewable.csv ({len(s1)} rows, {len(s1.columns)} columns)")


# ------------------------------------------------------------------
# SLICE 2: Energy Access (IEA, snapshot endpoints only)
# Sources: Electricity_access.csv, Clean_cooking.csv
# Note: IEA provides 2015 and 2022 snapshots only, not annual data.
# ------------------------------------------------------------------
def clean_slice2():
    print("Cleaning Slice 2: Energy Access...")

    def clean_pct(val):
        """
        Convert IEA string percentage values to numeric.
        Substitution rules (documented as assumptions):
          >99%  -> 99   (ceiling; reflects measurement uncertainty near universal access)
          <5%   -> 3    (midpoint of 0 to 5 range)
          >95%  -> 96   (floor at 96)
          <1    -> 0.5  (midpoint of 0 to 1 range)
        """
        if pd.isna(val):
            return np.nan
        s = str(val).strip()
        if s in ('>99%', '>99'):   return 99.0
        if s in ('<5%', '<5'):     return 3.0
        if s in ('>95%', '>95'):   return 96.0
        if s in ('<1', '<1%'):     return 0.5
        return pd.to_numeric(s.replace('%', '').strip(), errors='coerce')

    df_elec = pd.read_csv(
        os.path.join(RAW_DIR, 'slice2', 'Electricity_access.csv')
    )
    df_elec = df_elec[['geo_name', '2015_pct', '2022_pct', '2022_urban',
                        '2022_rural', '2022_population_without_access(million) ']].copy()
    df_elec.columns = [
        'geo_name', 'elec_access_2015_pct_iea', 'elec_access_2022_pct_iea',
        'elec_access_2022_urban_pct_iea', 'elec_access_2022_rural_pct_iea',
        'pop_without_elec_access_2022m_iea'
    ]
    df_elec['country_code'] = df_elec['geo_name'].map(
        {**ISO_MAP, 'Laos': 'LAO'}
    )
    df_elec = df_elec[df_elec['country_code'].isin(TARGET_CODES)].copy()
    for col in ['elec_access_2015_pct_iea', 'elec_access_2022_pct_iea',
                'elec_access_2022_urban_pct_iea', 'elec_access_2022_rural_pct_iea']:
        df_elec[col] = df_elec[col].apply(clean_pct)
    df_elec['pop_without_elec_access_2022m_iea'] = df_elec[
        'pop_without_elec_access_2022m_iea'
    ].apply(lambda x: 0.5 if str(x).strip() == '<1' else
            pd.to_numeric(str(x).strip(), errors='coerce'))
    df_elec['elec_access_improve_pp_iea'] = (
        df_elec['elec_access_2022_pct_iea'] - df_elec['elec_access_2015_pct_iea']
    ).round(1)

    df_cook = pd.read_csv(
        os.path.join(RAW_DIR, 'slice2', 'Clean_cooking.csv')
    )
    df_cook = df_cook[[
        'geo_name', '2015_pct', '2022_pct',
        '2022_population_without_access(million)',
        '2022_population_traditional_biomass(million)'
    ]].copy()
    df_cook.columns = [
        'geo_name', 'cooking_access_2015_pct_iea', 'cooking_access_2022_pct_iea',
        'pop_without_cooking_2022m_iea', 'pop_biomass_2022m_iea'
    ]
    df_cook['country_code'] = df_cook['geo_name'].map(
        {**ISO_MAP, 'Laos': 'LAO'}
    )
    df_cook = df_cook[df_cook['country_code'].isin(TARGET_CODES)].copy()
    for col in ['cooking_access_2015_pct_iea', 'cooking_access_2022_pct_iea']:
        df_cook[col] = df_cook[col].apply(clean_pct)
    for col in ['pop_without_cooking_2022m_iea', 'pop_biomass_2022m_iea']:
        df_cook[col] = df_cook[col].apply(
            lambda x: 0.5 if str(x).strip() == '<1' else
            pd.to_numeric(str(x).strip(), errors='coerce')
        )
    df_cook['cooking_access_improve_pp_iea'] = (
        df_cook['cooking_access_2022_pct_iea'] - df_cook['cooking_access_2015_pct_iea']
    ).round(1)

    s2 = df_elec[[
        'country_code', 'elec_access_2015_pct_iea', 'elec_access_2022_pct_iea',
        'elec_access_2022_urban_pct_iea', 'elec_access_2022_rural_pct_iea',
        'elec_access_improve_pp_iea', 'pop_without_elec_access_2022m_iea'
    ]].merge(df_cook[[
        'country_code', 'cooking_access_2015_pct_iea', 'cooking_access_2022_pct_iea',
        'cooking_access_improve_pp_iea', 'pop_without_cooking_2022m_iea',
        'pop_biomass_2022m_iea'
    ]], on='country_code', how='outer')

    # Add approximation flags: 1 = value was substituted from original string
    s2['approx_elec_access_2022']     = s2['country_code'].isin(['IDN','MYS','THA','VNM']).astype(int)
    s2['approx_cooking_access_2015']  = s2['country_code'].isin(['KHM','LAO','MMR']).astype(int)
    s2['approx_pop_without_elec_2022']= s2['country_code'].isin(['IDN','KHM','LAO','MYS','PHL','THA','VNM']).astype(int)

    s2 = s2.sort_values('country_code').reset_index(drop=True)
    assert len(s2) == 8, f"Slice 2 expected 8 rows, got {len(s2)}"
    s2.to_csv(os.path.join(OUT_DIR, 'clean_slice2_access.csv'), index=False)
    print(f"  Saved clean_slice2_access.csv ({len(s2)} rows, {len(s2.columns)} columns)")


# ------------------------------------------------------------------
# SLICE 3: Grid Infrastructure
# Source: World Bank WDI Dataset 1
#   EG.ELC.LOSS.ZS = T&D losses (% of output)
#   EG.EGY.PRIM.PP.KD = Energy intensity (MJ per USD 2021 PPP GDP)
# ------------------------------------------------------------------
def clean_slice3():
    print("Cleaning Slice 3: Grid Infrastructure...")

    df_grid = pd.read_csv(
        os.path.join(RAW_DIR, 'slice3', 'Dataset 1',
                     'aa915b1f-affa-4a9b-bfd8-a6d531c801ff_Data.csv')
    )
    # Remove embedded metadata rows
    df_grid = df_grid[df_grid['Country Code'].str.len() == 3].copy()
    df_grid['country_code'] = df_grid['Country Code']
    df_grid = df_grid[df_grid['country_code'].isin(TARGET_CODES)]

    GRID_SERIES = {
        'EG.ELC.LOSS.ZS':    'td_losses_pct',
        'EG.EGY.PRIM.PP.KD': 'energy_intensity_mj_gdp',
    }
    df_grid = df_grid[df_grid['Series Code'].isin(GRID_SERIES.keys())]
    year_cols = [c for c in WDI_YEAR_COLS if c in df_grid.columns]
    df_grid_long = df_grid.melt(
        id_vars=['country_code', 'Series Code'],
        value_vars=year_cols,
        var_name='year_col', value_name='value'
    )
    df_grid_long['year'] = df_grid_long['year_col'].str.extract(r'(\d{4})').astype(int)
    df_grid_long['value'] = pd.to_numeric(
        df_grid_long['value'].replace('..', np.nan), errors='coerce'
    )
    df_grid_long['metric'] = df_grid_long['Series Code'].map(GRID_SERIES)
    s3 = df_grid_long.pivot_table(
        index=['country_code', 'year'], columns='metric',
        values='value', aggfunc='first'
    ).reset_index()
    for col in ['td_losses_pct', 'energy_intensity_mj_gdp']:
        if col in s3.columns:
            s3[col] = s3[col].round(4)
    s3 = s3.sort_values(['country_code', 'year']).reset_index(drop=True)
    assert len(s3) == 56, f"Slice 3 expected 56 rows, got {len(s3)}"
    s3.to_csv(os.path.join(OUT_DIR, 'clean_slice3_grid.csv'), index=False)
    print(f"  Saved clean_slice3_grid.csv ({len(s3)} rows, {len(s3.columns)} columns)")


# ------------------------------------------------------------------
# SLICE 4: Economic Context
# Sources: raw_gdp_growth.csv, raw_gdp_per_capita.csv (IMF WEO)
#          raw_fdi.csv, raw_regulatory_quality.csv (World Bank WDI/WBGI)
#          raw_income_classification.csv (static)
# ------------------------------------------------------------------
def clean_slice4():
    print("Cleaning Slice 4: Economic Context...")

    def load_wide(filename, value_col_name):
        df = pd.read_csv(os.path.join(RAW_DIR, 'slice4', filename))
        country_col = df.columns[0]
        df['country_code'] = df[country_col].map(
            {**ISO_MAP, 'Lao P.D.R.': 'LAO'}
        )
        df = df[df['country_code'].isin(TARGET_CODES)]
        year_cols = [str(y) for y in TARGET_YEARS]
        df_long = df.melt(
            id_vars=['country_code'], value_vars=year_cols,
            var_name='year', value_name=value_col_name
        )
        df_long['year'] = df_long['year'].astype(int)
        df_long[value_col_name] = pd.to_numeric(
            df_long[value_col_name].replace('no data', np.nan), errors='coerce'
        )
        return df_long[['country_code', 'year', value_col_name]]

    df_gdp_growth = load_wide('raw_gdp_growth.csv', 'gdp_growth_pct')
    df_gdp_growth['gdp_growth_pct'] = df_gdp_growth['gdp_growth_pct'].round(2)

    df_gdp_pc = load_wide('raw_gdp_per_capita.csv', 'gdp_per_capita_usd')
    df_gdp_pc['gdp_per_capita_usd'] = df_gdp_pc['gdp_per_capita_usd'].round(1)

    # FDI: World Bank WDI format (different column structure)
    df_fdi = pd.read_csv(os.path.join(RAW_DIR, 'slice4', 'raw_fdi.csv'))
    df_fdi['country_code'] = df_fdi['Country Name'].map(ISO_MAP)
    df_fdi = df_fdi[df_fdi['country_code'].isin(TARGET_CODES)]
    year_cols = [str(y) for y in TARGET_YEARS]
    df_fdi_long = df_fdi.melt(
        id_vars=['country_code'], value_vars=year_cols,
        var_name='year', value_name='fdi_raw'
    )
    df_fdi_long['year'] = df_fdi_long['year'].astype(int)
    df_fdi_long['fdi_raw'] = pd.to_numeric(
        df_fdi_long['fdi_raw'].replace('..', np.nan), errors='coerce'
    )
    # Convert raw USD to USD millions
    df_fdi_long['fdi_usd_millions'] = (df_fdi_long['fdi_raw'] / 1_000_000).round(1)
    df_fdi_long = df_fdi_long[['country_code', 'year', 'fdi_usd_millions']]

    # Regulatory quality: WDI format
    df_rq = pd.read_csv(os.path.join(RAW_DIR, 'slice4', 'raw_regulatory_quality.csv'))
    df_rq = df_rq[df_rq['Country Code'].str.len() == 3].copy()
    df_rq['country_code'] = df_rq['Country Code']
    df_rq = df_rq[df_rq['country_code'].isin(TARGET_CODES)]
    rq_year_cols = [c for c in WDI_YEAR_COLS if c in df_rq.columns]
    df_rq_long = df_rq.melt(
        id_vars=['country_code'], value_vars=rq_year_cols,
        var_name='year_col', value_name='regulatory_quality_wbgi'
    )
    df_rq_long['year'] = df_rq_long['year_col'].str.extract(r'(\d{4})').astype(int)
    df_rq_long['regulatory_quality_wbgi'] = pd.to_numeric(
        df_rq_long['regulatory_quality_wbgi'].replace('..', np.nan), errors='coerce'
    ).round(4)
    df_rq_long = df_rq_long[['country_code', 'year', 'regulatory_quality_wbgi']]

    s4 = df_gdp_growth.merge(df_gdp_pc, on=['country_code', 'year'], how='outer')
    s4 = s4.merge(df_fdi_long, on=['country_code', 'year'], how='outer')
    s4 = s4.merge(df_rq_long, on=['country_code', 'year'], how='outer')
    s4 = s4.sort_values(['country_code', 'year']).reset_index(drop=True)
    assert len(s4) == 56, f"Slice 4 expected 56 rows, got {len(s4)}"
    s4.to_csv(os.path.join(OUT_DIR, 'clean_slice4_economic.csv'), index=False)
    print(f"  Saved clean_slice4_economic.csv ({len(s4)} rows, {len(s4.columns)} columns)")

    # Income classification (static, no year)
    df_income = pd.read_csv(
        os.path.join(RAW_DIR, 'slice4', 'raw_income_classification.csv')
    )
    df_income['country_code'] = df_income['country_name_raw'].map(ISO_MAP)
    df_income = df_income[df_income['country_code'].isin(TARGET_CODES)][
        ['country_code', 'income_classification']
    ].sort_values('country_code').reset_index(drop=True)
    assert len(df_income) == 8
    df_income.to_csv(os.path.join(OUT_DIR, 'clean_slice4_income_classification.csv'), index=False)
    print(f"  Saved clean_slice4_income_classification.csv ({len(df_income)} rows)")

REQUIRED = {
    1: ['worldbank_wdi_asean.csv', 'irena_electricity_statistics.csv', 'irena_renewable_share.csv'],
    2: ['Electricity_access.csv', 'Clean_cooking.csv'],
    3: [os.path.join('Dataset 1', 'aa915b1f-affa-4a9b-bfd8-a6d531c801ff_Data.csv')],
    4: ['raw_gdp_growth.csv', 'raw_gdp_per_capita.csv', 'raw_fdi.csv',
        'raw_regulatory_quality.csv', 'raw_income_classification.csv'],
}
CLEANERS = {1: clean_slice1, 2: clean_slice2, 3: clean_slice3, 4: clean_slice4}


def main():
    global RAW_DIR, OUT_DIR
    parser = argparse.ArgumentParser(description='Clean raw SDG 7 slice files')
    parser.add_argument('--slices', type=int, nargs='+', choices=[1, 2, 3, 4], default=[1, 2, 3, 4])
    parser.add_argument('--raw', default=RAW_DIR, help='raw data folder (default: data/raw)')
    parser.add_argument('--out', default=OUT_DIR, help='output folder (default: data/processed)')
    args = parser.parse_args()
    RAW_DIR, OUT_DIR = os.path.abspath(args.raw), os.path.abspath(args.out)
    os.makedirs(OUT_DIR, exist_ok=True)

    skipped = []
    for n in args.slices:
        missing = [f for f in REQUIRED[n] if not os.path.exists(os.path.join(RAW_DIR, f'slice{n}', f))]
        if missing:
            print(f"Skipping Slice {n}: raw files not found in data/raw/slice{n}/ -> {', '.join(missing)}")
            skipped.append(n)
            continue
        CLEANERS[n]()
    if skipped:
        print(f"\nSlices {skipped} were skipped; their committed clean CSVs in data/processed/ are unchanged.")
    print("Done. Next step: python scripts/build_database.py")
    return 0


if __name__ == '__main__':
    sys.exit(main())
