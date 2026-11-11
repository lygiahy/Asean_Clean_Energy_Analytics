# Data Dictionary: Renewable Energy Capacity

**Candidate Number:** SRLB2  
**SDG:** 7 - Affordable and Clean Energy | **Scope:** 8 ASEAN Countries, 2015-2024

---

## Data Sources

| Source | Publisher | Dataset | URL | Raw File |
|--------|-----------|---------|-----|----------|
| **Primary** | IRENA | Renewable Capacity Statistics 2025 | https://www.irena.org/Data | `irena_electricity_statistics.csv` |
| **Secondary** | World Bank | World Development Indicators | https://databank.worldbank.org/ | `worldbank_wdi_asean.csv` |
| **Supplementary** | IRENA | RE share of electricity capacity (%) | https://www.irena.org/Data | `irena_renewable_share.csv` |

**Note on supplementary file:** The IRENA renewable share CSV is included for cross-validation (Script 02, Part C) but is not imported as a separate SQL table. Its published RE share percentages serve as an independent check against our computed capacity totals.

## Country Coverage

| ISO Code | Country | IRENA Name | World Bank Name | Income Group |
|----------|---------|------------|-----------------|--------------|
| KHM | Cambodia | Cambodia | Cambodia | Lower-middle |
| IDN | Indonesia | Indonesia | Indonesia | Upper-middle |
| LAO | Laos | Lao People's Democratic Republic (the) | Lao PDR | Lower-middle |
| MYS | Malaysia | Malaysia | Malaysia | Upper-middle |
| MMR | Myanmar | Myanmar | Myanmar | Lower-middle |
| PHL | Philippines | Philippines (the) | Philippines | Lower-middle |
| THA | Thailand | Thailand | Thailand | Upper-middle |
| VNM | Vietnam | Viet Nam | Viet Nam | Lower-middle |

## Table Definitions

### `country_lookup` (Dimension)
Maps naming discrepancies across sources to standardised ISO codes.

| Column | Type | Description |
|--------|------|-------------|
| iso_code | VARCHAR(3) | ISO 3166-1 alpha-3 (PK) |
| country_name | VARCHAR(100) | Standardised name |
| country_name_irena | VARCHAR(100) | IRENA spelling |
| country_name_wb | VARCHAR(100) | World Bank spelling |

### `renewable_capacity` (IRENA — technology level)

| Column | Type | Description | Source |
|--------|------|-------------|--------|
| iso_code | VARCHAR(3) | Country (FK) | Derived via country_lookup |
| year | INTEGER | 2015-2024 | IRENA |
| technology | VARCHAR(50) | e.g. Solar photovoltaic | IRENA |
| technology_group | VARCHAR(20) | Solar/Wind/Hydro/Other | Derived (CASE) |
| capacity_mw | DECIMAL(12,2) | Installed capacity (MW) | IRENA |
| capacity_gw | DECIMAL(10,4) | Capacity in GW | Derived (MW/1000) |

**Technology groupings:** Solar = Solar PV; Wind = Onshore + Offshore; Hydro = Renewable hydropower; Other = Biogas + Geothermal.

### `worldbank_context` (World Bank WDI)

| Column | Type | WDI Code | Description |
|--------|------|----------|-------------|
| population | INTEGER | SP.POP.TOTL | Total population |
| electrification_rate_pct | DECIMAL(5,2) | EG.ELC.ACCS.ZS | Access to electricity (%) |
| renewable_elec_share_pct | DECIMAL(5,2) | EG.ELC.RNEW.ZS | Renewable share of output (%) |
| elec_consumption_kwh_pc | DECIMAL(10,2) | EG.USE.ELEC.KH.PC | Consumption per capita |

### `renewable_summary` (Aggregated country-year)
Derived from `renewable_capacity` via GROUP BY in Script 03. Expected: 80 rows (8 countries x 10 years).

| Column | Type | Description | Derivation |
|--------|------|-------------|------------|
| iso_code | VARCHAR(3) | Country (FK) | From renewable_capacity |
| country_name | VARCHAR(100) | Standardised name | From renewable_capacity |
| year | INTEGER | 2015-2024 | From renewable_capacity |
| total_renewable_mw | DECIMAL(12,2) | Total capacity (MW) | SUM(capacity_mw) |
| total_renewable_gw | DECIMAL(10,4) | Total capacity (GW) | SUM(capacity_gw) |
| solar_mw | DECIMAL(12,2) | Solar PV capacity | SUM WHERE technology_group = 'Solar' |
| wind_mw | DECIMAL(12,2) | Wind capacity | SUM WHERE technology_group = 'Wind' |
| hydro_mw | DECIMAL(12,2) | Hydropower capacity | SUM WHERE technology_group = 'Hydro' |
| other_mw | DECIMAL(12,2) | Biogas + Geothermal | SUM WHERE technology_group = 'Other' |
| solar_share_pct | DECIMAL(5,2) | Solar as % of total | solar_mw / total_renewable_mw * 100 |
| wind_share_pct | DECIMAL(5,2) | Wind as % of total | wind_mw / total_renewable_mw * 100 |
| hydro_share_pct | DECIMAL(5,2) | Hydro as % of total | hydro_mw / total_renewable_mw * 100 |

### `renewable_growth` (Growth calculations)
Derived via three-way self-join in Script 03. Expected: 80 rows (8 countries x 10 years).

| Column | Type | Description | Derivation |
|--------|------|-------------|------------|
| iso_code | VARCHAR(3) | Country (FK) | From renewable_summary |
| country_name | VARCHAR(100) | Standardised name | From renewable_summary |
| year | INTEGER | 2015-2024 | From renewable_summary |
| total_renewable_mw | DECIMAL(12,2) | Current year capacity | curr.total_renewable_mw |
| prev_year_mw | DECIMAL(12,2) | Previous year capacity | prev.total_renewable_mw (NULL for 2015) |
| absolute_growth_mw | DECIMAL(12,2) | MW added this year | curr - prev (NULL for 2015) |
| yoy_growth_pct | DECIMAL(8,2) | Year-on-year growth % | (curr - prev) / prev * 100 (NULL for 2015) |
| cumulative_growth_since_2015_pct | DECIMAL(8,2) | Growth vs 2015 baseline | (curr - base) / base * 100 (0 for 2015) |

## Join Keys

| Key | Type | Notes |
|-----|------|-------|
| iso_code | VARCHAR(3) | Primary join key across all tables |
| year | INTEGER | Secondary join key |

**Grain:** Country-Year (80 records = 8 countries × 10 years)

## Missing Value Handling

| Source | Raw Value | Cleaned Value | Rationale |
|--------|-----------|---------------|-----------|
| IRENA | "-" | 0 (zero) | Technology confirmed not deployed in that country-year; treated as known absence, not missing data |
| IRENA | numeric | numeric | Direct conversion to DECIMAL |
| World Bank | ".." | NULL | Data not yet reported by national statistics office; genuinely unknown, preserved as NULL to avoid misleading analysis |
| World Bank | numeric | numeric | Direct conversion to appropriate type |

**Why this distinction matters:** If Myanmar has "-" for wind energy, it means Myanmar has zero installed wind capacity (a real, known value). If Myanmar has ".." for electricity consumption in 2024, it means the World Bank has not yet received that data from Myanmar's statistics office (unknown). Treating both as zero would undercount missing data; treating both as NULL would lose confirmed information.

## Known Limitations

1. IRENA 2024 figures may be preliminary estimates
2. On-grid only; off-grid (rural Cambodia, Myanmar) underreported
3. Capacity ≠ generation; does not reflect intermittency or curtailment
4. World Bank energy indicators lag 1-2 years (2024 mostly ".." except population)

## File Manifest

| File | Location | Description | Expected Rows |
|------|----------|-------------|---------------|
| irena_electricity_statistics.csv | data/raw/ | IRENA capacity 2015-2024 | 480 data + headers |
| irena_renewable_share.csv | data/raw/ | IRENA RE share (supplementary) | 80 data + headers |
| worldbank_wdi_asean.csv | data/raw/ | World Bank WDI indicators | 32 data + headers |
| renewable_capacity_clean.csv | data/cleaned/ | Cleaned technology-level | 480 (8 x 6 x 10) |
| renewable_summary.csv | data/cleaned/ | Aggregated country-year | 80 (8 x 10) |
| renewable_growth.csv | data/cleaned/ | Growth calculations | 80 (8 x 10) |
| worldbank_indicators_clean.csv | data/cleaned/ | Cleaned WB indicators | 80 (8 x 10) |
| 01-04_*.sql | sql/ | Sequential SQL pipeline | N/A |

## References

- ACE (2020) The 6th ASEAN Energy Outlook 2017–2040. ASEAN Centre for Energy, Jakarta. Available at:
https://aseanenergy.org/the-6th-asean-energy-outlook/ (Accessed: February 2026).

- IEA (2024) Southeast Asia Energy Outlook 2024. International Energy Agency, Paris. Available at:
https://www.iea.org/reports/southeast-asia-energy-outlook-2024 (Accessed: February 2026).

- IRENA (2025) Renewable Capacity Statistics 2025. International Renewable Energy Agency, Abu Dhabi.
Available at: https://www.irena.org/Data (Accessed: February 2026).

- World Bank (2025) World Development Indicators. Washington, DC. Available at:
https://databank.worldbank.org/ (Accessed: February 2026).
