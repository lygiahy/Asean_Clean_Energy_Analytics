-- ============================================================================
-- Script 04: Bridge Queries for Integration
-- Purpose: (a) Working joins within my slice; (b) A2 integration plan
-- Candidate: SRLB2
-- ============================================================================

-- BRIDGE 1: Renewable capacity + World Bank electrification context (2024)
SELECT rs.iso_code, rs.country_name, rs.total_renewable_gw, rs.solar_share_pct,
    wb.population, wb.electrification_rate_pct,
    ROUND(rs.total_renewable_mw / (wb.population / 1000000.0), 2) AS mw_per_million_pop
FROM renewable_summary rs
INNER JOIN worldbank_context wb ON rs.iso_code = wb.iso_code AND rs.year = wb.year
WHERE rs.year = 2024 ORDER BY rs.total_renewable_mw DESC;

-- BRIDGE 2: Growth trajectory + energy access gap (investment signal)
SELECT rg.country_name, rg.cumulative_growth_since_2015_pct AS growth_pct,
    wb.electrification_rate_pct, ROUND(100.0 - wb.electrification_rate_pct, 1) AS access_gap_pct,
    CASE WHEN rg.cumulative_growth_since_2015_pct > 100 AND wb.electrification_rate_pct < 100
         THEN 'High growth + gap: Priority'
         WHEN rg.cumulative_growth_since_2015_pct > 50 THEN 'Moderate growth: Monitor'
         WHEN wb.electrification_rate_pct < 95 THEN 'Low growth + gap: Needs intervention'
         ELSE 'Mature: Maintenance' END AS investment_signal
FROM renewable_growth rg
INNER JOIN worldbank_context wb ON rg.iso_code = wb.iso_code AND rg.year = wb.year
WHERE rg.year = 2024 AND wb.population IS NOT NULL
ORDER BY rg.cumulative_growth_since_2015_pct DESC;

-- BRIDGE 3: Time-series join — Vietnam vs Indonesia deep dive
SELECT rs.country_name, rs.year, rs.total_renewable_gw, rs.solar_mw,
    wb.electrification_rate_pct, wb.elec_consumption_kwh_pc,
    ROUND(rs.total_renewable_gw / (wb.population / 1000000.0), 4) AS gw_per_million_pop
FROM renewable_summary rs
INNER JOIN worldbank_context wb ON rs.iso_code = wb.iso_code AND rs.year = wb.year
WHERE rs.iso_code IN ('VNM', 'IDN') AND rs.year BETWEEN 2015 AND 2024
ORDER BY rs.country_name, rs.year;

-- A2 INTEGRATION PLAN (commented; teammates' tables not yet available):
/*
CREATE VIEW integrated_sdg7_analysis AS
SELECT cl.iso_code, cl.country_name, rs.year,
    rs.total_renewable_gw, rs.solar_share_pct, rg.yoy_growth_pct,
    wb.population, wb.electrification_rate_pct,
    a.rural_electrification_pct,   -- Person B: Energy Access
    i.td_losses_pct,                -- Person C: Grid Infrastructure
    e.gdp_per_capita_usd            -- Zohra: Economic Context
FROM country_lookup cl
JOIN renewable_summary rs ON cl.iso_code = rs.iso_code
LEFT JOIN renewable_growth rg ON rs.iso_code = rg.iso_code AND rs.year = rg.year
LEFT JOIN worldbank_context wb ON rs.iso_code = wb.iso_code AND rs.year = wb.year
LEFT JOIN energy_access a ON rs.iso_code = a.iso_code AND rs.year = a.year
LEFT JOIN grid_infrastructure i ON rs.iso_code = i.iso_code AND rs.year = i.year
LEFT JOIN economic_context e ON rs.iso_code = e.iso_code AND rs.year = e.year;
*/

-- Verify join keys are integration-ready
SELECT DISTINCT rs.iso_code, rs.country_name,
    MIN(rs.year) AS first_yr, MAX(rs.year) AS last_yr, COUNT(DISTINCT rs.year) AS years
FROM renewable_summary rs GROUP BY rs.iso_code ORDER BY rs.country_name;
