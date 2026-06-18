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
year <- 2010
lista_estados <- c("AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT", 
                   "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO", 
                   "RR", "SC", "SP", "SE", "TO")

# 1. Geospatial data ---------------------------------------------------------------

# Get geo data for municipalities in metropolitan areas (geometry by municipality)
sf_muni_metro_br <- geobr::read_metro_area(year = 2010, cache = TRUE) %>%
  mutate(code_muni = as.character(code_muni))%>%
  # geobr names these "Ride ..." (not "RIDE"), so a case-sensitive "RIDE"
  # match never fires and every RIDE leaks through. RIDEs span >1 state and
  # would be aggregated once per state -> duplicate, partial rows. Match
  # case-insensitively on the word "ride".
  filter(!str_detect(name_metro, regex("\\bride\\b", ignore_case = TRUE)))

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

# read_metro_area() returns ONE ROW PER MUNICIPALITY-MEMBERSHIP and a single
# municipality can appear in several rows (one per `legislation` act). Any join
# that carries `legislation` (or any per-municipality column) therefore fans out
# and duplicates rows. We collapse to the attributes that are constant per metro
# (one row per name_metro) before joining metadata back to the unioned geometry.
metro_meta <- sf_muni_metro_br %>%
  st_drop_geometry() %>%
  group_by(name_metro) %>%
  summarise(
    abbrev_state = paste(sort(unique(abbrev_state)), collapse = "/"),
    .groups = "drop"
  )

# Get geo data for metropolitan areas (geometry by metropolitan area)
sf_metro_br <- sf_key_metro_br %>%
  left_join(metro_meta, by = "name_metro") %>%
  mutate(
    code_tract = "Total",
    code_muni = "Total"
  )

# One row per municipality mapping code_muni -> name_metro. distinct() collapses
# the multiple legislation rows that read_metro_area() returns per municipality,
# so the join below cannot fan out.
muni_metro_key <- sf_muni_metro_br %>%
  st_drop_geometry() %>%
  distinct(code_muni, name_metro)

# Get geo data for municipalities (geometry by municipality)
sf_muni_br <- geobr::read_municipality(year = 2010, cache = TRUE) %>%
  mutate(code_muni = as.character(code_muni)) %>%
  # integrate specific data for metropolitan areas (one row per municipality)
  left_join(muni_metro_key, by = "code_muni") %>%
  mutate(
    code_tract = "Total"
  )

# Get geo data for census tracts (geometry by census tract)
sf_tracts_br <- lista_estados %>%
  map_df(
    ~geobr::read_census_tract(code_tract = .x, year = 2010, cache = TRUE)
  ) %>%
  mutate(
    code_muni = as.character(code_muni),
    code_tract = as.character(code_tract)
  ) %>%
  # integrate specfic data for municipalities + metropolitan areas
  left_join(
    sf_muni_br %>% 
      st_drop_geometry() %>%
      select(-code_tract)
  )

# 
sf_geo_br <- bind_rows(
  sf_tracts_br,
  sf_muni_br,
  sf_metro_br
) 

# Export ------------------------------------------------------------------

# geo_br is a TRANSFORMED product (union of metro geometries + joins to the
# municipality/tract hierarchy), so by medallion semantics it belongs in the
# SILVER tier, not bronze/raw. Create the exact target subdirectory before writing.
if (!dir.exists(here("data", "2_silver"))) {
  dir.create(here("data", "2_silver"), recursive = TRUE)
}

# Export the combined geospatial data to a Parquet file (silver)
sfarrow::st_write_parquet(
  sf_geo_br,
  here(
    "data", "2_silver", "geo_br.parquet")
)

