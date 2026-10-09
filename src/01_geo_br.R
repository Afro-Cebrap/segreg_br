
# Reads and cleans metropolitan area data for the specified year
# Parameters:
#   year: Census year
# Returns:
#   Spatial data with municipalities and their metropolitan areas
read_metro_data <- function(year) {
  metro_data <- read_metro_area(year = year, cache = TRUE) %>%
    mutate(code_muni = as.character(code_muni)) %>%
    filter(!str_detect(name_metro, regex(REGEX_RIDE_NAME, ignore_case = TRUE)))
  
  if ("type" %in% names(metro_data)) {
    metro_data <- metro_data %>%
      filter(!str_detect(type, regex(REGEX_RIDE_TYPE, ignore_case = TRUE)))
  }
  
  if (year == 2022) {
    metro_data <- metro_data %>%
      mutate(name_metro = str_replace(name_metro, REGEX_METRO_NAME_2022, "RM "))
  }
  
  metro_data <- metro_data %>%
    filter(!name_metro %in% EXCLUDED_METRO_AREAS)
  
  # Ensure each municipality belongs at most one metropolitan area
  duplicates <- metro_data %>%
    st_drop_geometry() %>%
    distinct(code_muni, name_metro) %>%
    count(code_muni) %>%
    filter(n > 1)
  
  if (nrow(duplicates) > 0) {
    log_error(sprintf(
      "read_metro_data(%s): %d municipalities in multiple metro areas: %s",
      year, nrow(duplicates), paste(duplicates$code_muni, collapse = ", ")
    ))
  }
  
  metro_data
}

# Builds one metropolitan area geometry from municipality metro data
# Parameters:
#   metro_data: Output from read_metro_data()
# Returns:
#   Spatial data with one row per metropolitan area
build_metro_data <- function(metro_data) {
  key_metro <- metro_data %>%
    st_make_valid() %>%
    st_buffer(0) %>%
    group_by(name_metro) %>%
    summarise(geometry = st_union(geometry)) %>%
    ungroup()
  
  # Group metadata to avoid duplicate municipality legislation records
  metro_meta <- metro_data %>%
    st_drop_geometry() %>%
    group_by(name_metro) %>%
    summarise(abbrev_state = paste(sort(unique(abbrev_state)), collapse = "/"),
              .groups = "drop")
  
  key_metro %>%
    left_join(metro_meta, by = "name_metro") %>%
    mutate(code_tract = "Total", code_muni = "Total")
}

# Reads municipality data and links each municipality to its metropolitan area
# Parameters:
#   year: Census year
#   metro_data: Output from read_metro_data()
# Returns:
#   Spatial data with one row per municipality and code_tract = "Total"
build_municipality_data <- function(year, metro_data) {
  muni_metro_key <- metro_data %>%
    st_drop_geometry() %>%
    distinct(code_muni, name_metro)
  
  read_municipality(year = year, cache = TRUE) %>%
    mutate(code_muni = as.character(code_muni)) %>%
    left_join(muni_metro_key, by = "code_muni") %>%
    mutate(code_tract = "Total")
}

# Reads census tracts data and links each tract to municipality and metro data
# Parameters:
#   year: Census year
#   states: State will be processed
#   municipality_data: Municipality spatial data
# Returns:
#   Spatial data with one row per census tract.
build_tract_data <- function(year, states, municipality_data) {
  tract_data <- states %>%
    map_dfr(~ read_census_tract(code_tract = .x, year = year, cache = TRUE)) %>%
    mutate(code_tract = as.character(code_tract),
           code_muni = as.character(code_muni),
           .row_id = row_number()) %>%
    # Drop to avoid attribute conflicts when merging multipart tracts
    select(-any_of("code_weighting"))
  
  # Handle tracts represented by multiple geometry parts
  duplicate_codes <- tract_data %>%
    st_drop_geometry() %>%
    count(code_tract) %>%
    filter(n > 1) %>%
    pull(code_tract)
  
  if (length(duplicate_codes) > 0) {
    duplicated_tracts <- tract_data %>%
      filter(code_tract %in% duplicate_codes)
    
    # Ensure repeated codes differ only by geometry
    attribute_conflicts <- duplicated_tracts %>%
      st_drop_geometry() %>%
      select(-.row_id) %>%
      distinct() %>%
      count(code_tract) %>%
      filter(n > 1)
    
    if (nrow(attribute_conflicts) > 0) {
      log_error(sprintf(
        "build_tract_data(%s): %d tract codes have conflicting attributes.",
        year, nrow(attribute_conflicts)
      ))
    }
    
    attribute_columns <- setdiff(names(tract_data), 
                                 c("code_tract", ".row_id", 
                                   attr(tract_data, "sf_column")))
    
    # Merge geometry parts
    duplicated_tracts <- duplicated_tracts %>%
      group_by(code_tract) %>%
      summarise(across(all_of(attribute_columns), first),
                .row_id = min(.row_id), do_union = TRUE, .groups = "drop")
    
    tract_data <- bind_rows(
      tract_data %>% filter(!code_tract %in% duplicate_codes),
      duplicated_tracts
    ) %>% arrange(.row_id)
  }
  
  tract_data %>%
    select(-.row_id) %>%
    left_join(municipality_data %>%
                st_drop_geometry() %>%
                select(code_muni, name_metro),
              by = "code_muni", relationship = "many-to-one")
}

# Builds the complete geographic dataset for the specified year.
# Parameters:
#   year: Census year to process.
#   states: Vector with state abbreviations.
# Returns:
#   Spatial data containing census tracts, municipalities and metropolitan areas.
build_geo_br <- function(year, states) {
  metro_data <- read_metro_data(year)
  metro_data_built <- build_metro_data(metro_data)
  municipality_data <- build_municipality_data(year, metro_data)
  tract_data <- build_tract_data(year, states, municipality_data)
  
  bind_rows(tract_data, municipality_data, metro_data_built) %>%
    mutate(year = .env$year)
}

# Exports geographic data to the silver layer.
# Parameters:
#   data: Output from build_geo_br().
#   year: Census year used in the file name.
# Returns:
#   Path of the exported Parquet file.
export_geo_br <- function(data, year) {
  dir_create(SILVER_DIR)
  path <- file.path(SILVER_DIR, sprintf("geo_br_%s.parquet", year))
  
  st_write_parquet(data, path)
  log_success("geo_br exported: ", path)
  
  invisible(path)
}