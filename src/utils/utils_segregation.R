library(censobr)
library(dplyr)
library(stringr)
library(geobr)
library(sf)

prepare_data <- function(state_br, tracts_br, year) {
  
  muni_state <- read_municipality(state_br, year = year, simplified = TRUE) %>%
    st_drop_geometry() %>%
    select(code_muni) %>%
    mutate(code_muni = as.character(code_muni))
  
  # choosing variables based on var_name in each year
  if(year == 2010){
    tracts_state <- tracts_br %>%
      filter(code_muni %in% muni_state$code_muni) %>%
      select(
        code_muni = code_muni,
        code_tract = code_tract,
        branca = pessoa03_V002,
        preta  = pessoa03_V003,
        amarela  = pessoa03_V004,
        parda  = pessoa03_V005,
        indigena = pessoa03_V006
      )
  }
  if(year == 2022){
    tracts_state <- tracts_br %>%
      filter(code_muni %in% muni_state$code_muni) %>%
      select(
        code_muni = code_muni,
        code_tract = code_tract,
        branca = raca_V01317,
        preta  = raca_V01318,
        amarela  = raca_V01319,
        parda  = raca_V01320,
        indigena = raca_V01321
      )
  }
  
  tracts_state <- tracts_state %>%
    mutate(
      across(where(is.numeric), ~coalesce(.x, 0)),
      code_muni = as.character(code_muni),
      code_tract = as.character(code_tract),
      tract_total = branca + preta + parda,
      pop_total   = branca + preta + parda + amarela + indigena # full population
    ) %>%
    filter(pop_total > 0) # keep every inhabited tract, not only those with B/P/Pa
  
  metro_state <- read_metro_area(year) %>%
    st_drop_geometry() %>%
    filter(abbrev_state == state_br) %>%
    # drop RIDE areas
    filter(
      !str_detect(name_metro, regex("\\bride\\b", ignore_case = TRUE)),
      !str_detect(type, regex("^(raide|ride)", ignore_case = TRUE))
    ) %>% 
    select(code_muni, name_metro) %>%
    mutate(code_muni = as.character(code_muni))
  
  # harmonizing RM names for 2022
  if(year == 2022){
    metro_state <- metro_state %>% 
      mutate(
        name_metro = str_replace(name_metro, "^Recorte Metropolitano d[eoa]\\s+", "RM ")
      )
  }
  
  tracts_state <- tracts_state %>%
    left_join(metro_state, by = "code_muni")
  
  tracts_all <- bind_rows(
    tracts_state %>%
      mutate(unit_id = code_muni, unit_type = "muni"),
    tracts_state %>%
      filter(!is.na(name_metro)) %>%
      mutate(unit_id = name_metro, unit_type = "metro")
  )
  
  #Tm (Cidade/RM Level)
  tm_df <- tracts_all %>%
    group_by(unit_id, unit_type) %>%
    summarise(
      unit_total = sum(tract_total),
      branca_total = sum(branca),
      preta_total  = sum(preta),
      parda_total  = sum(parda),
      amarela_total  = sum(amarela),
      indigena_total = sum(indigena)
    ) %>%
    mutate(
      tm_branca = branca_total / unit_total,
      tm_preta  = preta_total  / unit_total,
      tm_parda  = parda_total  / unit_total
    ) |> 
    ungroup()
  
  #Tjm tract level
  tracts_segreg <- tracts_all %>%
    mutate(
      tjm_branca = branca / tract_total,
      tjm_preta  = preta  / tract_total,
      tjm_parda  = parda  / tract_total
    ) %>%
    left_join(tm_df, by = c("unit_id", "unit_type"))
  
  return(tracts_segreg)
}

calculate_local_dissimilarity <- function(tracts_segreg) {
  df_result <- tracts_segreg %>%
    #Diversity_index: I = sum(Tm * (1 - Tm))
    #Deviation = sum |tjm - Tm|
    #D_local = [ Pj * Deviation ] / (2 * N * I)
    mutate(
      index_i = (tm_branca * (1 - tm_branca)) + 
        (tm_preta * (1 - tm_preta)) + 
        (tm_parda * (1 - tm_parda))
    ) %>%
    mutate(
      diff_branca = abs(tjm_branca - tm_branca),
      diff_preta  = abs(tjm_preta  - tm_preta),
      diff_parda  = abs(tjm_parda  - tm_parda),
      deviation = diff_branca + diff_preta + diff_parda
    ) %>%
    mutate(
      tract_contrib = (deviation * tract_total) / (2 * unit_total * index_i)
    )%>%
    select(
      unit_id, 
      unit_type,
      code_tract, 
      dissimilarity = tract_contrib
    )
  return(df_result)
}

calculate_global_dissimilarity <- function(local_diss) {
  global_results <- local_diss %>%
    group_by(unit_id, unit_type) %>%
    summarise(
      dissimilarity = sum(dissimilarity, na.rm = TRUE),
    )%>%
    select(
      unit_id, 
      unit_type,
      dissimilarity
    ) |> 
    ungroup()
  return(global_results)
}

calculate_local_exposure <- function(tracts_segreg) {
  df_result <- tracts_segreg %>%
    #Isolation (m para m): iso_mm = (Pim / Pm) * (Pim / Pi)
    #Exposure (m para n):  exp_mn = (Pim / Pm) * (Pin / Pi)
    mutate(
      iso_branca_branca = (branca / branca_total) * (branca / tract_total),
      exp_branca_preta  = (branca / branca_total) * (preta / tract_total),
      exp_branca_parda  = (branca / branca_total) * (parda / tract_total),
      
      exp_preta_branca  = (preta / preta_total) * (branca / tract_total),
      iso_preta_preta   = (preta / preta_total) * (preta / tract_total),
      exp_preta_parda   = (preta / preta_total) * (parda / tract_total),
      
      exp_parda_branca  = (parda / parda_total) * (branca / tract_total),
      exp_parda_preta   = (parda / parda_total) * (preta / tract_total),
      iso_parda_parda   = (parda / parda_total) * (parda / tract_total)
    ) %>%
    mutate(across(starts_with(c("iso_", "exp_")), ~coalesce(., 0))) %>%
    select(
      unit_id, 
      unit_type,
      code_tract, 
      starts_with("exp_"), 
      starts_with("iso_")
    )
  
  return(df_result)
}

calculate_local_exposure_agregate <- function(tracts_segreg) {
  
  df_result <- tracts_segreg %>%
    mutate(
      pp = preta + parda,
      pp_total = preta_total + parda_total
    ) %>%
    mutate(
      iso_branca_branca = (branca / branca_total) * (branca / tract_total),
      exp_branca_pp  = (branca / branca_total) * (pp / tract_total),
      
      exp_pp_branca  = (pp / pp_total) * (branca / tract_total),
      iso_pp_pp   = (pp / pp_total) * (pp / tract_total)
    ) %>%
    mutate(across(starts_with(c("iso_", "exp_")), ~coalesce(., 0))) %>%
    select(
      unit_id, 
      unit_type,
      code_tract, 
      iso_branca_branca, exp_branca_pp,
      exp_pp_branca, iso_pp_pp
    )
  
  return(df_result)
}

calculate_global_exposure <- function(local_exposure) {
  global_results <- local_exposure %>%
    group_by(unit_id, unit_type) %>%
    summarise(
      across(starts_with(c("exp_", "iso_")), ~sum(., na.rm = TRUE)),
    ) |> 
    ungroup()
  
  return(global_results)
}

calculate_local_h <- function(tracts_segreg) {
  df_result <- tracts_segreg %>%
    # Local Entropy (Ei)
    mutate(
      ent_branca = if_else(tjm_branca > 0, tjm_branca * log(1 / tjm_branca), 0),
      ent_preta  = if_else(tjm_preta > 0,  tjm_preta  * log(1 / tjm_preta),  0),
      ent_parda  = if_else(tjm_parda > 0,  tjm_parda  * log(1 / tjm_parda),  0)
    ) %>%
    mutate(local_entropy = ent_branca + ent_preta + ent_parda) %>%
    
    # Global Entropy (E)
    mutate(
      gent_branca = if_else(tm_branca > 0, tm_branca * log(1 / tm_branca), 0),
      gent_preta  = if_else(tm_preta > 0,  tm_preta  * log(1 / tm_preta),  0),
      gent_parda  = if_else(tm_parda > 0,  tm_parda  * log(1 / tm_parda),  0)
    ) %>%
    mutate(global_entropy = gent_branca + gent_preta + gent_parda) %>%
    
    # Index H Local
    # H_local = [ Pj * (E - Ei) ] / (E * N)
    mutate(
      eei = global_entropy - local_entropy,
      index_h = (tract_total * eei) / (global_entropy * unit_total)
    ) %>%
    mutate(index_h = coalesce(index_h, 0)) %>%
    select(
      unit_id,
      unit_type,
      code_tract,
      local_entropy,
      global_entropy,
      index_h
    )
  
  return(df_result)
}

calculate_global_h <- function(local_h) {
  global_results <- local_h %>%
    group_by(unit_id, unit_type) %>%
    summarise(
      global_entropy = first(global_entropy),
      index_h  = sum(index_h)
    ) |> 
    ungroup()
  
  return(global_results)
}

# Adds population proportion columns by racial group at the city/RM level
add_percent_cols <- function(df) {
  df %>%
    mutate(
      n_branca = branca_total,
      n_preta_ou_parda = preta_total + parda_total,
      n_preta = preta_total,
      n_amarela = amarela_total,
      n_parda = parda_total,
      n_indigena = indigena_total,
      n_total = branca_total + preta_total + parda_total + amarela_total + indigena_total,
      percent_branca = branca_total / unit_total,
      percent_preta_ou_parda = (preta_total + parda_total) / unit_total,
      percent_preta = preta_total / unit_total,
      percent_amarela = n_amarela  / n_total,
      percent_parda = parda_total / unit_total,
      percent_indigena = n_indigena / n_total
      
    )
}

# Adds population proportion columns by racial group at the tract level
add_percent_cols_tract <- function(df) {
  df %>%
    mutate(
      n_branca         = branca,
      n_preta          = preta,
      n_parda          = parda,
      n_amarela        = amarela,
      n_indigena       = indigena,
      n_preta_ou_parda = preta + parda,
      n_total = branca + preta + parda + amarela + indigena,
      percent_branca         = branca / tract_total,
      percent_preta          = preta  / tract_total,
      percent_parda          = parda  / tract_total,
      percent_amarela        = amarela  / tract_total,
      percent_indigena       = indigena / tract_total,
      percent_preta_ou_parda = (preta + parda) / tract_total
    )
}