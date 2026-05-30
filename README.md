# territorios_negros

Data processing pipeline for the **"Mapa da Segregação"** dashboard.

## Overview

This project implements a sequential pipeline to estimate racial segregation indices across Brazilian territories using 2010 Census data. The final output is a set of optimized Parquet files that power the interactive visualization dashboard.

## Project Structure

```text
src/                    # Source code for pipelines and business logic
├── utils/              # Helper functions (GCS connections, segregation formulas)
├── 01_geo_br.R         # Initial censobr/geobr load to GCP/Local
├── 02_population.R     # Spatial joins and demographic cleaning
└── 03_mvp_...          # Matrix calculation of segregation indices
sandbox/                # Drafts, local validations, and QGIS tests
reports/                # Methodological notes, dynamic reports, and articles (Quarto/Rmd)
config/                 # Environment parameters, variables, and schemas
tests/                  # Automated unit tests (testthat)
data/
├── 1_bronze/           # Raw cache of census and original vector data
├── 2_silver/           # Cleaned and standardized data at census tract level
├── 3_gold/             # Consolidated final indices and aggregates
└── metadata/           # Schema files and structured Data Lake dictionaries
makefile                # Declarative orchestrator for infrastructure and execution
README.md               # Setup instructions and ecosystem overview
LICENSE.md              # MIT License
```

## Setup & Execution

### 1. Environment Setup
The project uses `renv` for dependency management.
```r
source("src/utils/setup.R")
```

### 2. Pipeline Execution
Execute the scripts in `src/` in numerical order:
1. `src/01_geo_br.R`: Prepare geographic data.
2. `src/02_population.R`: Process population data.
3. `src/03_mvp_segregation_indices.R`: Calculate segregation indices.

Alternatively, if you have `make` installed:
```bash
make all
```

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
