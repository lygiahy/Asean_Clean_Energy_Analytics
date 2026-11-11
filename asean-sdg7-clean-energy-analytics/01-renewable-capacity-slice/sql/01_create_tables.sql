-- ============================================================================
-- MSIN0304 Data Management: Tools and Techniques
-- Assessment A1 - Individual
-- Candidate: SRLB2
-- Data Slice: Renewable Energy Capacity & Growth (SDG 7)
-- Geographic Focus: Southeast Asia (8 ASEAN Countries)
-- ============================================================================
-- Script 01: Create Tables and Import Data
-- Purpose: Set up database schema and load raw data
-- Prerequisites: SQLite3 with CSV mode enabled
-- ============================================================================
-- QUICK RUN: python scripts/run_pipeline.py   (does every step below)
-- IMPORT INSTRUCTIONS (execute in SQLite3 terminal):
--   sqlite3 sdg7_renewable.db
--   .read sql/01_create_tables.sql
--   .mode csv
--   .headers on
--   .import data/raw/irena_electricity_statistics.csv raw_electricity_stats
--   .import data/raw/worldbank_wdi_asean.csv raw_worldbank_wdi
--   (Optional: irena_renewable_share.csv is included for cross-validation
--    but is not imported as a table; see Script 02 Part C for details.)
--   .read sql/02_data_cleaning.sql
--   .read sql/03_analysis_queries.sql
--   .read sql/04_bridge_query.sql
-- ============================================================================

DROP TABLE IF EXISTS raw_electricity_stats;
DROP TABLE IF EXISTS raw_worldbank_wdi;
DROP TABLE IF EXISTS renewable_capacity;
DROP TABLE IF EXISTS renewable_summary;
DROP TABLE IF EXISTS renewable_growth;
DROP TABLE IF EXISTS worldbank_context;
DROP TABLE IF EXISTS country_lookup;

-- Dimension table: standardises country names across IRENA and World Bank
CREATE TABLE country_lookup (
    iso_code VARCHAR(3) PRIMARY KEY,
    country_name VARCHAR(100) NOT NULL,
    country_name_irena VARCHAR(100),
    country_name_wb VARCHAR(100),
    region VARCHAR(50) DEFAULT 'Southeast Asia',
    income_group VARCHAR(50),
    asean_member BOOLEAN DEFAULT TRUE
);

INSERT INTO country_lookup (iso_code, country_name, country_name_irena, country_name_wb, income_group) VALUES
('KHM', 'Cambodia', 'Cambodia', 'Cambodia', 'Lower-middle'),
('IDN', 'Indonesia', 'Indonesia', 'Indonesia', 'Upper-middle'),
('LAO', 'Laos', 'Lao People''s Democratic Republic (the)', 'Lao PDR', 'Lower-middle'),
('MYS', 'Malaysia', 'Malaysia', 'Malaysia', 'Upper-middle'),
('MMR', 'Myanmar', 'Myanmar', 'Myanmar', 'Lower-middle'),
('PHL', 'Philippines', 'Philippines (the)', 'Philippines', 'Lower-middle'),
('THA', 'Thailand', 'Thailand', 'Thailand', 'Upper-middle'),
('VNM', 'Vietnam', 'Viet Nam', 'Viet Nam', 'Lower-middle');

-- Staging table for raw IRENA CSV
CREATE TABLE raw_electricity_stats (
    country_area VARCHAR(100), technology VARCHAR(100),
    data_type VARCHAR(100), grid_connection VARCHAR(50),
    year INTEGER, value_raw VARCHAR(50)
);

-- Staging table for raw World Bank CSV
CREATE TABLE raw_worldbank_wdi (
    country_name VARCHAR(100), country_code VARCHAR(3),
    series_name VARCHAR(200), series_code VARCHAR(50),
    yr_2015 VARCHAR(50), yr_2016 VARCHAR(50), yr_2017 VARCHAR(50),
    yr_2018 VARCHAR(50), yr_2019 VARCHAR(50), yr_2020 VARCHAR(50),
    yr_2021 VARCHAR(50), yr_2022 VARCHAR(50), yr_2023 VARCHAR(50),
    yr_2024 VARCHAR(50)
);

-- Clean analysis table: IRENA capacity at technology level
CREATE TABLE renewable_capacity (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    iso_code VARCHAR(3) NOT NULL, country_name VARCHAR(100) NOT NULL,
    year INTEGER NOT NULL, technology VARCHAR(50) NOT NULL,
    technology_group VARCHAR(20) NOT NULL,
    capacity_mw DECIMAL(12,2) DEFAULT 0, capacity_gw DECIMAL(10,4) DEFAULT 0,
    CONSTRAINT valid_year CHECK (year BETWEEN 2010 AND 2030),
    CONSTRAINT valid_capacity CHECK (capacity_mw >= 0),
    CONSTRAINT unique_record UNIQUE (iso_code, year, technology),
    FOREIGN KEY (iso_code) REFERENCES country_lookup(iso_code)
);
CREATE INDEX idx_rc_country_year ON renewable_capacity(iso_code, year);

-- Clean analysis table: World Bank contextual indicators
CREATE TABLE worldbank_context (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    iso_code VARCHAR(3) NOT NULL, country_name VARCHAR(100) NOT NULL,
    year INTEGER NOT NULL, population INTEGER,
    electrification_rate_pct DECIMAL(5,2),
    renewable_elec_share_pct DECIMAL(5,2),
    elec_consumption_kwh_pc DECIMAL(10,2),
    CONSTRAINT valid_wb_year CHECK (year BETWEEN 2010 AND 2030),
    CONSTRAINT valid_elec_rate CHECK (electrification_rate_pct IS NULL OR electrification_rate_pct BETWEEN 0 AND 100),
    CONSTRAINT valid_pop CHECK (population IS NULL OR population >= 0),
    CONSTRAINT unique_wb UNIQUE (iso_code, year),
    FOREIGN KEY (iso_code) REFERENCES country_lookup(iso_code)
);
CREATE INDEX idx_wb_country_year ON worldbank_context(iso_code, year);

-- Aggregated country-year totals
CREATE TABLE renewable_summary (
    iso_code VARCHAR(3) NOT NULL, country_name VARCHAR(100) NOT NULL,
    year INTEGER NOT NULL,
    total_renewable_mw DECIMAL(12,2), total_renewable_gw DECIMAL(10,4),
    solar_mw DECIMAL(12,2), wind_mw DECIMAL(12,2),
    hydro_mw DECIMAL(12,2), other_mw DECIMAL(12,2),
    solar_share_pct DECIMAL(5,2), wind_share_pct DECIMAL(5,2),
    hydro_share_pct DECIMAL(5,2),
    CONSTRAINT unique_summary UNIQUE (iso_code, year)
);

-- Year-on-year growth calculations
CREATE TABLE renewable_growth (
    iso_code VARCHAR(3) NOT NULL, country_name VARCHAR(100) NOT NULL,
    year INTEGER NOT NULL,
    total_renewable_mw DECIMAL(12,2), prev_year_mw DECIMAL(12,2),
    absolute_growth_mw DECIMAL(12,2), yoy_growth_pct DECIMAL(8,2),
    cumulative_growth_since_2015_pct DECIMAL(8,2),
    CONSTRAINT unique_growth UNIQUE (iso_code, year)
);

SELECT 'Tables created successfully' AS status;
