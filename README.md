# territorios_negros

Data processing pipeline for the **"Mapa da Segregação"** dashboard.

## Overview

This project implements a sequential pipeline to estimate racial segregation indices across Brazilian territories using 2010 Census data. The final output is a set of optimized Parquet files that power the interactive visualization dashboard.

## Project Structure

```text
src/                    # Source code for pipelines and business logic
├── utils/              # Helper functions (GCS connections, segregation formulas)
├── 01_geo_br.R         # Geo data prep (geobr) -> data/2_silver (transformed)
├── 02_population.R     # Census pull (censobr) -> data/1_bronze (raw)
└── 03_mvp_...          # Matrix calculation of segregation indices -> data/3_gold
sandbox/                # Drafts, local validations, and QGIS tests (never sourced by src/)
services/               # Delivery layer / data products
├── app_shiny/          # Interactive R/Shiny panel
├── api/                # External data endpoints (Plumber/FastAPI)
└── plataform/          # Front-ends / landing pages
reports/                # Methodological notes, dynamic reports, and articles (Quarto/Rmd)
config/                 # Environment parameters, variables, and schemas (no credentials)
tests/                  # Automated unit tests (testthat)
data/                   # Local mirror of the medallion data lake (contents git-ignored)
├── 1_bronze/           # Raw cache of census and original vector data
├── 2_silver/           # Cleaned/integrated data (e.g. geo_br)
├── 3_gold/             # Consolidated final indices and aggregates
└── metadata/           # Data dictionary + datapackage.json (VERSIONED)
makefile                # Declarative orchestrator for infrastructure and execution
README.md               # Setup instructions and ecosystem overview
LICENSE.md              # MIT License
```

> **Medallion tiering.** Raw `read_*()` pulls land in `1_bronze`; transformed/joined
> products in `2_silver`; consumption-ready indices in `3_gold`. Tier *contents* are
> git-ignored (skeleton preserved via `.gitkeep`); `data/metadata/` is versioned.

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
