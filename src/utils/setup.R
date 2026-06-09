# setup.R - Project Environment Setup
# Run this once after cloning the project

cat("\n📦 Setting up territorios_negros project environment...\n\n")

# 1. Install renv if needed
if (!requireNamespace("renv", quietly = TRUE)) {
  cat("Installing renv...\n")
  install.packages("renv", repos = "https://cloud.r-project.org")
}

# 2. Activate renv for this project
cat("Activating renv environment...\n")
renv::activate()

# 3. Restore packages from lockfile
cat("Restoring packages from renv.lock...\n")
renv::restore()

# 4. Verify key packages are installed
cat("\nVerifying critical packages...\n")
critical_packages <- c("here", "fs", "sf", "tidyverse", "geobr", "censobr", "arrow", "sfarrow", "tidylog", "leaflet")
missing <- !sapply(critical_packages, function(pkg) {
  requireNamespace(pkg, quietly = TRUE)
})

if (any(missing)) {
  cat("⚠️  Missing packages:", paste(names(missing)[missing], collapse = ", "), "\n")
  cat("Installing missing packages...\n")
  install.packages(critical_packages[missing])
} else {
  cat("✅ All critical packages installed!\n")
}

# 5. Create data directories if needed
data_dirs <- c("data/1_bronze", "data/2_silver", "data/3_gold", "data/metadata", "sandbox", "config", "tests")
for (d in data_dirs) {
  if (!dir.exists(here::here(d))) {
    cat(paste0("Creating ", d, " directory...\n"))
    dir.create(here::here(d), recursive = TRUE)
  }
}

cat("\n✅ Project environment ready!\n")
cat("📝 Next steps:\n")
cat("   1. Run: source('src/01_geo_br.R')      # Build geospatial data\n")
cat("   2. Run: source('src/02_population.R')  # Extract census data\n")
cat("   3. Run: source('src/03_mvp_segregation_indices.R')  # Calculate indices\n")
cat("\n📚 For help, see TROUBLESHOOTING.md\n\n")

