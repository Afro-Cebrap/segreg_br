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
year <- 2010


# 1. Population data ------------------------------------------------------

# Get tracts data for the specified year and dataset
census_tracts_br <- censobr::read_tracts(year, dataset = "Pessoa", as_data_frame = TRUE, cache = TRUE)

# TEMPORARY!!
#sf_qgis_segregation_indices <- sfarrow::st_read_parquet(
#  here::here(
#    "data",
#    "qgis",
#    "indices_segreg.parquet")
#)

# TEMPORARY!!
# To integrate population data and geometry!
#qgis_segregation_indices <- sf_qgis_segregation_indices %>%
#  st_drop_geometry() %>%
#  transmute(
#    code_muni = as.character(code_muni),
#    code_tract = as.character(cod_setor),
#    dissimilarity = dissimil,
#    index_h
#  )

# TEMPORARY!!
# To integrate population data and geometry!
#qgis_population_tracts <- sf_qgis_segregation_indices %>%
#  st_drop_geometry() %>%
#  mutate(
#    code_muni = as.character(code_muni),
#    code_tract = as.character(cod_setor),
#  ) %>%
#  select(-c(dissimil, entropy, index_h, cod_setor)) %>%
#  left_join(key_geo_br) %>%
#  select(name_metro, code_muni, code_tract, everything())

#
#qgis_population_rm <- qgis_population_tracts %>%
#  filter(!is.na(name_metro)) %>%
#  group_by(name_metro) %>%
#  summarize(
#    code_muni = "Total",
#    code_tract = "Total",
#    n_branca = sum(n_branca, na.rm = TRUE),
#    n_preta_ou_parda = sum(n_preta_ou_parda, na.rm = TRUE),
#    n_preta = sum(n_preta, na.rm = TRUE),
#    n_amarela = sum(n_amarela, na.rm = TRUE),
#    n_parda = sum(n_parda, na.rm = TRUE),
#    n_indigena = sum(n_indigena, na.rm = TRUE),
#    n_total = sum(n_total, na.rm = TRUE)
#  ) %>%
#  mutate(
#    percent_branca = n_branca / n_total,
#    percent_preta_ou_parda = n_preta_ou_parda / n_total,
#    percent_preta = n_preta / n_total,
#    percent_amarela = n_amarela / n_total,
#    percent_parda = n_parda / n_total,
#    percent_indigena = n_indigena / n_total
#  )

#
#qgis_population_muni <- qgis_population_tracts %>%
#  group_by(code_muni) %>%
#  summarize(
#    name_metro = first(name_metro), # Assuming name_metro is the same for all tracts within the same municipality
#    code_tract = "Total",
#    n_branca = sum(n_branca, na.rm = TRUE),
#    n_preta_ou_parda = sum(n_preta_ou_parda, na.rm = TRUE),
#    n_preta = sum(n_preta, na.rm = TRUE),
#    n_amarela = sum(n_amarela, na.rm = TRUE),
#    n_parda = sum(n_parda, na.rm = TRUE),
#    n_indigena = sum(n_indigena, na.rm = TRUE),
#    n_total = sum(n_total, na.rm = TRUE)
#  ) %>%
#  mutate(
#    percent_branca = n_branca / n_total,
#    percent_preta_ou_parda = n_preta_ou_parda / n_total,
#    percent_preta = n_preta / n_total,
#    percent_amarela = n_amarela / n_total,
#    percent_parda = n_parda / n_total,
#    percent_indigena = n_indigena / n_total
#  )

#
#qgis_population <- bind_rows(
#  qgis_population_tracts,
#  qgis_population_muni,
#  qgis_population_rm
#) 

# 2. Export ---------------------------------------------------------------

# Export the census tracts data to a Parquet file
arrow::write_parquet(
  census_tracts_br,
  here(
    "data", "census_tracts_br.parquet")
)

# TEMPORARY!!
# Export the combined population data to a Parquet file
#arrow::write_parquet(
#  qgis_population,
#  here(
#    "data", "population_br.parquet")
#)

