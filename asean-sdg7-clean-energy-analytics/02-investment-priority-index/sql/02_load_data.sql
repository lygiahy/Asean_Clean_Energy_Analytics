-- =============================================================
-- MSIN0304 | Team 3 | SDG 7: Affordable and Clean Energy
-- File: 02_load_data.sql
-- Purpose: Move data from imported raw CSV tables into
--          staging tables. Run AFTER importing CSVs via
--          DB Browser for SQLite (File > Import > Table from CSV).
-- =============================================================

-- QUICK RUN: python scripts/build_database.py   (does every step below)
--
-- HOW TO USE THIS FILE WITH DB BROWSER FOR SQLITE:
--
-- Step 1: Open DB Browser. Click "New Database".
--         Save it as: team3_sdg7.db
--
-- Step 2: Run 01_create_tables.sql first.
--         Go to: Execute SQL tab > paste contents > Run All
--
-- Step 3: Import each clean CSV as a raw table.
--         Go to: File > Import > Table from CSV file
--         Import these files with these exact table names:
--
--         File                                   Import as table name
--         clean_slice4_income_classification.csv raw_income
--         clean_slice1_renewable.csv             raw_renewable
--         clean_slice3_grid.csv                  raw_grid
--         clean_slice4_economic.csv              raw_economic
--         clean_slice2_access.csv                raw_access
--
--         Settings for each import:
--           Tick "Column names in first line"
--           Field separator: comma
--           Click OK
--
-- Step 4: Run this file (02_load_data.sql) in the Execute SQL tab.
--
-- Step 5: Run 03_integration.sql
-- Step 6: Run 05_priority_index.sql, then 04_qc_checks.sql
-- -------------------------------------------------------


-- POPULATE dim_country from raw_income
-- Adds country_name which is not in the source file
INSERT INTO dim_country (country_code, country_name, income_classification)
SELECT
    country_code,
    CASE country_code
        WHEN 'KHM' THEN 'Cambodia'
        WHEN 'IDN' THEN 'Indonesia'
        WHEN 'LAO' THEN 'Lao PDR'
        WHEN 'MYS' THEN 'Malaysia'
        WHEN 'MMR' THEN 'Myanmar'
        WHEN 'PHL' THEN 'Philippines'
        WHEN 'THA' THEN 'Thailand'
        WHEN 'VNM' THEN 'Vietnam'
    END AS country_name,
    income_classification
FROM raw_income;


-- POPULATE fact_spine: 8 countries x 7 years = 56 rows
-- Uses a CROSS JOIN between countries and years
INSERT INTO fact_spine (country_code, year)
SELECT d.country_code, y.year
FROM dim_country d
JOIN (
    SELECT 2015 AS year UNION SELECT 2016 UNION SELECT 2017
    UNION SELECT 2018   UNION SELECT 2019 UNION SELECT 2020
    UNION SELECT 2021
) y ON 1=1;


-- POPULATE stg_renewable from raw_renewable
INSERT INTO stg_renewable
SELECT
    country_code,
    CAST(year AS INTEGER),
    elec_access_pct_wdi_annual,
    electricity_consumption_kwh_pc,
    CAST(population_total_count AS INTEGER),
    renewable_output_pct_wdi,
    biogas_capacity_mw,
    geothermal_capacity_mw,
    hydro_capacity_mw,
    offshore_wind_capacity_mw,
    solar_capacity_mw,
    wind_capacity_mw,
    total_re_capacity_mw,
    re_capacity_share_pct
FROM raw_renewable;


-- POPULATE stg_grid from raw_grid
INSERT INTO stg_grid
SELECT
    country_code,
    CAST(year AS INTEGER),
    energy_intensity_mj_gdp,
    td_losses_pct
FROM raw_grid;


-- POPULATE stg_economic from raw_economic
INSERT INTO stg_economic
SELECT
    country_code,
    CAST(year AS INTEGER),
    gdp_growth_pct,
    gdp_per_capita_usd,
    fdi_usd_millions,
    regulatory_quality_wbgi
FROM raw_economic;


-- POPULATE stg_access from raw_access
INSERT INTO stg_access
SELECT
    country_code,
    elec_access_2015_pct_iea,
    elec_access_2022_pct_iea,
    elec_access_2022_urban_pct_iea,
    elec_access_2022_rural_pct_iea,
    elec_access_improve_pp_iea,
    pop_without_elec_access_2022m_iea,
    cooking_access_2015_pct_iea,
    cooking_access_2022_pct_iea,
    cooking_access_improve_pp_iea,
    pop_without_cooking_2022m_iea,
    pop_biomass_2022m_iea,
    CAST(approx_elec_access_2022 AS INTEGER),
    CAST(approx_cooking_access_2015 AS INTEGER),
    CAST(approx_pop_without_elec_2022 AS INTEGER)
FROM raw_access;


-- VERIFY: row counts before running 03_integration.sql
-- Expected: dim_country=8, fact_spine=56, all stg tables=56, stg_access=8
SELECT 'dim_country'   AS table_name, COUNT(*) AS rows FROM dim_country
UNION ALL
SELECT 'fact_spine',   COUNT(*) FROM fact_spine
UNION ALL
SELECT 'stg_renewable',COUNT(*) FROM stg_renewable
UNION ALL
SELECT 'stg_grid',     COUNT(*) FROM stg_grid
UNION ALL
SELECT 'stg_economic', COUNT(*) FROM stg_economic
UNION ALL
SELECT 'stg_access',   COUNT(*) FROM stg_access;
