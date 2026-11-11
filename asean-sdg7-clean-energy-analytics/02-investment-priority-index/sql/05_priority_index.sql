-- =============================================================
-- MSIN0304 | Team 3 | SDG 7: Affordable and Clean Energy
-- File: 05_priority_index.sql
-- Purpose: Calculate the Clean Energy Investment Priority Index
--          directly inside SQLite using min-max normalisation.
--          Run after 04_qc_checks.sql.
-- =============================================================
--
-- INDEX STRUCTURE (matches original brainstorm document):
--   Component 1: Impact Potential    40%
--   Component 2: Market Readiness    30%
--   Component 3: Economic Viability  30%
--   Final Score: weighted sum, scale 0 to 100
--
-- METHOD: min-max normalisation
--   Higher score always = better investment case
--   For metrics where lower is better (T&D losses, energy
--   intensity), the scale is inverted so 100 = most efficient
--
-- FORMULA:
--   normalised = (value - MIN) / (MAX - MIN) * 100
--   inverted   = 100 - normalised
-- =============================================================


-- Drop existing objects if re-running
DROP VIEW IF EXISTS v_index_normalised;
DROP VIEW IF EXISTS v_priority_index;


-- =============================================================
-- STEP 1: Normalise every input metric to 0-100 scale
-- All MIN() and MAX() are computed across the full 56-row
-- dataset so every country-year is compared on the same scale.
-- =============================================================
CREATE VIEW v_index_normalised AS
SELECT
    country_code,
    year,
    country_name,
    income_classification,

    -- --------------------------------------------------------
    -- IMPACT POTENTIAL inputs
    -- --------------------------------------------------------

    -- Electricity access gap: 100 minus IEA 2022 access rate
    -- Higher gap = higher impact potential
    -- Normalised: higher score = larger gap = more need
    ROUND(
        ((100.0 - elec_access_2022_pct_iea)
            - (SELECT MIN(100.0 - elec_access_2022_pct_iea) FROM v_integrated_master))
        / ((SELECT MAX(100.0 - elec_access_2022_pct_iea) FROM v_integrated_master)
            - (SELECT MIN(100.0 - elec_access_2022_pct_iea) FROM v_integrated_master))
        * 100.0
    , 1) AS n_elec_gap,

    -- Population without clean cooking (millions)
    -- Higher = more people affected = higher impact
    ROUND(
        (pop_without_cooking_2022m_iea
            - (SELECT MIN(pop_without_cooking_2022m_iea) FROM v_integrated_master))
        / ((SELECT MAX(pop_without_cooking_2022m_iea) FROM v_integrated_master)
            - (SELECT MIN(pop_without_cooking_2022m_iea) FROM v_integrated_master))
        * 100.0
    , 1) AS n_cooking_gap,

    -- Access improvement speed (percentage points gained 2015 to 2022)
    -- Faster improvement = government and market already moving = better target
    ROUND(
        (elec_access_improve_pp_iea
            - (SELECT MIN(elec_access_improve_pp_iea) FROM v_integrated_master))
        / ((SELECT MAX(elec_access_improve_pp_iea) FROM v_integrated_master)
            - (SELECT MIN(elec_access_improve_pp_iea) FROM v_integrated_master))
        * 100.0
    , 1) AS n_improve_speed,

    -- --------------------------------------------------------
    -- MARKET READINESS inputs
    -- --------------------------------------------------------

    -- Renewable output share (% of electricity from renewables)
    -- Higher = more renewables already in the mix
    ROUND(
        (renewable_output_pct_wdi
            - (SELECT MIN(renewable_output_pct_wdi) FROM v_integrated_master))
        / ((SELECT MAX(renewable_output_pct_wdi) FROM v_integrated_master)
            - (SELECT MIN(renewable_output_pct_wdi) FROM v_integrated_master))
        * 100.0
    , 1) AS n_re_output,

    -- T&D losses: INVERTED because lower losses = better grid
    ROUND(
        100.0 -
        (td_losses_pct
            - (SELECT MIN(td_losses_pct) FROM v_integrated_master))
        / ((SELECT MAX(td_losses_pct) FROM v_integrated_master)
            - (SELECT MIN(td_losses_pct) FROM v_integrated_master))
        * 100.0
    , 1) AS n_grid_efficiency,

    -- Energy intensity: INVERTED because lower = more efficient
    ROUND(
        100.0 -
        (energy_intensity_mj_gdp
            - (SELECT MIN(energy_intensity_mj_gdp) FROM v_integrated_master))
        / ((SELECT MAX(energy_intensity_mj_gdp) FROM v_integrated_master)
            - (SELECT MIN(energy_intensity_mj_gdp) FROM v_integrated_master))
        * 100.0
    , 1) AS n_energy_intensity,

    -- Total RE capacity (MW): higher = larger established RE market
    ROUND(
        (total_re_capacity_mw
            - (SELECT MIN(total_re_capacity_mw) FROM v_integrated_master))
        / ((SELECT MAX(total_re_capacity_mw) FROM v_integrated_master)
            - (SELECT MIN(total_re_capacity_mw) FROM v_integrated_master))
        * 100.0
    , 1) AS n_re_capacity,

    -- --------------------------------------------------------
    -- ECONOMIC VIABILITY inputs
    -- --------------------------------------------------------

    -- GDP growth rate
    ROUND(
        (gdp_growth_pct
            - (SELECT MIN(gdp_growth_pct) FROM v_integrated_master))
        / ((SELECT MAX(gdp_growth_pct) FROM v_integrated_master)
            - (SELECT MIN(gdp_growth_pct) FROM v_integrated_master))
        * 100.0
    , 1) AS n_gdp_growth,

    -- FDI net inflows (USD millions)
    ROUND(
        (fdi_usd_millions
            - (SELECT MIN(fdi_usd_millions) FROM v_integrated_master))
        / ((SELECT MAX(fdi_usd_millions) FROM v_integrated_master)
            - (SELECT MIN(fdi_usd_millions) FROM v_integrated_master))
        * 100.0
    , 1) AS n_fdi,

    -- Regulatory quality (WBGI score)
    ROUND(
        (regulatory_quality_wbgi
            - (SELECT MIN(regulatory_quality_wbgi) FROM v_integrated_master))
        / ((SELECT MAX(regulatory_quality_wbgi) FROM v_integrated_master)
            - (SELECT MIN(regulatory_quality_wbgi) FROM v_integrated_master))
        * 100.0
    , 1) AS n_regulatory,

    -- GDP per capita
    ROUND(
        (gdp_per_capita_usd
            - (SELECT MIN(gdp_per_capita_usd) FROM v_integrated_master))
        / ((SELECT MAX(gdp_per_capita_usd) FROM v_integrated_master)
            - (SELECT MIN(gdp_per_capita_usd) FROM v_integrated_master))
        * 100.0
    , 1) AS n_gdp_pc

FROM v_integrated_master;


-- =============================================================
-- STEP 2: Compute weighted component scores and final index
-- =============================================================
CREATE VIEW v_priority_index AS
SELECT
    country_code,
    year,
    country_name,
    income_classification,

    -- Component 1: Impact Potential (40% of final index)
    -- Sub-weights: access gap 40%, cooking gap 35%, improvement speed 25%
    ROUND(
        n_elec_gap      * 0.40 +
        n_cooking_gap   * 0.35 +
        n_improve_speed * 0.25
    , 1) AS component_impact,

    -- Component 2: Market Readiness (30% of final index)
    -- Sub-weights: RE output 30%, grid efficiency 30%,
    --              energy intensity 20%, RE capacity 20%
    ROUND(
        n_re_output        * 0.30 +
        n_grid_efficiency  * 0.30 +
        n_energy_intensity * 0.20 +
        n_re_capacity      * 0.20
    , 1) AS component_readiness,

    -- Component 3: Economic Viability (30% of final index)
    -- Sub-weights: GDP growth 35%, FDI 30%, regulatory 25%, GDP pc 10%
    ROUND(
        n_gdp_growth  * 0.35 +
        n_fdi         * 0.30 +
        n_regulatory  * 0.25 +
        n_gdp_pc      * 0.10
    , 1) AS component_viability,

    -- Final Priority Index: 0 to 100
    ROUND(
        (n_elec_gap      * 0.40 +
         n_cooking_gap   * 0.35 +
         n_improve_speed * 0.25) * 0.40 +
        (n_re_output        * 0.30 +
         n_grid_efficiency  * 0.30 +
         n_energy_intensity * 0.20 +
         n_re_capacity      * 0.20) * 0.30 +
        (n_gdp_growth  * 0.35 +
         n_fdi         * 0.30 +
         n_regulatory  * 0.25 +
         n_gdp_pc      * 0.10) * 0.30
    , 1) AS priority_index

FROM v_index_normalised;


-- =============================================================
-- STEP 3: Verify results
-- =============================================================

-- Rankings for 2021 (most recent complete year)
-- Philippines and Indonesia should rank highest
SELECT
    country_name,
    component_impact,
    component_readiness,
    component_viability,
    priority_index
FROM v_priority_index
WHERE year = 2021
ORDER BY priority_index DESC;

-- Index trend across all years
SELECT
    country_name,
    MAX(CASE WHEN year=2015 THEN priority_index END) AS y2015,
    MAX(CASE WHEN year=2016 THEN priority_index END) AS y2016,
    MAX(CASE WHEN year=2017 THEN priority_index END) AS y2017,
    MAX(CASE WHEN year=2018 THEN priority_index END) AS y2018,
    MAX(CASE WHEN year=2019 THEN priority_index END) AS y2019,
    MAX(CASE WHEN year=2020 THEN priority_index END) AS y2020,
    MAX(CASE WHEN year=2021 THEN priority_index END) AS y2021
FROM v_priority_index
GROUP BY country_name
ORDER BY MAX(CASE WHEN year=2021 THEN priority_index END) DESC;


-- =============================================================
-- STEP 4: Sensitivity analysis - alternative weighting schemes
-- Tests robustness of country rankings under different assumptions.
-- Reference: Saisana & Saltelli (2011); Nardo et al. (2005)
-- =============================================================

-- QC 11: Equal weights (33/33/33)
SELECT 'QC11_equal_weights' AS check_id,
    country_name,
    ROUND(component_impact * 0.333 + component_readiness * 0.333 + component_viability * 0.333, 1) AS pi_equal,
    priority_index AS pi_baseline,
    RANK() OVER (ORDER BY (component_impact * 0.333 + component_readiness * 0.333 + component_viability * 0.333) DESC) AS rank_equal,
    RANK() OVER (ORDER BY priority_index DESC) AS rank_baseline
FROM v_priority_index
WHERE year = 2021
ORDER BY pi_equal DESC;

-- QC 12: Readiness-led weights (25/40/35)
SELECT 'QC12_readiness_led' AS check_id,
    country_name,
    ROUND(component_impact * 0.25 + component_readiness * 0.40 + component_viability * 0.35, 1) AS pi_readiness,
    priority_index AS pi_baseline,
    RANK() OVER (ORDER BY (component_impact * 0.25 + component_readiness * 0.40 + component_viability * 0.35) DESC) AS rank_readiness,
    RANK() OVER (ORDER BY priority_index DESC) AS rank_baseline
FROM v_priority_index
WHERE year = 2021
ORDER BY pi_readiness DESC;

-- QC 13: Viability-led weights (25/30/45)
SELECT 'QC13_viability_led' AS check_id,
    country_name,
    ROUND(component_impact * 0.25 + component_readiness * 0.30 + component_viability * 0.45, 1) AS pi_viability,
    priority_index AS pi_baseline,
    RANK() OVER (ORDER BY (component_impact * 0.25 + component_readiness * 0.30 + component_viability * 0.45) DESC) AS rank_viability,
    RANK() OVER (ORDER BY priority_index DESC) AS rank_baseline
FROM v_priority_index
WHERE year = 2021
ORDER BY pi_viability DESC;

-- QC 14: Rank stability summary across all three alternatives
-- PASS if top-3 countries are the same set in all schemes
SELECT 'QC14_rank_stability' AS check_id,
    b.country_name,
    b.rank_base,
    e.rank_equal,
    r.rank_read,
    v.rank_viab,
    CASE WHEN b.rank_base <= 3 AND e.rank_equal <= 3 AND r.rank_read <= 3 AND v.rank_viab <= 3
         THEN 'STABLE' ELSE 'SHIFTED' END AS top3_status
FROM (SELECT country_name, RANK() OVER (ORDER BY priority_index DESC) AS rank_base FROM v_priority_index WHERE year=2021) b
JOIN (SELECT country_name, RANK() OVER (ORDER BY (component_impact*0.333+component_readiness*0.333+component_viability*0.333) DESC) AS rank_equal FROM v_priority_index WHERE year=2021) e ON b.country_name=e.country_name
JOIN (SELECT country_name, RANK() OVER (ORDER BY (component_impact*0.25+component_readiness*0.40+component_viability*0.35) DESC) AS rank_read FROM v_priority_index WHERE year=2021) r ON b.country_name=r.country_name
JOIN (SELECT country_name, RANK() OVER (ORDER BY (component_impact*0.25+component_readiness*0.30+component_viability*0.45) DESC) AS rank_viab FROM v_priority_index WHERE year=2021) v ON b.country_name=v.country_name
ORDER BY b.rank_base;

-- QC 15: All priority index scores within 0-100 and non-null
SELECT 'QC15_index_bounds' AS check_id,
    MIN(priority_index) AS min_pi,
    MAX(priority_index) AS max_pi,
    SUM(CASE WHEN priority_index IS NULL THEN 1 ELSE 0 END) AS null_count,
    SUM(CASE WHEN priority_index < 0 OR priority_index > 100 THEN 1 ELSE 0 END) AS out_of_range,
    CASE WHEN MIN(priority_index) >= 0 AND MAX(priority_index) <= 100
         AND SUM(CASE WHEN priority_index IS NULL THEN 1 ELSE 0 END) = 0
         THEN 'PASS' ELSE 'FAIL' END AS status
FROM v_priority_index;
