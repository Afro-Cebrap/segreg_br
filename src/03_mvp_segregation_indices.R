
# Reads geographic and population inputs for the specified year
# Parameters:
#   year: Census year
# Returns:
#   List with geographic and population data
read_segregation_inputs <- function(year) {
  sf_geo_br <- st_read_parquet(
    file.path(SILVER_DIR, sprintf("geo_br_%s.parquet", year))
  )
  census_data <- read_parquet(
    file.path(BRONZE_DIR, sprintf("census_tracts_br_%s.parquet", year))
  )
  
  list(sf_geo_br = sf_geo_br, census_data = census_data)
}

# Calculates segregation indices and population summaries for one state
# Parameters:
#   state: State will be processed
#   sf_geo_br: Geographic data for the census year
#   census_data: Population data for the census year
#   year: Census year
# Returns:
#   List with segregation indices and population summaries for the state.
process_state <- function(state, sf_geo_br, census_data, year) {
  tracts_segreg <- prepare_data(state, sf_geo_br, census_data, year)
  tracts_index <- tracts_segreg %>% filter(tract_total > 0)
  
  local_diss <- calculate_local_dissimilarity(tracts_index)
  global_diss <- calculate_global_dissimilarity(local_diss)
  
  aggregate_local_expo <- calculate_local_exposure(tracts_index)
  aggregate_global_expo <- calculate_global_exposure(aggregate_local_expo)
  
  local_index_h <- calculate_local_h(tracts_index)
  global_index_h <- calculate_global_h(local_index_h)
  
  list(
    local_diss = local_diss,
    global_diss = global_diss,
    aggregate_local_expo = aggregate_local_expo,
    aggregate_global_expo = aggregate_global_expo,
    local_index_h = local_index_h,
    global_index_h = global_index_h,
    percent_summary = tracts_segreg %>%
      distinct(unit_id, unit_type, unit_total, branca_total, preta_total,
               amarela_total, parda_total, indigena_total),
    percent_summary_tract = tracts_segreg %>%
      distinct(code_tract, branca, preta, parda, amarela, indigena, tract_total)
  )
}

# Processes segregation data for all specified states
# Parameters:
#   states: Array with all states
#   sf_geo_br: Geographic data for the census year
#   census_data: Population data for the census year
#   year: Census year
# Returns:
#   List with one result per state
process_all_states <- function(states, sf_geo_br, census_data, year) {
  states %>%
    set_names() %>%
    map(~ process_state(.x, sf_geo_br, census_data, year))
}

# Consolidates local and global segregation indices from all states
# Parameters:
#   state_results: Output from process_all_states().
#   sf_geo_br: Geographic data for the census year.
# Returns:
#   Data with segregation indices by census tract and totals by
#   municipality and metropolitan area.
build_segregation_indices <- function(state_results, sf_geo_br) {
  local_diss <- bind_rows(map(state_results, "local_diss"))
  global_diss <- bind_rows(map(state_results, "global_diss"))
  aggregate_local_expo <- bind_rows(map(state_results, "aggregate_local_expo"))
  aggregate_global_expo <- bind_rows(map(state_results, "aggregate_global_expo"))
  local_index_h <- bind_rows(map(state_results, "local_index_h"))
  global_index_h <- bind_rows(map(state_results, "global_index_h"))
  
  indices_global <- list(
    global_diss %>% mutate(code_tract = "Total"),
    global_index_h %>% mutate(code_tract = "Total"),
    aggregate_global_expo %>% mutate(code_tract = "Total")
  ) %>%
    reduce(full_join, by = c("unit_id", "unit_type", "code_tract")) %>%
    select(-global_entropy) %>%
    select(unit_id, unit_type, code_tract, everything())
  
  indices_local <- list(
    local_diss,
    local_index_h %>% select(-global_entropy),
    aggregate_local_expo
  ) %>%
    reduce(full_join, by = c("unit_id", "unit_type", "code_tract")) %>%
    select(-local_entropy) %>%
    select(unit_id, unit_type, code_tract, everything())
  
  indices_raw <- bind_rows(indices_global, indices_local) %>%
    mutate(
      name_metro = if_else(unit_type == "metro", unit_id, NA_character_),
      code_muni = case_when(
        unit_type == "metro" & code_tract == "Total" ~ "Total",
        unit_type == "metro" ~ NA_character_,
        TRUE ~ unit_id
      )
    ) %>%
    select(name_metro, code_muni, unit_type, code_tract, everything(), -unit_id)
  
  bind_rows(
    # Municipality level census tract indices
    indices_raw %>% filter(is.na(name_metro), code_tract != "Total"),
    
    # Metropolitan level census tract indices
    indices_raw %>%
      filter(!is.na(name_metro), code_tract != "Total") %>%
      left_join(
        sf_geo_br %>%
          st_drop_geometry() %>%
          filter(code_tract != "Total") %>%
          distinct(code_muni, code_tract),
        by = "code_tract"
      ) %>%
      mutate(code_muni = coalesce(code_muni.y, code_muni.x)) %>%
      select(-code_muni.x, -code_muni.y),
    
    # Municipality and metropolitan area totals
    indices_raw %>% filter(code_tract == "Total")
  ) %>%
    select(name_metro, code_muni, unit_type, code_tract, everything())
}

# Links segregation indices to census tract, municipality and metro geometries.
# Parameters:
#   sf_geo_br: Geographic data for the census year.
#   segregation_indices: Output from build_segregation_indices().
# Returns:
#   List with spatial data for census tracts, municipalities and
#   metropolitan areas.
build_spatial_data <- function(sf_geo_br, segregation_indices) {
  sf_tracts <- sf_geo_br %>%
    filter(code_tract != "Total") %>%
    left_join(
      segregation_indices %>%
        filter(code_tract != "Total") %>%
        select(code_tract, unit_type, all_of(SEGREGATION_METRICS)),
      by = "code_tract",
      relationship = "one-to-many"
    )
  
  sf_totals_muni <- sf_geo_br %>%
    filter(code_tract == "Total", code_muni != "Total") %>%
    left_join(
      segregation_indices %>%
        filter(code_tract == "Total", unit_type == "muni") %>%
        select(code_muni, unit_type, code_tract, all_of(SEGREGATION_METRICS)),
      by = c("code_muni", "code_tract")
    )
  
  sf_totals_rm <- sf_geo_br %>%
    filter(code_tract == "Total", code_muni == "Total") %>%
    left_join(
      segregation_indices %>%
        filter(code_tract == "Total", unit_type == "metro") %>%
        select(name_metro, unit_type, code_tract, all_of(SEGREGATION_METRICS)),
      by = c("name_metro", "code_tract")
    )
  
  list(
    sf_tracts = sf_tracts,
    sf_totals_muni = sf_totals_muni,
    sf_totals_rm = sf_totals_rm
  )
}

# Calculates population proportions for census tracts, municipalities and metros.
# Parameters:
#   state_results: Output from process_all_states().
# Returns:
#   List with population proportions for each geographic level.
build_population_data <- function(state_results) {
  percent_tract <- bind_rows(map(state_results, "percent_summary_tract")) %>%
    add_percent_cols_tract() %>%
    select(code_tract, starts_with("n_"), starts_with("percent_"))
  
  percent_summary <- bind_rows(map(state_results, "percent_summary")) %>%
    add_percent_cols() %>%
    select(unit_id, unit_type, starts_with("n_"), starts_with("percent_"))
  
  percent_muni <- percent_summary %>%
    filter(unit_type == "muni") %>%
    rename(code_muni = unit_id) %>%
    select(-unit_type)
  
  percent_rm <- percent_summary %>%
    filter(unit_type == "metro") %>%
    rename(name_metro = unit_id) %>%
    select(-unit_type)
  
  list(
    percent_tract = percent_tract,
    percent_muni = percent_muni,
    percent_rm = percent_rm
  )
}

# Combines spatial segregation indices with population proportions.
# Parameters:
#   spatial_data: Output from build_spatial_data().
#   population_data: Output from build_population_data().
# Returns:
#   Complete spatial segregation dataset.
build_final_data <- function(spatial_data, population_data) {
  bind_rows(
    spatial_data$sf_tracts %>%
      left_join(population_data$percent_tract, by = "code_tract"),
    
    spatial_data$sf_totals_muni %>%
      left_join(population_data$percent_muni, by = "code_muni"),
    
    spatial_data$sf_totals_rm %>%
      left_join(population_data$percent_rm, by = "name_metro")
  )
}

# Builds the complete segregation dataset for the specified year.
# Parameters:
#   year: Census year to process.
#   states: Vector with state abbreviations.
#   inputs: Output from read_segregation_inputs().
# Returns:
#   Complete spatial segregation data for the census year.
build_segregation_data <- function(year, states, inputs) {
  state_results <- process_all_states(
    states, inputs$sf_geo_br, inputs$census_data, year
  )
  
  segregation_indices <- build_segregation_indices(
    state_results, inputs$sf_geo_br
  )
  
  spatial_data <- build_spatial_data(
    inputs$sf_geo_br, segregation_indices
  )
  
  population_data <- build_population_data(state_results)
  
  build_final_data(spatial_data, population_data) %>%
    mutate(year = year)
}

# Exports segregation data for one census year to the gold layer.
# Parameters:
#   data: Output from build_segregation_data().
#   year: Census year used in the file name.
# Returns:
#   Path of the exported Parquet file.
export_segregation_data <- function(data, year) {
  dir_create(GOLD_DIR)
  path <- file.path(GOLD_DIR, sprintf("sf_segregation_indices_%s.parquet", year))
  
  st_write_parquet(data, path)
  log_success("segregation data exported: ", path)
  
  invisible(path)
}