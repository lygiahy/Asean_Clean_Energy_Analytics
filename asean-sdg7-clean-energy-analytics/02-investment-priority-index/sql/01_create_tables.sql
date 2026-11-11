-- =============================================================
-- MSIN0304 | Team 3 | SDG 7: Affordable and Clean Energy
-- File: 01_create_tables.sql
-- Purpose: Create all staging and core tables in SQLite
-- Run first on a fresh database: sqlite3 team3_sdg7.db
-- =============================================================

-- Dimension table: 8 countries with income classification
CREATE TABLE IF NOT EXISTS dim_country (
    country_code          TEXT PRIMARY KEY,  -- ISO 3166-1 alpha-3
    country_name          TEXT NOT NULL,
    income_classification TEXT NOT NULL      -- World Bank income group
);

-- Fact spine: one row per country-year (8 x 7 = 56 rows)
-- This is the join anchor for all four slices
CREATE TABLE IF NOT EXISTS fact_spine (
    country_code  TEXT    NOT NULL,
    year          INTEGER NOT NULL,
    PRIMARY KEY (country_code, year),
    FOREIGN KEY (country_code) REFERENCES dim_country(country_code)
);

-- Staging: Slice 1 - Renewable energy (IRENA + World Bank WDI)
CREATE TABLE IF NOT EXISTS stg_renewable (
    country_code                   TEXT    NOT NULL,
    year                           INTEGER NOT NULL,
    elec_access_pct_wdi_annual     REAL,   -- % population with electricity (WDI annual)
    electricity_consumption_kwh_pc REAL,   -- kWh per capita
    population_total_count         INTEGER,-- raw person count (not millions)
    renewable_output_pct_wdi       REAL,   -- % of electricity from renewables (WDI)
    biogas_capacity_mw             REAL,   -- installed capacity MW
    geothermal_capacity_mw         REAL,
    hydro_capacity_mw              REAL,
    offshore_wind_capacity_mw      REAL,
    solar_capacity_mw              REAL,
    wind_capacity_mw               REAL,
    total_re_capacity_mw           REAL,   -- sum of all above technologies
    re_capacity_share_pct          REAL,   -- RE share of total installed capacity (IRENA)
    PRIMARY KEY (country_code, year)
);

-- Staging: Slice 3 - Grid infrastructure (World Bank WDI)
CREATE TABLE IF NOT EXISTS stg_grid (
    country_code            TEXT    NOT NULL,
    year                    INTEGER NOT NULL,
    energy_intensity_mj_gdp REAL,   -- MJ per USD 2021 PPP GDP
    td_losses_pct           REAL,   -- T&D losses as % of electricity output
    PRIMARY KEY (country_code, year)
);

-- Staging: Slice 4 - Economic context (IMF + World Bank WDI/WBGI)
CREATE TABLE IF NOT EXISTS stg_economic (
    country_code            TEXT    NOT NULL,
    year                    INTEGER NOT NULL,
    gdp_growth_pct          REAL,   -- annual real GDP growth (IMF WEO)
    gdp_per_capita_usd      REAL,   -- GDP per capita, current USD (IMF WEO)
    fdi_usd_millions        REAL,   -- net FDI inflows in USD millions (WDI)
    regulatory_quality_wbgi REAL,   -- World Bank Governance Indicators score
    PRIMARY KEY (country_code, year)
);

-- Staging: Slice 2 - Energy access (IEA, 2015 and 2022 snapshots only)
-- Note: IEA data has no annual grain. Joined as static context per country.
CREATE TABLE IF NOT EXISTS stg_access (
    country_code                      TEXT PRIMARY KEY,
    elec_access_2015_pct_iea          REAL,
    elec_access_2022_pct_iea          REAL,
    elec_access_2022_urban_pct_iea    REAL,
    elec_access_2022_rural_pct_iea    REAL,
    elec_access_improve_pp_iea        REAL,   -- percentage point change 2015 to 2022
    pop_without_elec_access_2022m_iea REAL,   -- millions of people without access
    cooking_access_2015_pct_iea       REAL,
    cooking_access_2022_pct_iea       REAL,
    cooking_access_improve_pp_iea     REAL,
    pop_without_cooking_2022m_iea     REAL,
    pop_biomass_2022m_iea             REAL,   -- millions using traditional biomass
    approx_elec_access_2022           INTEGER,-- 1 = value substituted from >99% to 99
    approx_cooking_access_2015        INTEGER,-- 1 = value substituted from <5% to 3
    approx_pop_without_elec_2022      INTEGER -- 1 = value substituted from <1 to 0.5
);
