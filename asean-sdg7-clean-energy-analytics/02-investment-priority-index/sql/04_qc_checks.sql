-- =============================================================
-- MSIN0304 | Team 3 | SDG 7: Affordable and Clean Energy
-- File: 04_qc_checks.sql
-- Purpose: Quality control checks on the integrated view
-- Run after 03_integration.sql
-- Screenshot all outputs and save as qc_results.pdf
-- =============================================================

-- QC 1: Total row count
-- Expected: 56 (8 countries x 7 years)
SELECT 'QC1' AS check_id, COUNT(*) AS result,
       CASE WHEN COUNT(*)=56 THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_integrated_master;

-- QC 2: Rows per country
-- Expected: every country has exactly 7 rows
SELECT 'QC2' AS check_id, country_code, COUNT(*) AS rows,
       CASE WHEN COUNT(*)=7 THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_integrated_master
GROUP BY country_code
ORDER BY country_code;

-- QC 3: No NULLs in core metrics
-- Expected: all zero
SELECT 'QC3' AS check_id,
    SUM(CASE WHEN renewable_output_pct_wdi IS NULL THEN 1 ELSE 0 END) AS null_renewable,
    SUM(CASE WHEN td_losses_pct            IS NULL THEN 1 ELSE 0 END) AS null_td_losses,
    SUM(CASE WHEN energy_intensity_mj_gdp  IS NULL THEN 1 ELSE 0 END) AS null_energy_int,
    SUM(CASE WHEN gdp_growth_pct           IS NULL THEN 1 ELSE 0 END) AS null_gdp_growth,
    SUM(CASE WHEN fdi_usd_millions         IS NULL THEN 1 ELSE 0 END) AS null_fdi,
    SUM(CASE WHEN total_re_capacity_mw     IS NULL THEN 1 ELSE 0 END) AS null_re_capacity
FROM v_integrated_master;

-- QC 4: Year range
-- Expected: 2015 to 2021
SELECT 'QC4' AS check_id,
    MIN(year) AS min_year, MAX(year) AS max_year,
    CASE WHEN MIN(year)=2015 AND MAX(year)=2021 THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_integrated_master;

-- QC 5: Distinct country count
-- Expected: 8
SELECT 'QC5' AS check_id,
    COUNT(DISTINCT country_code) AS n_countries,
    CASE WHEN COUNT(DISTINCT country_code)=8 THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_integrated_master;

-- QC 6: Vietnam solar boom (key analytical insight)
-- Expected: ~0.8 MW in 2015, ~4989 in 2019, ~16656 in 2020
SELECT 'QC6' AS check_id, country_code, year,
       ROUND(solar_capacity_mw, 1) AS solar_mw
FROM v_integrated_master
WHERE country_code = 'VNM'
ORDER BY year;

-- QC 7: Myanmar economic collapse (key investment risk signal)
-- Expected: GDP growth 6.6 in 2019, -9.0 in 2020, -12.0 in 2021
SELECT 'QC7' AS check_id, country_code, year, gdp_growth_pct
FROM v_integrated_master
WHERE country_code = 'MMR' AND year IN (2019, 2020, 2021);

-- QC 8: Lao PDR T&D drop (documented anomaly, not an error)
-- Expected: ~15.7 in 2015, drops to ~5.4 in 2016
SELECT 'QC8' AS check_id, country_code, year,
       ROUND(td_losses_pct, 2) AS td_losses_pct
FROM v_integrated_master
WHERE country_code = 'LAO'
ORDER BY year;

-- QC 9: Approximation flags correctly set
-- Expected: IDN MYS THA VNM = 1 for approx_elec_access_2022
-- Expected: KHM LAO MMR = 1 for approx_cooking_access_2015
SELECT 'QC9' AS check_id, country_code,
       approx_elec_access_2022,
       approx_cooking_access_2015,
       approx_pop_without_elec_2022
FROM v_integrated_master
WHERE year = 2015
ORDER BY country_code;

-- QC 10: All four slices contributed data (no slice entirely missing)
SELECT 'QC10' AS check_id,
    COUNT(CASE WHEN renewable_output_pct_wdi IS NOT NULL THEN 1 END) AS slice1_rows,
    COUNT(CASE WHEN td_losses_pct            IS NOT NULL THEN 1 END) AS slice3_rows,
    COUNT(CASE WHEN gdp_growth_pct           IS NOT NULL THEN 1 END) AS slice4_rows,
    COUNT(CASE WHEN elec_access_2022_pct_iea IS NOT NULL THEN 1 END) AS slice2_rows
FROM v_integrated_master;
-- Expected: 56, 56, 56, 56


-- =============================================================
-- PRIORITY INDEX QC CHECKS (run after 05_priority_index.sql)
-- =============================================================

-- QC 11: Priority Index row count matches integrated view
SELECT 'QC11' AS check_id,
    COUNT(*) AS index_rows,
    CASE WHEN COUNT(*)=56 THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_priority_index;

-- QC 12: All priority index scores within 0-100 range
SELECT 'QC12' AS check_id,
    MIN(priority_index) AS min_score,
    MAX(priority_index) AS max_score,
    CASE WHEN MIN(priority_index) >= 0 AND MAX(priority_index) <= 100
         THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_priority_index;

-- QC 13: Component scores within 0-100 range
SELECT 'QC13' AS check_id,
    MIN(component_impact) AS min_impact,
    MAX(component_impact) AS max_impact,
    MIN(component_readiness) AS min_readiness,
    MAX(component_readiness) AS max_readiness,
    MIN(component_viability) AS min_viability,
    MAX(component_viability) AS max_viability,
    CASE WHEN MIN(component_impact) >= 0 AND MAX(component_impact) <= 100
          AND MIN(component_readiness) >= 0 AND MAX(component_readiness) <= 100
          AND MIN(component_viability) >= 0 AND MAX(component_viability) <= 100
         THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_priority_index;

-- QC 14: No NULL values in priority index output
SELECT 'QC14' AS check_id,
    SUM(CASE WHEN priority_index IS NULL THEN 1 ELSE 0 END) AS null_index,
    SUM(CASE WHEN component_impact IS NULL THEN 1 ELSE 0 END) AS null_impact,
    SUM(CASE WHEN component_readiness IS NULL THEN 1 ELSE 0 END) AS null_readiness,
    SUM(CASE WHEN component_viability IS NULL THEN 1 ELSE 0 END) AS null_viability,
    CASE WHEN SUM(CASE WHEN priority_index IS NULL THEN 1 ELSE 0 END) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_priority_index;

-- QC 15: 2021 ranking sense check (Philippines and Indonesia should rank top 2)
SELECT 'QC15' AS check_id,
    country_name,
    priority_index,
    RANK() OVER (ORDER BY priority_index DESC) AS rank_2021
FROM v_priority_index
WHERE year = 2021
ORDER BY priority_index DESC;
