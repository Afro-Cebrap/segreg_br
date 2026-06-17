#!/usr/bin/env Rscript
# =====================================================================
# main.R — segreg_br pipeline orchestrator
# ---------------------------------------------------------------------
# Portable alternative to the `makefile` (does not require `make` to be
# installed, which helps Windows collaborators).
# Usage:   Rscript main.R
#
# Runs, in ISOLATED R sessions and in the correct order:
#   setup -> 01_geo_br -> 02_population -> 03_mvp_segregation_indices
#
# Before anything else it bootstraps the reproducible environment via renv
# it restores the library from renv.lock. If the lockfile is still
# "decorative" (only renv/R), the `setup` step fails loudly with a clear
# message to run renv::snapshot() — so this script doubles as the entry
# point for reproducibility, not just execution.
# =====================================================================

# --- 0. Reproducible environment (renv) -----------------------------
# The project .Rprofile already activates renv on session start; here we
# just make sure the local library is in sync with renv.lock.
if (!requireNamespace("renv", quietly = TRUE)) {
  stop("renv not found. Run install.packages('renv') and renv::restore().",
       call. = FALSE)
}
message("• renv::restore() — syncing the library with renv.lock")
renv::restore(prompt = FALSE)

# --- 1. Pipeline definition (order matters) -------------------------
steps <- c(
  setup      = "src/utils/setup.R",            # verify packages + create directories
  geo        = "src/01_geo_br.R",              # geobr   -> data/2_silver
  population = "src/02_population.R",           # censobr -> data/1_bronze
  indices    = "src/03_mvp_segregation_indices.R"  # indices -> data/3_gold
)

# --- 2. Executor: each step in a clean R session --------------------
# Same isolation as the makefile (one session per script). Each subprocess
# re-activates renv via .Rprofile, so it uses the same restored library.
rscript <- file.path(R.home("bin"), "Rscript")  # cross-platform (Win: resolves Rscript.exe)

run_step <- function(name, path) {
  if (!file.exists(path)) {
    stop(sprintf("Script not found: %s (run from the project root)", path),
         call. = FALSE)
  }
  message(sprintf("\n=== [%s] %s ===", name, path))
  t0 <- Sys.time()
  status <- system2(rscript, args = shQuote(path))   # inherits CWD (project root)
  dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  if (!identical(status, 0L) && !identical(status, 0)) {
    stop(sprintf("Step '%s' FAILED (exit %s) after %.1fs. Pipeline aborted.",
                 name, status, dt), call. = FALSE)
  }
  message(sprintf("✓ [%s] done in %.1fs", name, dt))
}

# --- 3. Run ---------------------------------------------------------
message("▶ Starting segreg_br pipeline\n")
t_start <- Sys.time()

for (name in names(steps)) {
  run_step(name, steps[[name]])
}

total <- as.numeric(difftime(Sys.time(), t_start, units = "secs"))
message(sprintf("\n✅ Pipeline complete in %.1fs", total))
