# 0. Setup ----------------------------------------------------------------

#
options(scipen = 999) # Disable scientific notation for numbers

library(here) # For file path management
library(sf) # For spatial data manipulation
library(censobr) # For accessing Brazilian census data
library(tidyverse) # For data manipulation and visualization
library(tidylog) # For logging tidyverse operations
library(arrow) # For reading and writing data in Parquet format

## Parameters
year <- 2022


# 1. Population data ------------------------------------------------------

# Get tracts data for the specified year and dataset
census_tracts_br <- censobr::read_tracts(year, dataset = "Pessoas", as_data_frame = TRUE, cache = TRUE)

# 2. Export ---------------------------------------------------------------

# census_tracts_br is an untouched read_*() pull from censobr -> BRONZE tier.
# Create the exact target subdirectory before writing so a clean clone does not
# fail if 01 has not run yet.
if (!dir.exists(here("data", "1_bronze"))) {
  dir.create(here("data", "1_bronze"), recursive = TRUE)
}

# Export the census tracts data to a Parquet file (bronze)
arrow::write_parquet(
  census_tracts_br,
  here(
    "data", "1_bronze", "census_tracts_br_2022.parquet")
)


