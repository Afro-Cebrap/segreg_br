
# Prepares census tract data for segregation index calculations
# Parameters:
#   state_br: State will be processed
#   sf_geo_br: Geographic data for the census year
#   tracts_br: Population data by census tract
#   year: Census year used to identify the race columns
# Returns:
#   Data with one row per census tract and geographic unit, with
#   tract-level, unit-level and racial proportions
prepare_data <- function(state_br, sf_geo_br, tracts_br, year) {
  
  municipality_data <- sf_geo_br %>%
    st_drop_geometry() %>%
    filter(code_tract == "Total", code_muni != "Total", abbrev_state == state_br) %>%
    distinct(code_muni, name_metro)
  
  race_columns <- get_race_columns(year)
  
  tracts_state <- tracts_br %>%
    filter(code_muni %in% municipality_data$code_muni) %>%
    select(code_muni, code_tract, all_of(unname(race_columns))) %>%
    rename(!!!race_columns) %>%
    mutate(
      across(where(is.numeric), ~ coalesce(.x, 0)),
      code_muni = as.character(code_muni),
      code_tract = as.character(code_tract),
      tract_total = branca + preta + parda + amarela + indigena
    ) %>%
    filter(tract_total > 0) %>%
    left_join(municipality_data, by = "code_muni")
  
  tracts_all <- bind_rows(
    tracts_state %>% mutate(unit_id = code_muni, unit_type = "muni"),
    tracts_state %>%
      filter(!is.na(name_metro)) %>%
      mutate(unit_id = name_metro, unit_type = "metro")
  )
  
  unit_data <- tracts_all %>%
    group_by(unit_id, unit_type) %>%
    summarise(
      unit_total = sum(tract_total),
      branca_total = sum(branca),
      preta_total = sum(preta),
      parda_total = sum(parda),
      amarela_total = sum(amarela),
      indigena_total = sum(indigena),
      .groups = "drop"
    ) %>%
    mutate(
      tm_branca = branca_total / unit_total,
      tm_preta = preta_total / unit_total,
      tm_parda = parda_total / unit_total,
      tm_amarela = amarela_total / unit_total,
      tm_indigena = indigena_total / unit_total
    )
  
  tracts_all %>%
    mutate(
      tjm_branca = branca / tract_total,
      tjm_preta = preta / tract_total,
      tjm_parda = parda / tract_total,
      tjm_amarela = amarela / tract_total,
      tjm_indigena = indigena / tract_total
    ) %>%
    left_join(unit_data, by = c("unit_id", "unit_type"))
}


# Calculates the local contribution to the dissimilarity index
# Parameters:
#   tracts_segreg: Output from prepare_data()
# Returns:
#   Data with one dissimilarity value per census tract and geographic unit
calculate_local_dissimilarity <- function(tracts_segreg) {
  
  tracts_segreg %>%
    mutate(
      index_i =
        (tm_branca * (1 - tm_branca)) +
        (tm_preta * (1 - tm_preta)) +
        (tm_parda * (1 - tm_parda)) +
        (tm_amarela * (1 - tm_amarela)) +
        (tm_indigena * (1 - tm_indigena))
    ) %>%
    mutate(
      diff_branca = abs(tjm_branca - tm_branca),
      diff_preta = abs(tjm_preta - tm_preta),
      diff_parda = abs(tjm_parda - tm_parda),
      diff_amarela = abs(tjm_amarela - tm_amarela),
      diff_indigena = abs(tjm_indigena - tm_indigena),
      deviation = diff_branca + diff_preta + diff_parda + diff_amarela + diff_indigena
    ) %>%
    mutate(tract_contrib = (deviation * tract_total) / (2 * unit_total * index_i)) %>%
    select(unit_id, unit_type, code_tract, dissimilarity = tract_contrib)
}


# Aggregates local dissimilarity values for each geographic unit
# Parameters:
#   local_diss: Output from calculate_local_dissimilarity()
# Returns:
#   Data with one dissimilarity value per geographic unit
calculate_global_dissimilarity <- function(local_diss) {
  
  local_diss %>%
    group_by(unit_id, unit_type) %>%
    summarise(dissimilarity = sum(dissimilarity, na.rm = TRUE), .groups = "drop")
}


# Calculates exposure and isolation using preta and parda as one group
# Parameters:
#   tracts_segreg: Output from prepare_data().
# Returns:
#   Data with aggregated exposure and isolation values by census tract.
calculate_local_exposure <- function(tracts_segreg) {
  
  tracts_segreg %>%
    mutate(pp = preta + parda, pp_total = preta_total + parda_total) %>%
    mutate(
      iso_branca_branca = (branca / branca_total) * (branca / tract_total),
      exp_branca_pp = (branca / branca_total) * (pp / tract_total),
      exp_pp_branca = (pp / pp_total) * (branca / tract_total),
      iso_pp_pp = (pp / pp_total) * (pp / tract_total),
      
      exp_branca_amarela = (branca / branca_total) * (amarela / tract_total),
      exp_amarela_branca = (amarela / amarela_total) * (branca / tract_total),
      iso_amarela_amarela = (amarela / amarela_total) * (amarela / tract_total),
      
      exp_branca_indigena = (branca / branca_total) * (indigena / tract_total),
      exp_indigena_branca = (indigena / indigena_total) * (branca / tract_total),
      iso_indigena_indigena = (indigena / indigena_total) * (indigena / tract_total)
    ) %>%
    mutate(across(starts_with(c("iso_", "exp_")), ~ coalesce(.x, 0))) %>%
    select(
      unit_id, unit_type, code_tract,
      iso_branca_branca, exp_branca_pp, exp_pp_branca, iso_pp_pp,
      exp_branca_amarela, exp_amarela_branca, iso_amarela_amarela,
      exp_branca_indigena, exp_indigena_branca, iso_indigena_indigena
    )
}


# Global exposure and isolation values for each geographic unit.
# Parameters:
#   local_exposure: Output from a local exposure calculation.
# Returns:
#   Data with exposure and isolation indices by geographic unit.
calculate_global_exposure <- function(local_exposure) {
  
  local_exposure %>%
    group_by(unit_id, unit_type) %>%
    summarise(
      across(starts_with(c("exp_", "iso_")), ~ sum(.x, na.rm = TRUE)),
      .groups = "drop"
    )
}


# Calculates the local contribution to the H index.
# Parameters:
#   tracts_segreg: Output from prepare_data().
# Returns:
#   Data with local entropy, global entropy and H index by census tract.
calculate_local_h <- function(tracts_segreg) {
  
  tracts_segreg %>%
    mutate(
      ent_branca = if_else(tjm_branca > 0, tjm_branca * log(1 / tjm_branca), 0),
      ent_preta = if_else(tjm_preta > 0, tjm_preta * log(1 / tjm_preta), 0),
      ent_parda = if_else(tjm_parda > 0, tjm_parda * log(1 / tjm_parda), 0),
      ent_amarela = if_else(tjm_amarela > 0, tjm_amarela * log(1 / tjm_amarela), 0),
      ent_indigena = if_else(tjm_indigena > 0, tjm_indigena * log(1 / tjm_indigena), 0)
    ) %>%
    mutate(local_entropy = ent_branca + ent_preta + ent_parda + ent_amarela + ent_indigena) %>%
    mutate(
      gent_branca = if_else(tm_branca > 0, tm_branca * log(1 / tm_branca), 0),
      gent_preta = if_else(tm_preta > 0, tm_preta * log(1 / tm_preta), 0),
      gent_parda = if_else(tm_parda > 0, tm_parda * log(1 / tm_parda), 0),
      gent_amarela = if_else(tm_amarela > 0, tm_amarela * log(1 / tm_amarela), 0),
      gent_indigena = if_else(tm_indigena > 0, tm_indigena * log(1 / tm_indigena), 0)
    ) %>%
    mutate(global_entropy = gent_branca + gent_preta + gent_parda + gent_amarela + gent_indigena) %>%
    mutate(
      eei = global_entropy - local_entropy,
      index_h = (tract_total * eei) / (global_entropy * unit_total)
    ) %>%
    mutate(index_h = coalesce(index_h, 0)) %>%
    select(unit_id, unit_type, code_tract, local_entropy, global_entropy, index_h)
}


# Global H values for each geographic unit.
# Parameters:
#   local_h: Output from calculate_local_h().
# Returns:
#   Data with global entropy and H index by geographic unit.
calculate_global_h <- function(local_h) {
  
  local_h %>%
    group_by(unit_id, unit_type) %>%
    summarise(
      global_entropy = first(global_entropy),
      index_h = sum(index_h),
      .groups = "drop"
    )
}


# Adds population counts and proportions at municipality and metro level.
# Parameters:
#   df: Data with racial population totals.
# Returns:
#   Data with population count and percentage columns.
add_percent_cols <- function(df) {
  
  df %>%
    mutate(
      n_branca = branca_total,
      n_preta = preta_total,
      n_parda = parda_total,
      n_amarela = amarela_total,
      n_indigena = indigena_total,
      n_preta_ou_parda = preta_total + parda_total,
      n_total = branca_total + preta_total + parda_total + amarela_total + indigena_total,
      
      percent_branca = branca_total / unit_total,
      percent_preta = preta_total / unit_total,
      percent_parda = parda_total / unit_total,
      percent_amarela = amarela_total / unit_total,
      percent_indigena = indigena_total / unit_total,
      percent_preta_ou_parda = (preta_total + parda_total) / unit_total
    )
}


# Adds population counts and proportions at census tract level.
# Parameters:
#   df: Data with racial population counts by census tract.
# Returns:
#   Data with population count and percentage columns.
add_percent_cols_tract <- function(df) {
  
  df %>%
    mutate(
      n_branca = branca,
      n_preta = preta,
      n_parda = parda,
      n_amarela = amarela,
      n_indigena = indigena,
      n_preta_ou_parda = preta + parda,
      n_total = branca + preta + parda + amarela + indigena,
      
      percent_branca = branca / tract_total,
      percent_preta = preta / tract_total,
      percent_parda = parda / tract_total,
      percent_amarela = amarela / tract_total,
      percent_indigena = indigena / tract_total,
      percent_preta_ou_parda = (preta + parda) / tract_total
    )
}


# Returns the race column mapping configured for a census year.
# Parameters:
#   year: Census year.
# Returns:
#   Named character vector mapping standardized names to source columns.
get_race_columns <- function(year) {
  
  columns <- RACE_COLUMNS_BY_YEAR[[as.character(year)]]
  
  if (is.null(columns)) {
    stop(paste("Race columns not configured for year:", year), call. = FALSE)
  }
  
  columns
}
