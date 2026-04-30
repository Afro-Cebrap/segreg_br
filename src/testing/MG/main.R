# 0. Setup ----------------------------------------------------------------

library(here)
library(censobr)
library(dplyr)

# Custom functions to calculate segregation indices
#source("scripts/utils_segregation.R")
source(here::here(
  "R", "utils_segregation.R")
  )

# 1. Inputs ---------------------------------------------------------------

year <- 2010
lista_estados <- c("MG")

tracts_br <- read_tracts(year, dataset = "Pessoa", as_data_frame = TRUE, cache = TRUE)


# 2. Estimate -------------------------------------------------------------


for(st in lista_estados) {
  
  message("--- Starting process: ", st, " ---")
  
  tracts_segreg <- prepare_data(st, tracts_br, year)

  local_diss <- calculate_local_dissimilarity(tracts_segreg)
  global_diss <- calculate_global_dissimilarity(local_diss)

  local_expo  <- calculate_local_exposure(tracts_segreg)
  global_expo <- calculate_global_exposure(local_expo)

  agregate_local_expo  <- calculate_local_exposure_agregate(tracts_segreg)
  agragate_global_expo <- calculate_global_exposure(agregate_local_expo)
  
  local_index_h  <- calculate_local_h(tracts_segreg)
  global_index_h <- calculate_global_h(local_index_h)
  
  message("--- Process completed: ", st, " ---")
}

# 3. Export ---------------------------------------------------------------

#write.csv(tracts_segreg, paste0("data/tracts_segreg_", st, ".csv"), row.names = FALSE)
write.csv(tracts_segreg, paste0(here::here("Indicadores R", "data", "tracts_segreg_"), st, ".csv"), row.names = FALSE)

#write.csv(local_diss, paste0("output/local_diss_", st, ".csv"), row.names = FALSE)
write.csv(local_diss, paste0(here::here("Indicadores R", "output", "local_diss_"), st, ".csv"), row.names = FALSE)
#write.csv(global_diss, paste0("output/global_diss_", st, ".csv"), row.names = FALSE)
write.csv(global_diss, paste0(here::here("Indicadores R", "output", "global_diss_"), st, ".csv"), row.names = FALSE)

#write.csv(local_expo, paste0("output/local_expo_", st, ".csv"), row.names = FALSE)
write.csv(local_expo, paste0(here::here("Indicadores R", "output", "local_expo_"), st, ".csv"), row.names = FALSE)
#write.csv(global_expo, paste0("output/global_expo_", st, ".csv"), row.names = FALSE)
write.csv(global_expo, paste0(here::here("Indicadores R", "output", "global_expo_"), st, ".csv"), row.names = FALSE)

#write.csv(agregate_local_expo, paste0("output/agregate_local_expo_", st, ".csv"), row.names = FALSE)
write.csv(agregate_local_expo, paste0(here::here("Indicadores R", "output", "agregate_local_expo_"), st, ".csv"), row.names = FALSE)
#write.csv(agragate_global_expo, paste0("output/agregate_global_expo_", st, ".csv"), row.names = FALSE)
write.csv(agragate_global_expo, paste0(here::here("Indicadores R", "output", "agregate_global_expo_"), st, ".csv"), row.names = FALSE)

#write.csv(local_index_h %>% select(-global_entropy), paste0("output/local_h_", st, ".csv"), row.names = FALSE)
write.csv(local_index_h %>% select(-global_entropy), paste0(here::here("Indicadores R", "output", "local_h_"), st, ".csv"), row.names = FALSE)
#write.csv(global_index_h, paste0("output/global_h_", st, ".csv"), row.names = FALSE)
write.csv(global_index_h, paste0(here::here("Indicadores R", "output", "global_h_"), st, ".csv"), row.names = FALSE)
