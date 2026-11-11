# Raw data

Only **Slice 1** raw files are included. They are the same IRENA and World Bank exports
used in [`01-renewable-capacity-slice`](../../../01-renewable-capacity-slice/data/raw/),
and `clean_raw_data.py --slices 1` reproduces `clean_slice1_renewable.csv` exactly.

Slices 2–4 were cleaned by other team members, and their original exports are not in this
repository. Their cleaned outputs are in `../processed/`, so the full database and index
can still be rebuilt with `scripts/build_database.py`.

To re-run cleaning for every slice, place the files like this:

```
data/raw/
├── slice1/  worldbank_wdi_asean.csv, irena_electricity_statistics.csv, irena_renewable_share.csv
├── slice2/  Electricity_access.csv, Clean_cooking.csv                      (IEA Energy Access)
├── slice3/  Dataset 1/aa915b1f-affa-4a9b-bfd8-a6d531c801ff_Data.csv        (World Bank WDI export)
└── slice4/  raw_gdp_growth.csv, raw_gdp_per_capita.csv                     (IMF WEO)
             raw_fdi.csv, raw_regulatory_quality.csv                        (World Bank WDI / WGI)
             raw_income_classification.csv
```
