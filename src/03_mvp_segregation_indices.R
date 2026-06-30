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
source(here::here
       ("src", "utils", "utils_segregation.R"))

# 1. Inputs ---------------------------------------------------------------

## Parameters
year <- 2010
lista_estados <- c("AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", 
                   "MA", "MT", "MS", "MG", "PA", "PB", "PR", "PE", "PI", 
                   "RJ", "RN", "RS", "RO", "RR", "SC", "SP", "SE", "TO")

# Get geographic data for Brazil (silver: transformed/joined product from 01)
sf_geo_br <- sfarrow::st_read_parquet(
  here(
    "data", "2_silver", "geo_br.parquet")
)

# Get census tract data for Brazil (bronze: raw censobr pull from 02)
# Could be incorporated in the function!!
census_tracts_br <- arrow::read_parquet(
  here(
    "data", "1_bronze", "census_tracts_br.parquet")
)

# 2. Estimate -------------------------------------------------------------

# Initialize accumulator list
all_results <- list()

# For each state in the list of states, calculate segregation indices
# Could be part of the function 
for(st in lista_estados) {
  
  message("--- Starting process: ", st, " ---")
  
  # prepare data for segregation indices calculation
  # Could be included in each index estimation function!
  tracts_segreg <- prepare_data(st, census_tracts_br, year)
  
  # indices are defined only where branca + preta + parda > 0
  tracts_index <- tracts_segreg %>% filter(tract_total > 0)
  
  # calculate dissimilarity index
  local_diss <- calculate_local_dissimilarity(tracts_index)
  global_diss <- calculate_global_dissimilarity(local_diss)
  
  # calculate exposure index
  local_expo  <- calculate_local_exposure(tracts_index)
  global_expo <- calculate_global_exposure(local_expo)
  
  # calculate H index (entropy-based)
  agregate_local_expo  <- calculate_local_exposure_agregate(tracts_index)
  agragate_global_expo <- calculate_global_exposure(agregate_local_expo)
  
  local_index_h  <- calculate_local_h(tracts_index)
  global_index_h <- calculate_global_h(local_index_h)
  
  # accumulate results for this state
  all_results[[st]] <- list(
    local_diss = local_diss,
    global_diss = global_diss,
    local_expo = local_expo,
    global_expo = global_expo,
    agregate_local_expo = agregate_local_expo,
    agragate_global_expo = agragate_global_expo,
    local_index_h = local_index_h,
    global_index_h = global_index_h,
    percent_summary = tracts_segreg %>%
      distinct(unit_id, unit_type, unit_total, branca_total, preta_total,
               amarela_total, parda_total, indigena_total),
    percent_summary_tract = tracts_segreg %>%
      distinct(code_tract, branca, preta, parda, amarela, indigena, tract_total)
  )
  
  message("--- Process completed: ", st, " ---")
}

# combine all states
local_diss <- bind_rows(map(all_results, "local_diss"))
global_diss <- bind_rows(map(all_results, "global_diss"))
local_expo <- bind_rows(map(all_results, "local_expo"))
global_expo <- bind_rows(map(all_results, "global_expo"))
agregate_local_expo <- bind_rows(map(all_results, "agregate_local_expo"))
agragate_global_expo <- bind_rows(map(all_results, "agragate_global_expo"))
local_index_h <- bind_rows(map(all_results, "local_index_h"))
global_index_h <- bind_rows(map(all_results, "global_index_h"))

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
  reduce(full_join, by = c("unit_id", "unit_type", "code_tract"))  %>%
  # adjust columns
  select(-c(global_entropy)) %>%
  # reposition columns
  select(unit_id, unit_type, code_tract, everything())

segregation_indices_local <- # list of estimated indices to apply join function
  list_segregation_indices_local %>%
  # apply full_join sequentially to integrate all indices into a single data frame
  reduce(full_join, by = c("unit_id", "unit_type", "code_tract"))  %>%
  # adjust columns
  select(-c(local_entropy)) %>%
  # reposition columns
  select(unit_id, unit_type, code_tract, everything())

#
segregation_indices_raw <- bind_rows(
  segregation_indices_global,
  segregation_indices_local
) %>%
  # adjust columns
  mutate(
    # unit_type = "metro" means unit_id is a RM name; "muni" means it is a code_muni
    name_metro = if_else(unit_type == "metro", unit_id, NA_character_),
    # totals of RM keep code_muni = "Total" to preserve backwards compatibility
    code_muni = case_when(
      unit_type == "metro" & code_tract == "Total" ~ "Total",
      unit_type == "metro" ~ NA_character_,
      TRUE ~ unit_id)
  ) %>%
  select(
    name_metro, code_muni, unit_type, code_tract, everything(), -unit_id
  )


segregation_indices <- bind_rows(
  # tracts outside RM (only have unit_type = "muni")
  segregation_indices_raw %>%
    filter(is.na(name_metro) & code_tract != "Total"),
  
  # tracts inside RM (unit_type = "muni" and "metro")
  segregation_indices_raw %>%
    filter(!is.na(name_metro) & code_tract != "Total") %>%
    left_join(
      sf_geo_br %>% st_drop_geometry() %>%
        filter(code_tract != "Total") %>%
        distinct(code_muni, code_tract),
      by = "code_tract"
    ) %>%
    mutate(code_muni = coalesce(code_muni.y, code_muni.x)) %>%
    select(-code_muni.x, -code_muni.y),
  
  # totals per municipality or RM
  segregation_indices_raw %>%
    filter(code_tract == "Total")
) %>%
  select(name_metro, code_muni, unit_type, code_tract, everything())


# join for census tracts (tract level)
sf_tracts <- sf_geo_br %>%
  filter(code_tract != "Total") %>%
  left_join(
    segregation_indices %>% 
      filter(code_tract != "Total") %>%
      select(code_tract, unit_type, dissimilarity, index_h, exp_branca_pp, 
             exp_pp_branca, iso_branca_branca, iso_pp_pp),
    by = "code_tract",
    relationship = "one-to-many"  # tracts inside RM have 2 index rows (muni + metro)
  )

# totals per municipality
sf_totals_muni <- sf_geo_br %>%
  filter(code_tract == "Total" & code_muni != "Total") %>%
  left_join(
    segregation_indices %>%
      filter(code_tract == "Total" & unit_type == "muni") %>%
      select(code_muni, unit_type, code_tract, dissimilarity, index_h,
             exp_branca_pp, exp_pp_branca, iso_branca_branca, iso_pp_pp),
    by = c("code_muni", "code_tract")
  )

# totals per RMs
sf_totals_rm <- sf_geo_br %>%
  filter(code_tract == "Total" & code_muni == "Total") %>%
  left_join(
    segregation_indices %>%
      filter(code_tract == "Total" & unit_type == "metro") %>%
      select(name_metro, unit_type, code_tract, dissimilarity, index_h,
             exp_branca_pp, exp_pp_branca, iso_branca_branca, iso_pp_pp),
    by = c("name_metro", "code_tract")
  )

# Adds population proportion columns by racial group at the census tract level
percent_tract <- bind_rows(map(all_results, "percent_summary_tract")) %>%
  add_percent_cols_tract() %>%
  select(code_tract, starts_with("n_"), starts_with("percent_"))

#Adds population proportion columns by racial group at the municipality/RM level
percent_summary <- bind_rows(map(all_results, "percent_summary")) %>%
  add_percent_cols() %>%
  select(unit_id, unit_type, starts_with("n_"), starts_with("percent_"))

#Split by level
percent_rm <- percent_summary %>%
  filter(unit_type == "metro") %>%
  rename(name_metro = unit_id) %>%
  select(-unit_type)

percent_muni <- percent_summary %>%
  filter(unit_type == "muni") %>%
  rename(code_muni = unit_id) %>%
  select(-unit_type)

sf_segregation_indices <- bind_rows(
  sf_tracts      %>% left_join(percent_tract, by = "code_tract"),
  sf_totals_muni %>% left_join(percent_muni,  by = "code_muni"),
  sf_totals_rm   %>% left_join(percent_rm,    by = "name_metro")
)

# 3. Export ---------------------------------------------------------------

# GOLD tier: consolidated, consumption-ready indices. fs::dir_create is quiet
# and recursive by default (no showWarnings argument — that belongs to base::dir.create).
gold_dir <- here::here("data", "3_gold")
fs::dir_create(gold_dir)

# Get list of all segregation indices to export
list_segregation_indices <- c(list_segregation_indices_global, list_segregation_indices_local)

# export each index as a separate Parquet file (DAT-01: parquet for data layers)
map2(
  list_segregation_indices,
  names(list_segregation_indices),
  ~ arrow::write_parquet(
    .x,
    here::here("data", "3_gold", paste0(.y, ".parquet"))
  )
)

# export the integrated data frame with all indices as a single parquet file
sfarrow::st_write_parquet(
  sf_segregation_indices,
  here::here("data", "3_gold", "sf_segregation_indices.parquet")
)

# 4. Check ----------------------------------------------------------------
# Exploratory previews (interactive maps/tables). Guarded by interactive() so a
# pipeline run (Rscript / make) does not trigger view()/leaflet side effects.
# For durable, shareable figures, prefer a notebook under reports/.
if (interactive()) {
sf_segregation_indices %>%
  filter(name_metro == "Rm Belo Horizonte") %>%
  view()

# Static map with ggplot2
ggplot() +
  geom_sf(
    data = sf_segregation_indices %>% filter(name_metro == "Rm Belo Horizonte" & code_tract != "Total"),
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
    data = sf_segregation_indices %>% filter(name_metro == "Rm Rio de Janeiro" & code_tract != "Total"),
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
    data = sf_segregation_indices %>% filter(name_muni == "Ribeirão das Neves" & code_tract != "Total"),
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
    data = sf_segregation_indices %>% filter(name_metro == "Rm Belo Horizonte" & code_tract != "Total"),
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
}
