
# Returns the censo dataset name for the specified year
# Parameters:
#   year: Census year
# Returns:
#   Dataset name used by censobr
get_censo_population <- function(year) {
  dataset <- CENSO_DATASET_BY_YEAR[[as.character(year)]]
  
  if (is.null(dataset)) {
    log_error(sprintf("Population dataset not configured for year: %s", year))
  }
  
  dataset
}

# Reads population data by census tract for the specified year
# Parameters:
#   year: Census year
# Returns:
#   Population data by census tract
read_population_data <- function(year) {
  dataset <- get_censo_population(year)
  read_tracts(year, dataset = dataset, as_data_frame = TRUE, cache = TRUE)
}

# Exports population data to the bronze layer
# Parameters:
#   data: Output from read_population_data()
#   year: Census year used in the file name
# Returns:
#   Path of the exported Parquet file
export_population_data <- function(data, year) {
  dir_create(BRONZE_DIR)
  path <- file.path(BRONZE_DIR, sprintf("census_tracts_br_%s.parquet", year))
  
  write_parquet(data, path)
  log_success("population exported: ", path)
  
  invisible(path)
}