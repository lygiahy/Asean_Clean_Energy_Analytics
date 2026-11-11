-- ============================================================================
-- Script 03: Analysis Queries
-- Purpose: Aggregate, compute growth, and generate analytical outputs
-- Candidate: SRLB2
-- ============================================================================

-- STEP 1: Populate summary table (country-year totals)
DELETE FROM renewable_summary;
INSERT INTO renewable_summary (iso_code, country_name, year, total_renewable_mw, total_renewable_gw,
    solar_mw, wind_mw, hydro_mw, other_mw, solar_share_pct, wind_share_pct, hydro_share_pct)
SELECT iso_code, country_name, year,
    ROUND(SUM(capacity_mw), 2),
    ROUND(SUM(capacity_gw), 4),
    ROUND(SUM(CASE WHEN technology_group = 'Solar' THEN capacity_mw ELSE 0 END), 2),
    ROUND(SUM(CASE WHEN technology_group = 'Wind' THEN capacity_mw ELSE 0 END), 2),
    ROUND(SUM(CASE WHEN technology_group = 'Hydro' THEN capacity_mw ELSE 0 END), 2),
    ROUND(SUM(CASE WHEN technology_group = 'Other' THEN capacity_mw ELSE 0 END), 2),
    ROUND(SUM(CASE WHEN technology_group = 'Solar' THEN capacity_mw ELSE 0 END) * 100.0 / 
          NULLIF(SUM(capacity_mw), 0), 2),
    ROUND(SUM(CASE WHEN technology_group = 'Wind' THEN capacity_mw ELSE 0 END) * 100.0 / 
          NULLIF(SUM(capacity_mw), 0), 2),
    ROUND(SUM(CASE WHEN technology_group = 'Hydro' THEN capacity_mw ELSE 0 END) * 100.0 / 
          NULLIF(SUM(capacity_mw), 0), 2)
FROM renewable_capacity GROUP BY iso_code, country_name, year;

-- STEP 2: Year-on-year growth (self-join: current vs previous vs 2015 baseline)
DELETE FROM renewable_growth;
INSERT INTO renewable_growth (iso_code, country_name, year, total_renewable_mw,
    prev_year_mw, absolute_growth_mw, yoy_growth_pct, cumulative_growth_since_2015_pct)
SELECT curr.iso_code, curr.country_name, curr.year, curr.total_renewable_mw,
    prev.total_renewable_mw,
    ROUND(CASE WHEN prev.total_renewable_mw IS NULL THEN NULL
          ELSE curr.total_renewable_mw - prev.total_renewable_mw END, 2),
    ROUND(CASE WHEN prev.total_renewable_mw IS NULL OR prev.total_renewable_mw = 0 THEN NULL
          ELSE ((curr.total_renewable_mw - prev.total_renewable_mw) * 1.0 / prev.total_renewable_mw) * 100
          END, 2),
    ROUND(CASE WHEN base.total_renewable_mw IS NULL OR base.total_renewable_mw = 0 THEN NULL
          ELSE ((curr.total_renewable_mw - base.total_renewable_mw) * 1.0 / base.total_renewable_mw) * 100
          END, 2)
FROM renewable_summary curr
LEFT JOIN renewable_summary prev ON curr.iso_code = prev.iso_code AND curr.year = prev.year + 1
LEFT JOIN renewable_summary base ON curr.iso_code = base.iso_code AND base.year = 2015
ORDER BY curr.iso_code, curr.year;

-- STEP 3: Key analytical queries

-- 3.1: Capacity ranking (2024)
SELECT country_name, total_renewable_gw, solar_share_pct, hydro_share_pct,
    RANK() OVER (ORDER BY total_renewable_mw DESC) AS capacity_rank
FROM renewable_summary WHERE year = 2024 ORDER BY capacity_rank;

-- 3.2: Growth leaders (2015-2024)
SELECT g.country_name, g.total_renewable_mw AS capacity_2024_mw,
    g.cumulative_growth_since_2015_pct AS growth_pct,
    RANK() OVER (ORDER BY g.cumulative_growth_since_2015_pct DESC) AS growth_rank
FROM renewable_growth g WHERE g.year = 2024 ORDER BY growth_rank;

-- 3.3: Vietnam solar explosion detail
SELECT year, solar_mw, total_renewable_mw, solar_share_pct,
    LAG(solar_mw) OVER (ORDER BY year) AS prev_solar,
    ROUND(solar_mw - LAG(solar_mw) OVER (ORDER BY year), 2) AS solar_added_mw
FROM renewable_summary WHERE iso_code = 'VNM' ORDER BY year;

-- 3.4: Technology dominance classification (2024)
SELECT country_name, ROUND(solar_share_pct,1) AS solar_pct,
    ROUND(hydro_share_pct,1) AS hydro_pct,
    CASE WHEN solar_share_pct >= hydro_share_pct THEN 'Solar-led'
         ELSE 'Hydro-led' END AS primary_technology
FROM renewable_summary WHERE year = 2024 ORDER BY total_renewable_mw DESC;

-- 3.5: Vietnam vs Indonesia comparison
SELECT v.year, v.total_renewable_gw AS vietnam_gw, i.total_renewable_gw AS indonesia_gw,
    ROUND(v.total_renewable_mw / NULLIF(i.total_renewable_mw, 0), 2) AS ratio
FROM renewable_summary v
JOIN renewable_summary i ON v.year = i.year
WHERE v.iso_code = 'VNM' AND i.iso_code = 'IDN' ORDER BY v.year;

-- ========================================
-- STEP 4: Data Integrity Validation
-- ========================================

SELECT CASE WHEN COUNT(*) = 80 THEN '✓ renewable_summary: 80 rows'
    ELSE '✗ ERROR: expected 80, got ' || COUNT(*) END AS validation
FROM renewable_summary;

SELECT CASE WHEN COUNT(*) = 80 THEN '✓ renewable_growth: 80 rows'
    ELSE '✗ ERROR: expected 80, got ' || COUNT(*) END AS validation
FROM renewable_growth;

-- Verify 2015 baseline has NULL growth (no previous year)
SELECT CASE WHEN COUNT(*) = 8 THEN '✓ All 8 countries have NULL yoy_growth for 2015'
    ELSE '✗ ERROR: expected 8 NULL baselines, got ' || COUNT(*) END AS validation
FROM renewable_growth WHERE year = 2015 AND yoy_growth_pct IS NULL;

-- Verify no negative capacity (would indicate data error)
SELECT CASE WHEN COUNT(*) = 0 THEN '✓ No negative capacity values'
    ELSE '✗ ERROR: ' || COUNT(*) || ' negative values found' END AS validation
FROM renewable_summary WHERE total_renewable_mw < 0;

-- Verify technology shares sum to ~100% for each country-year
SELECT CASE WHEN COUNT(*) = 0 THEN '✓ Technology shares sum to ~100% for all rows'
    ELSE '✗ ERROR: ' || COUNT(*) || ' rows with shares not summing to 100' END AS validation
FROM (
    SELECT iso_code, year, solar_share_pct + wind_share_pct + hydro_share_pct +
        ROUND((other_mw * 100.0 / NULLIF(total_renewable_mw, 0)), 2) AS total_share
    FROM renewable_summary
    WHERE total_renewable_mw > 0
) WHERE ABS(total_share - 100) > 1;
