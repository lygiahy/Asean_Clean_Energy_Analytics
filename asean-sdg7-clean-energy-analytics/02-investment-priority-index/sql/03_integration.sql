-- =============================================================
-- MSIN0304 | Team 3 | SDG 7: Affordable and Clean Energy
-- File: 03_integration.sql
-- Purpose: Create integrated master view from all four slices
-- Run after 02_load_data.sql
-- =============================================================

-- Design decisions documented:
-- (1) LEFT JOIN used throughout so no spine rows are dropped
--     even if a staging table has partial coverage
-- (2) Slice 2 joined on country_code only (no year key)
--     because IEA data provides 2015 and 2022 snapshots,
--     not annual figures — values repeat across all 7 years
--     per country by design
-- (3) Year ceiling is 2021 because energy_intensity_mj_gdp
--     (Slice 3) ends at 2021 for most countries
-- (4) Grain: one row = one country x one year

DROP VIEW IF EXISTS v_integrated_master;

CREATE VIEW v_integrated_master AS
SELECT
    s.country_code,
    s.year,
    d.country_name,
    d.income_classification,

    -- Slice 1: Renewable energy (IRENA + World Bank WDI)
    r.renewable_output_pct_wdi,
    r.re_capacity_share_pct,
    r.solar_capacity_mw,
    r.wind_capacity_mw,
    r.hydro_capacity_mw,
    r.geothermal_capacity_mw,
    r.biogas_capacity_mw,
    r.offshore_wind_capacity_mw,
    r.total_re_capacity_mw,
    r.elec_access_pct_wdi_annual,
    r.electricity_consumption_kwh_pc,
    r.population_total_count,

    -- Slice 3: Grid infrastructure (World Bank WDI)
    g.td_losses_pct,
    g.energy_intensity_mj_gdp,

    -- Slice 4: Economic context (IMF WEO + World Bank WDI/WBGI)
    e.gdp_growth_pct,
    e.gdp_per_capita_usd,
    e.fdi_usd_millions,
    e.regulatory_quality_wbgi,

    -- Slice 2: Energy access context (IEA, snapshot endpoints only)
    a.elec_access_2015_pct_iea,
    a.elec_access_2022_pct_iea,
    a.elec_access_improve_pp_iea,
    a.elec_access_2022_urban_pct_iea,
    a.elec_access_2022_rural_pct_iea,
    a.pop_without_elec_access_2022m_iea,
    a.cooking_access_2015_pct_iea,
    a.cooking_access_2022_pct_iea,
    a.cooking_access_improve_pp_iea,
    a.pop_without_cooking_2022m_iea,
    a.pop_biomass_2022m_iea,
    a.approx_elec_access_2022,
    a.approx_cooking_access_2015,
    a.approx_pop_without_elec_2022

FROM fact_spine s
LEFT JOIN dim_country d
    ON s.country_code = d.country_code
LEFT JOIN stg_renewable r
    ON s.country_code = r.country_code
    AND s.year        = r.year
LEFT JOIN stg_grid g
    ON s.country_code = g.country_code
    AND s.year        = g.year
LEFT JOIN stg_economic e
    ON s.country_code = e.country_code
    AND s.year        = e.year
LEFT JOIN stg_access a
    ON s.country_code = a.country_code  -- no year key: IEA data is snapshot
ORDER BY s.country_code, s.year;

-- Confirm view is queryable
SELECT COUNT(*) AS view_row_count FROM v_integrated_master;
-- Expected: 56
