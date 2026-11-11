# Data Dictionary — Integrated Master Dataset

> Converted from `data_dictionary.docx` for reading on GitHub. The .docx is the original submitted version.

MSIN0304 | Team 3 | SDG 7: Affordable and Clean Energy

Data Dictionary: integrated_master_from_sql.csv

40 columns | 56 rows | 8 countries | Years 2015 to 2021

Grain: one row = one country in one year | Join keys: country_code + year

### Data Pipeline and Lineage

The dataset is produced by a four-stage pipeline. Each stage is independently reproducible by running the numbered scripts in sequence from the code/ folder against team3_sdg7.db.

Stage 1 – Cleaning (00_clean_raw_data.py): Raw CSV files from IRENA, IEA, WDI, and IMF are standardised: country names mapped to ISO alpha-3 codes, categorical IEA strings converted to numeric with boolean flags, and units harmonised (current USD, MW, 0–100 percentages). Output: four clean_slice*.csv files.

Stage 2 – Schema and Loading (01–02): 01_create_tables.sql creates dim_country, fact_spine (CROSS JOIN), and four staging tables (stg_renewable, stg_access, stg_grid, stg_economic). 02_load_data.sql populates them from the cleaned CSVs.

Stage 3 – Integration (03): 03_integration.sql creates v_integrated_master by LEFT JOINing all four staging tables to fact_spine on country_code + year (stg_access joins on country_code alone due to its snapshot structure). Output: integrated_master_from_sql.csv (36 columns, 56 rows).

Stage 4 – QC and Index (04–05): 04_qc_checks.sql runs 10 structured quality checks. 05_priority_index.sql applies min–max normalisation and weighted aggregation to produce the composite index, followed by 5 index validation checks and 5 sensitivity analyses. Output: integrated_master_with_index.csv (40 columns, 56 rows).

### How to read this document

Every column in the integrated master dataset is defined below. Columns are grouped by which data slice contributed them. Groups 1–6 cover the 36 columns from integrated_master_from_sql.csv. Group 7 covers the 4 composite-index columns added by the priority-index pipeline (integrated_master_with_index.csv). The Source column identifies the exact dataset and organisation. The Unit column specifies what the numbers represent. The Definition column explains what the metric means and notes any known data characteristics that affect interpretation.

Approximation flags (columns whose names begin with approx_) are integer values where 1 means the corresponding value in that row was substituted from a non-numeric string in the original IEA source. These flags are for documentation and QC purposes only and should not be used as analytical variables in Tableau.

### Group 1: Identity Columns (4 columns)

| Column name | Source | Unit | Definition |
|---|---|---|---|
| country_code | Derived | ISO 3166-1 alpha-3 | Three-letter standardised country identifier. All source name variants (e.g. Viet Nam, Lao P.D.R., Laos) were mapped to this code before loading into SQLite. This is the primary join key. |
| country_name | Derived | Text | Full country name for display in Tableau. Cambodia, Indonesia, Lao PDR, Malaysia, Myanmar, Philippines, Thailand, Vietnam. |
| year | Derived | Integer (2015 to 2021) | Calendar year. The ceiling of 2021 was set by energy_intensity_mj_gdp availability. All slices were capped at 2021 for consistent coverage across all metrics. |
| income_classification | World Bank WDI 2024 | Category | World Bank income group as of 2024. Cambodia, Indonesia, Lao PDR, Myanmar, Philippines, Vietnam are Lower-middle-income. Malaysia and Thailand are Upper-middle-income. Static attribute joined once per country across all years. |

### Group 2: Slice 1 — Renewable Energy (12 columns) | IRENA + World Bank WDI

| Column name | Source | Unit | Definition |
|---|---|---|---|
| renewable_output_pct_wdi | World Bank WDI (EG.ELC.RNEW.ZS) | Percentage (0 to 100) | Renewable electricity output as a share of total electricity output. Includes hydro, solar, wind, geothermal, and biomass. Lao PDR and Myanmar exceed 60% due to large hydro capacity. Vietnam grows from 35% in 2015 to 41% in 2021 driven by solar. |
| re_capacity_share_pct | IRENA 2024 | Percentage (0 to 100) | Renewable energy installed capacity as a share of total electricity capacity. Differs from renewable_output_pct_wdi because capacity and generation are not proportional. Higher capacity does not always mean higher generation share. |
| solar_capacity_mw | IRENA Electricity Statistics | Megawatts | On-grid solar photovoltaic installed capacity. Vietnam grows from 0.8 MW in 2015 to 16,656 MW in 2020, driven by the feed-in tariff policy introduced April 2019. Zero where the country had no installed solar in that year. |
| wind_capacity_mw | IRENA Electricity Statistics | Megawatts | On-grid onshore wind installed capacity. Zero where no capacity present. Vietnam is the only country with substantial wind capacity in this dataset. |
| hydro_capacity_mw | IRENA Electricity Statistics | Megawatts | Renewable hydropower installed capacity. Lao PDR has the highest share relative to its economy, exporting significant electricity to neighbouring countries. |
| geothermal_capacity_mw | IRENA Electricity Statistics | Megawatts | Geothermal installed capacity. Only Indonesia and Philippines have non-zero values in this dataset. |
| biogas_capacity_mw | IRENA Electricity Statistics | Megawatts | Biogas installed capacity. Minor contribution across all 8 countries. |
| offshore_wind_capacity_mw | IRENA Electricity Statistics | Megawatts | Offshore wind installed capacity. Near-zero across all countries in this period (2015 to 2021). |
| total_re_capacity_mw | Derived from IRENA | Megawatts | Sum of solar, wind, hydro, geothermal, biogas, and offshore wind capacity. Verified: equals the arithmetic sum of the six component columns for all 56 rows. |
| elec_access_pct_wdi_annual | World Bank WDI (EG.ELC.ACCS.ZS) | Percentage (0 to 100) | Annual electricity access rate from World Bank household surveys. Cambodia and Myanmar show non-monotonic trends (values fluctuate year to year). These reflect survey methodology revisions in the WDI source, not cleaning errors. |
| electricity_consumption_kwh_pc | World Bank WDI (EG.USE.ELEC.KH.PC) | kWh per person per year | Per capita electricity consumption. Malaysia (around 4,800 kWh) and Thailand (around 2,700 kWh) are highest. Myanmar (around 270 kWh) and Cambodia (around 350 to 700 kWh) are lowest, reflecting both lower access rates and lower industrial demand. |
| population_total_count | World Bank WDI (SP.POP.TOTL) | Raw person count | Total population as a raw count (not millions). Indonesia is the largest at 261 to 277 million. Used to scale impact potential metrics. To convert to millions, divide by 1,000,000. |

### Group 3: Slice 3 — Grid Infrastructure (2 columns) | World Bank WDI

| Column name | Source | Unit | Definition |
|---|---|---|---|
| td_losses_pct | World Bank WDI (EG.ELC.LOSS.ZS) | Percentage of electricity output | Transmission and distribution losses as a share of total electricity output. Lower values indicate a more efficient grid. Malaysia shows near-constant values around 6.897% across all years, confirmed in the raw WDI source as a reporting methodology characteristic. Lao PDR drops sharply from 15.7% in 2015 to 5.4% in 2016, corresponding to new hydro infrastructure coming online. |
| energy_intensity_mj_gdp | World Bank WDI (EG.EGY.PRIM.PP.KD) | Megajoules per USD 2021 PPP GDP | Primary energy intensity. Lower values indicate more energy-efficient economic activity. A declining trend signals that an economy is growing without proportionally increasing energy use. Thailand and Malaysia are most energy-intensive in this group. Philippines is most efficient. |

### Group 4: Slice 4 — Economic Context (4 columns) | IMF WEO + World Bank WDI/WBGI

| Column name | Source | Unit | Definition |
|---|---|---|---|
| gdp_growth_pct | IMF World Economic Outlook 2024 | Percentage | Annual real GDP growth rate. Myanmar falls to -9.0% in 2020 (COVID-19) and -12.0% in 2021 (military coup, February 2021). Philippines falls to -9.5% in 2020. Vietnam grew 2.9% in 2020, one of the few positive figures globally during COVID-19. |
| gdp_per_capita_usd | IMF World Economic Outlook 2024 | Current USD per person | GDP per capita at current prices in USD. Malaysia (around USD 9,500 to 11,500) and Thailand (around USD 5,800 to 7,800) are highest. Myanmar (around USD 1,000 to 1,400) is lowest, amplified by the 2021 coup impact. |
| fdi_usd_millions | World Bank WDI (BX.KLT.DINV.CD.WD) | USD millions | Net FDI inflows in USD millions. Converted from raw USD by dividing by 1,000,000. Thailand shows -4,293.9 million in 2020, a confirmed net capital outflow during COVID-19. This is real data and is retained without modification. Vietnam consistently receives 11,800 to 15,500 million USD per year. |
| regulatory_quality_wbgi | World Bank Governance Indicators | Score (-2.5 to +2.5) | Regulatory quality score from the World Bank Worldwide Governance Indicators. Higher positive scores indicate a stronger regulatory environment for private investment. Malaysia (+0.66 to +0.71) and Indonesia (improving from -0.16 toward +0.29) score highest. Myanmar (-0.62 to -1.25) and Lao PDR (-0.76 to -0.91) score lowest. |

### Group 5: Slice 2 — Energy Access (8 values + 3 flags = 11 columns) | IEA 2023

Important: these columns come from IEA energy access snapshots at 2015 and 2022 only. There is no annual data. The same value repeats across all 7 rows per country. These columns must only be used in Tableau visuals where country is on the axis, not year. Do not use them in time-series line charts.

| Column name | Source | Unit | Definition |
|---|---|---|---|
| elec_access_2015_pct_iea | IEA Energy Access 2023 | Percentage (0 to 100) | IEA modelled electricity access rate at 2015. Differs from elec_access_pct_wdi_annual (World Bank survey data) by up to 30.5 percentage points for Myanmar, reflecting different methodologies. Both are retained with source labels. |
| elec_access_2022_pct_iea | IEA Energy Access 2023 | Percentage (0 to 100) | IEA modelled electricity access rate at 2022. Values of 99 for Indonesia, Malaysia, Thailand, Vietnam represent a substitution from the original string greater than 99 percent. See approx_elec_access_2022 flag. |
| elec_access_improve_pp_iea | Derived from IEA | Percentage points | Change in electricity access from 2015 to 2022. Cambodia improved by 44 pp. Myanmar improved by 34 pp. The large improvement in Myanmar despite starting from only 30% in 2015 makes it a high-impact investment target. |
| elec_access_2022_urban_pct_iea | IEA Energy Access 2023 | Percentage (0 to 100) | Urban electricity access rate at 2022. Most countries are at 98 to 99 percent for urban populations. |
| elec_access_2022_rural_pct_iea | IEA Energy Access 2023 | Percentage (0 to 100) | Rural electricity access rate at 2022. Myanmar at 48% rural vs 98% urban shows the most severe urban-rural divide in the dataset, a gap of 50 percentage points. |
| pop_without_elec_access_2022m_iea | IEA Energy Access 2023 | Millions of people | Population without electricity access at 2022 in millions. Myanmar at 20 million is the highest in this group. Values of 0.5 represent a substitution from the original string less than 1 million. See approx_pop_without_elec_2022 flag. |
| cooking_access_2015_pct_iea | IEA Energy Access 2023 | Percentage (0 to 100) | Clean cooking access rate at 2015. Very low for Cambodia (21%), Lao PDR (6%), and Myanmar (21%). Values of 3 for these three countries represent a substitution from the original string less than 5 percent. |
| cooking_access_2022_pct_iea | IEA Energy Access 2023 | Percentage (0 to 100) | Clean cooking access rate at 2022. Philippines remains at only 48% despite near-universal electricity access, showing that electricity access and clean cooking access are distinct problems requiring separate solutions. |
| cooking_access_improve_pp_iea | Derived from IEA | Percentage points | Change in clean cooking access from 2015 to 2022. Vietnam improved by 15 pp. Indonesia improved by 18 pp. Lao PDR improved by only 4 pp, remaining at 10% in 2022, the lowest in the group. |
| pop_without_cooking_2022m_iea | IEA Energy Access 2023 | Millions of people | Population without clean cooking access in 2022 in millions. Philippines at 60 million is the largest absolute clean cooking gap in this dataset. Myanmar at 33 million and Indonesia at 41 million are also significant. |
| pop_biomass_2022m_iea | IEA Energy Access 2023 | Millions of people | Population still using traditional biomass for cooking in 2022 in millions. Closely tracks pop_without_cooking_2022m_iea. The difference between the two represents populations using other unclean fuels (charcoal, kerosene, coal). |

### Group 6: Approximation Flags (3 columns)

These three columns document exactly where non-numeric strings in the IEA source were substituted with numeric values. They are for QC and documentation only. Do not include them in Tableau visualisations.

| Column name | Source | Unit | Definition |
|---|---|---|---|
| approx_elec_access_2022 | Derived cleaning flag | Integer (0 or 1) | 1 means elec_access_2022_pct_iea was substituted from the string greater than 99 percent to the value 99. Applies to Indonesia, Malaysia, Thailand, Vietnam. |
| approx_cooking_access_2015 | Derived cleaning flag | Integer (0 or 1) | 1 means cooking_access_2015_pct_iea was substituted from the string less than 5 percent to the value 3 (midpoint of 0 to 5 range). Applies to Cambodia, Lao PDR, Myanmar. |
| approx_pop_without_elec_2022 | Derived cleaning flag | Integer (0 or 1) | 1 means pop_without_elec_access_2022m_iea was substituted from the string less than 1 to the value 0.5 (midpoint of 0 to 1 range). Applies to all countries except Myanmar and Philippines, which had numeric values. |

### Group 7: Composite Index (4 columns) | Derived

| Column name | Source | Unit | Definition |
|---|---|---|---|
| component_impact | Derived | Score (0 to 100) | Impact Potential sub-index. Weighted 40% of the total Priority Index. Combines electricity access gap, clean cooking gap, and access improvement speed using min-max normalisation. |
| component_readiness | Derived | Score (0 to 100) | Market Readiness sub-index. Weighted 30% of the total Priority Index. Combines renewable output share, grid efficiency (inverted T&D losses), energy intensity (inverted), and installed RE capacity. |
| component_viability | Derived | Score (0 to 100) | Economic Viability sub-index. Weighted 30% of the total Priority Index. Combines GDP growth, FDI inflows, regulatory quality, and GDP per capita. |
| priority_index | Derived | Score (0 to 100) | Composite Clean Energy Investment Priority Index. Weighted sum of component_impact (40%), component_readiness (30%), and component_viability (30%). Scored 0 to 100 via min-max normalisation across all 56 country-year observations. Myanmar averages 53.16, Philippines 47.59, Indonesia 45.50. Higher scores indicate greater investment priority. |

## Known Data Anomalies

These are confirmed characteristics of the source data, not cleaning errors. Each one must be mentioned in the report.

| Anomaly | What the data shows | Why it is real |
|---|---|---|
| Malaysia T&D losses constant | 6.897% in all 7 years with no variation | Confirmed in raw World Bank WDI source. Reflects consistent national grid reporting methodology, not a data error or cleaning failure. |
| Lao PDR T&D drop 2015 to 2016 | 15.7% in 2015 drops to 5.4% in 2016 and stays low | Corresponds to commissioning of Nam Ngiep hydropower project and expansion of Nam Theun 2. New infrastructure dramatically reduced system losses. This is a key analytical insight. |
| Cambodia electricity access non-monotonic | Access rises to 89% in 2017 then falls to 80% in 2018 | World Bank WDI applies survey methodology revisions across years, causing apparent backward movement. Real trend is upward overall from 62% to 82%. |
| Myanmar electricity access non-monotonic | Drops from 60% in 2015 to 55% in 2016 then rises | Same reason as Cambodia: WDI survey methodology revisions. Overall trend is upward from 60% to 72%. |
| Vietnam solar 20,000x growth 2015 to 2020 | 0.8 MW in 2015 becomes 16,656 MW in 2020 | Vietnam's feed-in tariff policy introduced April 2019 triggered a massive solar build-out. Confirmed in IRENA source. The single most dramatic pattern in the entire dataset. |
| Myanmar GDP -12% in 2021 | Deepest contraction in the dataset | Military coup February 2021. IMF data confirmed. Critical investment risk signal. |
| Thailand FDI negative in 2020 | -4,293.9 million USD | Net capital outflow during COVID-19. Real and confirmed in World Bank WDI source. Retained without modification. |

Team 3 | MSIN0304 | UCL School of Management | 2025 to 2026
