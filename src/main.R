
# Environment Setup ---------------------------------------------------------

if (!requireNamespace("renv", quietly = TRUE)) {
  stop("renv not found. Run install.packages('renv') and renv::restore().",
       call. = FALSE)
}

options(scipen = 999)

# Package Dependencies ------------------------------------------------------

library(here)
library(fs) 
library(sf)
library(tidyverse)
library(tidylog)
library(geobr) 
library(censobr)
library(arrow) 
library(sfarrow)

# Project files and modules -----------------------------------------------

source(here("src", "utils", "constants.R"))
source(here("src", "utils", "utils_log.R"))
source(here("src", "utils", "utils_segregation.R"))

source(here("src", "01_geo_br.R"))
source(here("src", "02_population.R"))
source(here("src", "03_mvp_segregation_indices.R"))

# 3. Pipeline Execution --------------------------------------------------------

results_by_year <- list()

for (year in CENSO_YEARS) {
  
  log_info("Starting pipeline for year: ", year)
  
  geo_data <- build_geo_br(year, TARGET_STATES)
  export_geo_br(geo_data, year)
  
  population_data <- read_population_data(year)
  export_population_data(population_data, year)
  
  # Segregation indices calculation
  inputs <- read_segregation_inputs(year)
  segregation_data <- build_segregation_data(year, TARGET_STATES, inputs)
  export_segregation_data(segregation_data, year)
  
  results_by_year[[as.character(year)]] <- segregation_data
  
  log_success("Pipeline completed for year: ", year)
}

# 4. Final Dataset -------------------------------------------------

# Remove not used geobr columns
final_data <- bind_rows(results_by_year) %>%
  select(-any_of(c("code_neighborhood", "name_neighborhood", "code_district", 
                   "name_district", "code_subdistrict", "name_subdistrict",
                   "zone", "code_region", "name_region")))

final_path <- file.path(GOLD_DIR, "sf_segregation_indices_all_years.parquet")
st_write_parquet(final_data, final_path)
log_success("Combined segregation data exported: ", final_path)