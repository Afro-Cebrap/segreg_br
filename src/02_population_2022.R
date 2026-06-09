# 0. Setup ----------------------------------------------------------------

#
options(scipen = 999) # Disable scientific notation for numbers

library(here) # For file path management
library(sf) # For spatial data manipulation
library(censobr) # For accessing Brazilian census data
library(tidyverse) # For data manipulation and visualization
library(tidylog) # For logging tidyverse operations
library(arrow) # For reading and writing data in Parquet format
library(sidrar) # For reading data from SIDRA IBGE

# 1. Population data ------------------------------------------------------

# Importing data at municipal unity from SIDRA
# obs.: this API was generated based on the table creator in the SIDRA website

census_munic_br <- sidrar::get_sidra(api = "/t/9606/n6/all/v/allxp/p/last%201/c86/allxt/c2/6794/c287/100362")

# 2. Data handling --------------------------------------------------------

# selecting variables of interest
census_munic_br <- census_munic_br |> 
  select(c(6,12,5))

# renaming them

colnames(census_munic_br) <- c("code_munic","race","n")

# get dataset as similar as dataset for 2010

census_munic_br <- census_munic_br |> 
  mutate(
    race = case_when(
      race == 2776 ~ "pessoa03_V002",
      race == 2777 ~ "pessoa03_V003",
      race == 2778 ~ "pessoa03_V004",
      race == 2779 ~ "pessoa03_V005",
      race == 2780 ~ "pessoa03_V006"
    )
  ) |> 
  pivot_wider(
    names_from = "race",
    values_from = "n"
  )


# 3. Export ---------------------------------------------------------------

# Export the census tracts data to a Parquet file
arrow::write_parquet(
  census_munic_br,
  here(
    "data", "1_raw", "census_munic_br_2022.parquet")
)
