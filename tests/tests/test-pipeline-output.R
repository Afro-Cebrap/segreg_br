
# Pipeline output integration tests
# Reads actual generated parquets (silver + gold). If the pipeline has not
# run yet on this machine, tests are skipped instead of failing.



caminho_gold <- file.path(GOLD_DIR, "sf_segregation_indices_all_years.parquet")

test_that("no rows are duplicated by key columns", {
  skip_if_not(
    file.exists(caminho_gold),
    "gold dataset not found — run the pipeline first"
  )
  
  dados <- sfarrow::st_read_parquet(caminho_gold)
  chave <- c("year", "unit_type", "code_tract", "code_muni", "name_metro")
  chave <- intersect(chave, names(dados))
  
  duplicadas <- dados %>%
    sf::st_drop_geometry() %>%
    dplyr::count(dplyr::across(dplyr::all_of(chave))) %>%
    dplyr::filter(n > 1)
  
  expect_equal(nrow(duplicadas), 0)
})

test_that("all 5 racial group percentages sum to 1 when index is calculated", {
  skip_if_not(
    file.exists(caminho_gold),
    "gold dataset not found — run the pipeline first"
  )
  
  dados <- sfarrow::st_read_parquet(caminho_gold) %>%
    sf::st_drop_geometry() %>%
    dplyr::filter(!is.na(unit_type))
  
  soma <- dados$percent_branca + dados$percent_preta + dados$percent_parda +
    dados$percent_amarela + dados$percent_indigena
  
  expect_equal(soma, rep(1, nrow(dados)), tolerance = 1e-6)
})

test_that("n_total matches the sum of all 5 racial groups", {
  skip_if_not(
    file.exists(caminho_gold),
    "gold dataset not found — run the pipeline first"
  )
  
  dados <- sfarrow::st_read_parquet(caminho_gold) %>%
    sf::st_drop_geometry() %>%
    dplyr::filter(!is.na(unit_type))
  
  soma_grupos <- dados$n_branca + dados$n_preta + dados$n_parda +
    dados$n_amarela + dados$n_indigena
  
  expect_equal(dados$n_total, soma_grupos, tolerance = 1e-6)
})

test_that("no municipality belongs to more than one metro area", {
  caminhos <- file.path(SILVER_DIR, sprintf("geo_br_%s.parquet", CENSO_YEARS))
  caminhos <- caminhos[file.exists(caminhos)]
  skip_if(
    length(caminhos) == 0,
    "geo_br not found — run 01_geo_br.R first"
  )
  
  for (caminho in caminhos) {
    geo_br <- sfarrow::st_read_parquet(caminho) %>%
      sf::st_drop_geometry()
    
    duplicados <- geo_br %>%
      dplyr::filter(code_tract == "Total", code_muni != "Total") %>%
      dplyr::distinct(code_muni, name_metro) %>%
      dplyr::count(code_muni) %>%
      dplyr::filter(n > 1)
    
    expect_equal(nrow(duplicados), 0, info = paste("failed in:", caminho))
  }
})

test_that("dissimilarity and exposure indices are within expected bounds", {
  skip_if_not(
    file.exists(caminho_gold),
    "gold dataset not found — run the pipeline first"
  )
  
  dados <- sfarrow::st_read_parquet(caminho_gold) %>%
    sf::st_drop_geometry() %>%
    dplyr::filter(!is.na(unit_type))
  
  margem <- 1e-6
  
  colunas_0_a_1 <- c(
    "dissimilarity",
    "exp_branca_pp", "exp_pp_branca", "iso_branca_branca", "iso_pp_pp",
    "exp_branca_amarela", "exp_amarela_branca", "iso_amarela_amarela",
    "exp_branca_indigena", "exp_indigena_branca", "iso_indigena_indigena"
  )
  colunas_0_a_1 <- intersect(colunas_0_a_1, names(dados))
  
  for (coluna in colunas_0_a_1) {
    valores <- dados[[coluna]]
    fora_do_intervalo <- sum(
      valores < -margem | valores > 1 + margem,
      na.rm = TRUE
    )
    expect_equal(fora_do_intervalo, 0, info = paste("column:", coluna))
  }
  
  h_agregado <- dados %>%
    dplyr::filter(code_tract == "Total") %>%
    dplyr::pull(index_h)
  fora_do_intervalo_h <- sum(
    h_agregado < -margem | h_agregado > 1 + margem,
    na.rm = TRUE
  )
  expect_equal(fora_do_intervalo_h, 0)
})

test_that("number of municipalities matches official IBGE count", {
  skip_if_not(
    file.exists(caminho_gold),
    "gold dataset not found — run the pipeline first"
  )
  
  contagem_oficial <- c("2010" = 5565, "2022" = 5570)
  
  dados <- sfarrow::st_read_parquet(caminho_gold) %>%
    sf::st_drop_geometry()
  
  for (ano in names(contagem_oficial)) {
    n_municipios <- dados %>%
      dplyr::filter(
        year == as.numeric(ano),
        unit_type == "muni",
        code_tract == "Total"
      ) %>%
      dplyr::distinct(code_muni) %>%
      nrow()
    
    expect_equal(n_municipios, contagem_oficial[[ano]], info = paste("year:", ano))
  }
})

test_that("national total population matches official IBGE Census magnitude", {
  skip_if_not(
    file.exists(caminho_gold),
    "gold dataset not found — run the pipeline first"
  )
  
  populacao_oficial <- c("2010" = 190755799, "2022" = 203080756)
  tolerancia_relativa <- 0.02
  
  dados <- sfarrow::st_read_parquet(caminho_gold) %>%
    sf::st_drop_geometry()
  
  for (ano in names(populacao_oficial)) {
    populacao_calculada <- dados %>%
      dplyr::filter(
        year == as.numeric(ano),
        unit_type == "muni",
        code_tract == "Total"
      ) %>%
      dplyr::summarise(total = sum(n_total, na.rm = TRUE)) %>%
      dplyr::pull(total)
    
    diferenca_relativa <- abs(populacao_calculada - populacao_oficial[[ano]]) /
      populacao_oficial[[ano]]
    
    expect_true(
      diferenca_relativa < tolerancia_relativa,
      info = sprintf(
        "year %s: calculated=%s, official=%s, difference=%.2f%%",
        ano, populacao_calculada, populacao_oficial[[ano]],
        diferenca_relativa * 100
      )
    )
  }
})

test_that("tracts with population only in amarela/indigena are not excluded", {
  skip_if_not(
    file.exists(caminho_gold),
    "gold dataset not found — run the pipeline first"
  )
  
  for (ano in CENSO_YEARS) {
    caminho_bronze <- file.path(
      BRONZE_DIR,
      sprintf("census_tracts_br_%s.parquet", ano)
    )
    skip_if_not(
      file.exists(caminho_bronze),
      paste("bronze data for year", ano, "not found")
    )
    
    colunas_raca <- get_race_columns(ano)
    raw <- arrow::read_parquet(caminho_bronze) %>%
      dplyr::select(code_tract, dplyr::all_of(unname(colunas_raca))) %>%
      dplyr::rename(!!!colunas_raca) %>%
      dplyr::mutate(dplyr::across(-code_tract, ~ dplyr::coalesce(.x, 0)))
    
    setores_so_amarela_indigena <- raw %>%
      dplyr::filter(
        branca == 0, preta == 0, parda == 0, (amarela > 0 | indigena > 0)
      ) %>%
      dplyr::pull(code_tract)
    
    if (length(setores_so_amarela_indigena) == 0) next
    
    setores_no_gold <- sfarrow::st_read_parquet(caminho_gold) %>%
      sf::st_drop_geometry() %>%
      dplyr::filter(year == ano, unit_type == "muni", code_tract != "Total") %>%
      dplyr::pull(code_tract)
    
    faltando <- setdiff(setores_so_amarela_indigena, setores_no_gold)
    
    expect_equal(
      length(faltando), 0,
      info = paste(
        length(faltando),
        "tract(s) with pop only in amarela/indigena missing in year", ano
      )
    )
  }
})