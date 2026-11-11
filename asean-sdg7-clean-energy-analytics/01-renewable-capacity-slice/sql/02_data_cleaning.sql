-- ============================================================================
-- Script 02: Data Cleaning and Transformation
-- Input: raw_electricity_stats (IRENA), raw_worldbank_wdi (World Bank)
-- Output: renewable_capacity, worldbank_context
-- Candidate: SRLB2
-- ============================================================================

-- ========================================
-- PART A: IRENA DATA CLEANING
-- ========================================

-- Quality check: confirm expected countries and year range
SELECT DISTINCT country_area FROM raw_electricity_stats ORDER BY country_area;
SELECT MIN(year) AS min_year, MAX(year) AS max_year, COUNT(DISTINCT year) AS year_count
FROM raw_electricity_stats;

-- Audit missing values ("-" in IRENA = technology not deployed)
SELECT country_area, technology,
    SUM(CASE WHEN value_raw = '-' OR value_raw IS NULL THEN 1 ELSE 0 END) AS missing_count,
    COUNT(*) AS total_records
FROM raw_electricity_stats GROUP BY country_area, technology;

-- Insert cleaned IRENA records into renewable_capacity
DELETE FROM renewable_capacity;
INSERT INTO renewable_capacity (iso_code, country_name, year, technology, technology_group, capacity_mw, capacity_gw)
SELECT 
    cl.iso_code, cl.country_name, r.year, r.technology,
    CASE 
        WHEN r.technology = 'Solar photovoltaic' THEN 'Solar'
        WHEN r.technology IN ('Onshore wind energy', 'Offshore wind energy') THEN 'Wind'
        WHEN r.technology = 'Renewable hydropower' THEN 'Hydro'
        ELSE 'Other'  -- Biogas, Geothermal
    END AS technology_group,
    CASE WHEN r.value_raw = '-' OR r.value_raw IS NULL OR r.value_raw = '' THEN 0
         ELSE CAST(r.value_raw AS DECIMAL(12,2)) END AS capacity_mw,
    CASE WHEN r.value_raw = '-' OR r.value_raw IS NULL OR r.value_raw = '' THEN 0
         ELSE ROUND(CAST(r.value_raw AS DECIMAL(12,2)) / 1000.0, 4) END AS capacity_gw
FROM raw_electricity_stats r
INNER JOIN country_lookup cl ON r.country_area = cl.country_name_irena
WHERE r.year BETWEEN 2015 AND 2024
  AND r.data_type = 'Electricity Installed Capacity (MW)'
  AND r.grid_connection = 'On-grid';

-- Verify: expect ~60 records per country (6 techs x 10 years)
SELECT iso_code, country_name, COUNT(*) AS records, COUNT(DISTINCT year) AS years
FROM renewable_capacity GROUP BY iso_code ORDER BY country_name;

-- ========================================
-- PART B: WORLD BANK DATA CLEANING
-- ========================================

-- World Bank WDI arrives in wide format (one column per year).
-- We unpivot into long format with one INSERT per year.
-- Missing value convention:
--   World Bank ".." = data not yet reported → NULL (genuinely unknown)
--   IRENA    "-"   = technology not deployed → 0   (confirmed absence)
-- This distinction matters for downstream analysis.

DELETE FROM worldbank_context;

-- Year 2015
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2015,
    CASE WHEN pop.yr_2015 IN ('..','') THEN NULL ELSE CAST(pop.yr_2015 AS INTEGER) END,
    CASE WHEN acc.yr_2015 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2015 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2015 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2015 AS DECIMAL),2) END,
    CASE WHEN con.yr_2015 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2015 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2016
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2016,
    CASE WHEN pop.yr_2016 IN ('..','') THEN NULL ELSE CAST(pop.yr_2016 AS INTEGER) END,
    CASE WHEN acc.yr_2016 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2016 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2016 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2016 AS DECIMAL),2) END,
    CASE WHEN con.yr_2016 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2016 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2017
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2017,
    CASE WHEN pop.yr_2017 IN ('..','') THEN NULL ELSE CAST(pop.yr_2017 AS INTEGER) END,
    CASE WHEN acc.yr_2017 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2017 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2017 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2017 AS DECIMAL),2) END,
    CASE WHEN con.yr_2017 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2017 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2018
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2018,
    CASE WHEN pop.yr_2018 IN ('..','') THEN NULL ELSE CAST(pop.yr_2018 AS INTEGER) END,
    CASE WHEN acc.yr_2018 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2018 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2018 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2018 AS DECIMAL),2) END,
    CASE WHEN con.yr_2018 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2018 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2019
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2019,
    CASE WHEN pop.yr_2019 IN ('..','') THEN NULL ELSE CAST(pop.yr_2019 AS INTEGER) END,
    CASE WHEN acc.yr_2019 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2019 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2019 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2019 AS DECIMAL),2) END,
    CASE WHEN con.yr_2019 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2019 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2020
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2020,
    CASE WHEN pop.yr_2020 IN ('..','') THEN NULL ELSE CAST(pop.yr_2020 AS INTEGER) END,
    CASE WHEN acc.yr_2020 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2020 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2020 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2020 AS DECIMAL),2) END,
    CASE WHEN con.yr_2020 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2020 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2021
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2021,
    CASE WHEN pop.yr_2021 IN ('..','') THEN NULL ELSE CAST(pop.yr_2021 AS INTEGER) END,
    CASE WHEN acc.yr_2021 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2021 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2021 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2021 AS DECIMAL),2) END,
    CASE WHEN con.yr_2021 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2021 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2022
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2022,
    CASE WHEN pop.yr_2022 IN ('..','') THEN NULL ELSE CAST(pop.yr_2022 AS INTEGER) END,
    CASE WHEN acc.yr_2022 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2022 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2022 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2022 AS DECIMAL),2) END,
    CASE WHEN con.yr_2022 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2022 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2023
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2023,
    CASE WHEN pop.yr_2023 IN ('..','') THEN NULL ELSE CAST(pop.yr_2023 AS INTEGER) END,
    CASE WHEN acc.yr_2023 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2023 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2023 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2023 AS DECIMAL),2) END,
    CASE WHEN con.yr_2023 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2023 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Year 2024 (note: most WB indicators show ".." for 2024 except population)
INSERT INTO worldbank_context (iso_code, country_name, year, population, electrification_rate_pct, renewable_elec_share_pct, elec_consumption_kwh_pc)
SELECT cl.iso_code, cl.country_name, 2024,
    CASE WHEN pop.yr_2024 IN ('..','') THEN NULL ELSE CAST(pop.yr_2024 AS INTEGER) END,
    CASE WHEN acc.yr_2024 IN ('..','') THEN NULL ELSE ROUND(CAST(acc.yr_2024 AS DECIMAL),2) END,
    CASE WHEN ren.yr_2024 IN ('..','') THEN NULL ELSE ROUND(CAST(ren.yr_2024 AS DECIMAL),2) END,
    CASE WHEN con.yr_2024 IN ('..','') THEN NULL ELSE ROUND(CAST(con.yr_2024 AS DECIMAL),2) END
FROM country_lookup cl
LEFT JOIN raw_worldbank_wdi pop ON cl.country_name_wb = pop.country_name AND pop.series_code='SP.POP.TOTL'
LEFT JOIN raw_worldbank_wdi acc ON cl.country_name_wb = acc.country_name AND acc.series_code='EG.ELC.ACCS.ZS'
LEFT JOIN raw_worldbank_wdi ren ON cl.country_name_wb = ren.country_name AND ren.series_code='EG.ELC.RNEW.ZS'
LEFT JOIN raw_worldbank_wdi con ON cl.country_name_wb = con.country_name AND con.series_code='EG.USE.ELEC.KH.PC';

-- Verify: 80 rows expected (8 countries x 10 years)
SELECT iso_code, country_name, COUNT(*) AS records,
    SUM(CASE WHEN population IS NOT NULL THEN 1 ELSE 0 END) AS pop_years,
    SUM(CASE WHEN electrification_rate_pct IS NOT NULL THEN 1 ELSE 0 END) AS elec_years
FROM worldbank_context GROUP BY iso_code ORDER BY country_name;

-- ========================================
-- PART C: CROSS-VALIDATION
-- ========================================

-- The supplementary IRENA file (irena_renewable_share.csv) provides
-- independently published RE share of electricity capacity (%).
-- We use it here as a validation benchmark: our computed capacity
-- totals should be consistent with these published percentages.
-- The file is included in data/raw/ for auditability but is not
-- imported as a separate table because the metric is already
-- derivable from the primary IRENA source.

-- Spot-check: Vietnam 2024 should show ~48.5 GW total renewable
SELECT country_name, year,
    ROUND(SUM(capacity_mw), 2) AS total_mw,
    ROUND(SUM(capacity_gw), 4) AS total_gw
FROM renewable_capacity WHERE year = 2024
GROUP BY country_name ORDER BY total_mw DESC;

-- Row count validation: fail loudly if pipeline produced unexpected results
SELECT CASE WHEN COUNT(*) = 480 THEN '✓ renewable_capacity: 480 rows (8 countries x 6 techs x 10 years)'
    ELSE '✗ ERROR: expected 480 rows, got ' || COUNT(*) END AS validation
FROM renewable_capacity;

SELECT CASE WHEN COUNT(*) = 80 THEN '✓ worldbank_context: 80 rows (8 countries x 10 years)'
    ELSE '✗ ERROR: expected 80 rows, got ' || COUNT(*) END AS validation
FROM worldbank_context;

SELECT CASE WHEN COUNT(DISTINCT iso_code) = 8 THEN '✓ All 8 ASEAN countries present'
    ELSE '✗ ERROR: expected 8 countries, got ' || COUNT(DISTINCT iso_code) END AS validation
FROM renewable_capacity;

SELECT CASE WHEN COUNT(DISTINCT year) = 10 THEN '✓ All 10 years (2015-2024) present'
    ELSE '✗ ERROR: expected 10 years, got ' || COUNT(DISTINCT year) END AS validation
FROM renewable_capacity;
