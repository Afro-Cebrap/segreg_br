# territorios_negros

Data processing pipeline for the **"Mapa da Segregação"** dashboard.

## Overview

This project implements a sequential pipeline to estimate racial segregation indices across Brazilian territories using 2010 Census data. The final output is a set of optimized Parquet files that power the interactive visualization dashboard.

## Project Structure

- `src/`: Sequential processing scripts:
    - `01_geo_br.R`: Geographic data preparation.
    - `02_population.R`: Population data processing.
    - `03_mvp_segregation_indices.R`: Calculation of segregation indices.
- `R/`: Reusable helper functions (spatial utilities, index formulas).
- `data/`: Raw and intermediate datasets (ignored by Git).
- `outputs/`: Final Parquet files and visualization artifacts (ignored by Git).
- `reports/`: Technical documentation and validation reports.

## Pipeline Execution

To reproduce the data layer:
1.  Open `territorios_negros.Rproj`.
2.  Run `renv::restore()` to sync the local environment.
3.  Execute scripts in `src/` in numerical order.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
