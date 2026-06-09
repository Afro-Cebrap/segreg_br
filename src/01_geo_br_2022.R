# 0. Setup ----------------------------------------------------------------

#
options(scipen = 999) # Disable scientific notation for numbers

library(here) # For file path management
library(sf) # For spatial data manipulation
library(tidyverse) # For data manipulation and visualization
library(tidylog) # For logging tidyverse operations
library(geobr) # For accessing Brazilian geographic data
library(sfarrow) # For reading and writing spatial data in Parquet format

## Parameters
year <- 2022 # let's work with 2022 metropolitan areas for 2022 analyzes
lista_estados <- c("AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", 
                   "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", 
                   "RR", "SC", "SP", "SE", "TO")

# 1. Geospatial data ---------------------------------------------------------------

# Get geo data for municipalities in metropolitan areas (geometry by municipality)
sf_muni_metro_br <- geobr::read_metro_area(year = 2022, cache = TRUE) %>%
  mutate(code_muni = as.character(code_muni))%>%
  filter(!str_detect(name_metro, "RIDE"))

# Spatial key for metropolitan areas
sf_key_metro_br <- sf_muni_metro_br %>%
  # Make sure geometries are valid and fix any issues
  st_make_valid() %>%
  # Apply a small buffer to fix potential geometry issues (e.g., self-intersections)
  st_buffer(0) %>%
  # The geometry of metro must be estimated by the union of the geometry of the municipalities that compose it
  # to integrate with the population data and geometry of the tracts
  group_by(name_metro) %>%
  summarise(
    geom = st_union(geometry)
  ) %>%
  ungroup()

# Get geo data for metropolitan areas (geometry by metropolitan area)
sf_metro_br <- sf_key_metro_br %>%
  left_join(sf_muni_metro_br %>%
              st_drop_geometry() %>%
              select(-c(code_muni, name_muni, legislation_date)) %>%
              distinct()
  ) %>%
  mutate(
    code_muni = "Total"
  )

# Get geo data for municipalities (geometry by municipality)
sf_muni_br <- geobr::read_municipality(year = 2022, cache = TRUE) %>%
  mutate(code_muni = as.character(code_muni)) %>%
  # integrate specific data for metropolitan areas
  left_join(
    sf_muni_metro_br %>%
      st_drop_geometry()
  )

# 
sf_geo_br <- bind_rows(
  sf_muni_br,
  sf_metro_br
)

# Export ------------------------------------------------------------------

# Create data directory if it does not exist
if (!dir.exists(here("data"))) {
  dir.create(here("data"), recursive = TRUE)
}
if (!dir.exists(here("data","1_raw"))) {
  dir.create(here("data","1_raw"), recursive = TRUE)
}

# Export the combined geospatial data to a Parquet file
sfarrow::st_write_parquet(
  sf_geo_br,
  here(
    "data", "1_raw", "geo_br_2022.parquet")
)

