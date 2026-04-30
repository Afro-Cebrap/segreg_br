# 0. Setup ----------------------------------------------------------------

# Options
options(scipen = 999) # Disable scientific notation for numbers

# libraries
library(here) # For file path management
library(fs) # For file system operations
library(censobr) # For accessing Brazilian census data
library(tidyverse) # For data manipulation and visualization
library(tidylog) # For logging tidyverse operations
library(geobr) # For accessing Brazilian geographic data
library(leaflet) # For interactive maps
library(arrow) # For reading and writing data in Parquet format
library(sfarrow) # For reading and writing spatial data in Parquet format

# Custom functions to calculate segregation indices
#source("scripts/utils_segregation.R")
source(here::here(
  "R", "utils_segregation.R")
)

# 1. Inputs ---------------------------------------------------------------

## Parameters
year <- 2010
# lista_estados <- c("AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", 
#                    "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", 
#                    "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO")
lista_estados <- c("MG")

# Get geographic data for Brazil
sf_geo_br <- sfarrow::st_read_parquet(
  here(
    "data", "geo_br.parquet")
)

# Get population data for Brazil
population_br <- arrow::read_parquet(
  here(
    "data", "population_br.parquet")
)

# Get census tract data for Brazil
# Could be incorporated in the function!!
census_tracts_br <- arrow::read_parquet(
  here(
    "data", "census_tracts_br.parquet")
)

# TEMPORARY!!
# Get segregation indices estimated via QGIS plugin segreg 
# for the tracts not covered in the MVP estimation 
# to ensure we have all tracts covered for the MVP
sf_qgis_segregation_indices <- sfarrow::st_read_parquet(
  here::here(
    "data",
    "qgis",
    "indices_segreg.parquet")
)

# TEMPORARY!!
# To integrate population data and geometry!
qgis_segregation_indices <- sf_qgis_segregation_indices %>%
  st_drop_geometry() %>%
  transmute(
    code_muni = as.character(code_muni),
    code_tract = as.character(cod_setor),
    dissimilarity = dissimil,
    index_h
  )

# 2. Estimate -------------------------------------------------------------

# For each state in the list of states, calculate segregation indices
# Could be part of the function 
for(st in lista_estados) {
  
  message("--- Starting process: ", st, " ---")
  
  # prepare data for segregation indices calculation
  # Could be included in each index estimation function!
  tracts_segreg <- prepare_data(st, census_tracts_br, year)
  
  # calculate dissimilarity index
  local_diss <- calculate_local_dissimilarity(tracts_segreg)
  global_diss <- calculate_global_dissimilarity(local_diss)
  
  # calculate exposure index
  local_expo  <- calculate_local_exposure(tracts_segreg)
  global_expo <- calculate_global_exposure(local_expo)
  
  # calculate H index (entropy-based)
  agregate_local_expo  <- calculate_local_exposure_agregate(tracts_segreg)
  agragate_global_expo <- calculate_global_exposure(agregate_local_expo)
  
  local_index_h  <- calculate_local_h(tracts_segreg)
  global_index_h <- calculate_global_h(local_index_h)
  
  message("--- Process completed: ", st, " ---")
}


# TEMPORARY!!
# Adjust naming!!
local_diss <- local_diss %>%
  rename(dissimilarity = tract_contrib)
# Adjust naming
global_index_h <- global_index_h %>%
  rename(index_h = h_index_global)
# Adjust naming
local_index_h <- local_index_h %>%
  rename(index_h = h_local)

# list of estimated indices - global
list_segregation_indices_global <- list(
  global_diss = global_diss %>% mutate(code_tract = "Total"),
  global_index_h = global_index_h %>% mutate(code_tract = "Total"),
  agragate_global_expo = agragate_global_expo %>% mutate(code_tract = "Total")
)

# list of estimated indices - local
list_segregation_indices_local <- list(
  local_diss = local_diss,
  local_index_h = local_index_h %>% select(-global_entropy),
  agregate_local_expo = agregate_local_expo
)

#
segregation_indices_global <- # list of estimated indices to apply join function
  list_segregation_indices_global %>%
  # apply full_join sequentially to integrate all indices into a single data frame
  reduce(full_join) %>%
  # adjust columns
  select(-c(global_entropy)) %>%
  # reposition columns
  select(unit_id, code_tract, everything()) %>%
  rename(
    code_muni = unit_id
  )

segregation_indices_local <- # list of estimated indices to apply join function
  list_segregation_indices_local %>%
  # apply full_join sequentially to integrate all indices into a single data frame
  reduce(full_join) %>%
  # adjust columns
  select(-c(local_entropy)) %>%
  # reposition columns
  select(unit_id, code_tract, everything()) %>%
  rename(
    code_muni = unit_id
  )

#
segregation_indices_raw <- full_join(
  segregation_indices_global,
  segregation_indices_local
) %>%
  # adjust columns
  mutate(
    # if code_muni is not numeric, then that is a metro area named as the name_muni
    name_metro = if_else(!str_detect(code_muni, "^\\d+$"), code_muni, NA_character_),
    # if code_muni is not numeric and code tract is "Total", then that is total not for a municipality, but a metro area 
    # if_code_muni is numeric and code tract is "Total", then that is total for a municipality
    code_muni = case_when(
      !str_detect(code_muni, "^\\d+$") & code_tract == "Total" ~ "Total", 
      !str_detect(code_muni, "^\\d+$") ~ NA_character_,
      TRUE ~ code_muni)
  ) %>%
  select(
    name_metro, everything()
  )

# TEMPORARY!!
segregation_indices_mg_rm <- segregation_indices_raw %>%
  filter(code_muni == "Total") %>%
  left_join(population_br) 

# TEMPORARY!!
segregation_indices_mg_rm_tract <- segregation_indices_raw %>%
  filter(!is.na(name_metro) & code_tract != "Total") %>%
  select(-c(code_muni)) %>%
  left_join(sf_geo_br %>% st_drop_geometry() %>% select(code_muni, code_tract),
            by = c("code_tract")) %>%
  left_join(population_br) %>%
  select(name_metro, code_muni, code_tract, everything())

# TEMPORARY!!
segregation_indices_mg_muni_tract <- segregation_indices_raw %>%
  filter(is.na(name_metro)) %>%
  select(-name_metro) %>%
  left_join(population_br)

#
list_code_tracts_mvp <- c(
  segregation_indices_raw %>%
    filter(code_tract != "Total") %>%
    pull(code_tract)
)

#
segregation_indices <- segregation_indices_mg_muni_tract %>%
  full_join(segregation_indices_mg_rm_tract) %>%
  full_join(segregation_indices_mg_rm) %>%
  # Add the remaining tracts estimated via QGIS plugin segreg 
  # to ensure we have all tracts covered for the MVP
  full_join(
    qgis_segregation_indices %>%
      filter(!code_tract %in% list_code_tracts_mvp) %>% # only those out of MG State
      left_join(population_br)
  ) %>%
  select(
    name_metro, everything()
  )


# TEMPORARY
sf_segregation_indices <- sf_geo_br %>%
  left_join(segregation_indices)


# 3. Export ---------------------------------------------------------------

# creat folder if it doesn't exist
fs::dir_create(here::here("outputs", "mvp"), showWarnings = FALSE)

# Get list of all segregation indices to export
list_segregation_indices <- c(list_segregation_indices_global, list_segregation_indices_local)

# export each index as a separate CSV file
map2(
  list_segregation_indices,
  names(list_segregation_indices),
  ~ write_csv(
    .x,
    here::here("outputs", "mvp", paste0(.y, ".csv"))
  )
)

# export the integrated data frame with all indices as a single parquet file
sfarrow::st_write_parquet(
  sf_segregation_indices,
  here::here("outputs", "mvp", "sf_segregation_indices.parquet")
)

# 4. Check ----------------------------------------------------------------

# view data for RM Belo Horizonte
sf_segregation_indices %>%
  filter(name_metro == "RM Belo Horizonte") %>%
  view()

# Static map with ggplot2
ggplot() +
  geom_sf(
    data = sf_segregation_indices %>% filter(name_metro == "RM Belo Horizonte" & code_tract != "Total"),
    aes(fill = dissimilarity)
  ) +
  scale_fill_viridis_c() +
  theme_minimal() +
  labs(
    title = "Dissimilarity Index in RM Belo Horizonte (2010)",
    fill = "Dissimilarity"
  )

# Static map with ggplot2 - RM Rio de Janeiro
ggplot() +
  geom_sf(
    data = sf_segregation_indices %>% filter(name_metro == "RM Rio de Janeiro" & code_tract != "Total"),
    aes(fill = dissimilarity)
  ) +
  scale_fill_viridis_c() +
  theme_minimal() +
  labs(
    title = "Dissimilarity Index in RM Rio de Janeiro (2010)",
    fill = "Dissimilarity"
  )

# Static map with ggplot2 - Ribeirão das Neves (municipality in RM Belo Horizonte)
ggplot() +
  geom_sf(
    data = sf_segregation_indices %>% filter(name_muni == "Ribeirão Das Neves" & code_tract != "Total"),
    aes(fill = dissimilarity)
  ) +
  scale_fill_viridis_c() +
  theme_minimal() +
  labs(
    title = "Dissimilarity Index in Ribeirão das Neves (2010)",
    fill = "Dissimilarity"
  )

# Responsive interactive map with leaflet - RM Belo Horizonte
leaflet() %>%
  addTiles() %>%
  addPolygons(
    data = sf_segregation_indices %>% filter(name_metro == "RM Belo Horizonte" & code_tract != "Total"),
    fillColor = ~colorNumeric("viridis", dissimilarity)(dissimilarity),
    fillOpacity = 0.7,
    color = "white",
    weight = 1,
    popup = ~paste0("Dissimilarity: ", round(dissimilarity, 2))
  ) %>%
  addLegend(
    pal = colorNumeric("viridis", sf_segregation_indices$dissimilarity),
    values = sf_segregation_indices$dissimilarity,
    title = "Dissimilarity Index",
    position = "bottomright"
  )

