
# Environment Management ------------------------------------

if (!requireNamespace("renv", quietly = TRUE)) {
  install.packages("renv", repos = "https://cloud.r-project.org")
}

renv::activate()
renv::restore()

critical_packages <- c(
  "here", "fs", "sf", "tidyverse", "tidylog", 
  "geobr", "censobr", "arrow", "sfarrow"
)

missing_packages <- critical_packages[
  !sapply(critical_packages, requireNamespace, quietly = TRUE)
]

if (length(missing_packages) > 0) {
  stop(
    paste("Missing packages:", paste(missing_packages, collapse = ", ")),
    call. = FALSE
  )
}


# Create Directory Structure ----------------------------------

project_dirs <- c(
  "data/1_bronze", "data/2_silver", "data/3_gold", "data/metadata",
  "sandbox", "config", "tests", "reports"
)

for (dir in project_dirs) {
  dir.create(here::here(dir), recursive = TRUE, showWarnings = FALSE)
}


# Validate Configuration Files --------------------------------

config_path <- here::here("src", "utils", "constants.R")

if (!file.exists(config_path)) {
  stop("Configuration file not found: src/utils/constants.R", call. = FALSE)
}

message("PROJECT ENVIRONMENT READY")
