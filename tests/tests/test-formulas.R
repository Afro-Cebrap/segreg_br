
# Index formula unit tests using small synthetic datasets 
# Verifies mathematical properties that formulas must satisfy by definition

# Perfectly integrated tract (tract composition == unit composition)
setor_integrado <- tibble::tibble(
  unit_id = "U1", unit_type = "muni", code_tract = "T1",
  tract_total = 100, unit_total = 1000,
  branca = 50, preta = 25, parda = 15, amarela = 6, indigena = 4,
  branca_total = 500, preta_total = 250, parda_total = 150,
  amarela_total = 60, indigena_total = 40,
  tjm_branca = 0.50, tjm_preta = 0.25, tjm_parda = 0.15, tjm_amarela = 0.06,
  tjm_indigena = 0.04,
  tm_branca = 0.50, tm_preta = 0.25, tm_parda = 0.15, tm_amarela = 0.06,
  tm_indigena = 0.04
)

# Unit with two unequal tracts for testing sums and bounds
setor_a <- tibble::tibble(
  unit_id = "U2", unit_type = "muni", code_tract = "TA",
  tract_total = 100, unit_total = 200,
  branca = 80, preta = 10, parda = 5, amarela = 3, indigena = 2,
  branca_total = 100, preta_total = 50, parda_total = 35,
  amarela_total = 8, indigena_total = 7,
  tjm_branca = 0.80, tjm_preta = 0.10, tjm_parda = 0.05, tjm_amarela = 0.03,
  tjm_indigena = 0.02,
  tm_branca = 0.50, tm_preta = 0.25, tm_parda = 0.175, tm_amarela = 0.04,
  tm_indigena = 0.035
)

setor_b <- tibble::tibble(
  unit_id = "U2", unit_type = "muni", code_tract = "TB",
  tract_total = 100, unit_total = 200,
  branca = 20, preta = 40, parda = 30, amarela = 5, indigena = 5,
  branca_total = 100, preta_total = 50, parda_total = 35,
  amarela_total = 8, indigena_total = 7,
  tjm_branca = 0.20, tjm_preta = 0.40, tjm_parda = 0.30, tjm_amarela = 0.05,
  tjm_indigena = 0.05,
  tm_branca = 0.50, tm_preta = 0.25, tm_parda = 0.175, tm_amarela = 0.04,
  tm_indigena = 0.035
)

unidade_desigual <- dplyr::bind_rows(setor_a, setor_b)

test_that("all 5 racial groups sum to 1 in test data (tjm and tm)", {
  todos <- dplyr::bind_rows(setor_integrado, unidade_desigual)
  
  soma_tjm <- todos$tjm_branca + todos$tjm_preta + todos$tjm_parda +
    todos$tjm_amarela + todos$tjm_indigena
  soma_tm <- todos$tm_branca + todos$tm_preta + todos$tm_parda +
    todos$tm_amarela + todos$tm_indigena
  
  expect_equal(soma_tjm, rep(1, nrow(todos)), tolerance = 1e-9)
  expect_equal(soma_tm, rep(1, nrow(todos)), tolerance = 1e-9)
})

test_that("dissimilarity of a perfectly integrated tract is zero", {
  resultado <- calculate_local_dissimilarity(setor_integrado)
  expect_equal(resultado$dissimilarity, 0, tolerance = 1e-9)
})

test_that("index H of a perfectly integrated tract is zero", {
  resultado <- calculate_local_h(setor_integrado)
  expect_equal(resultado$index_h, 0, tolerance = 1e-9)
})

test_that("dissimilarity is never negative", {
  diss <- calculate_local_dissimilarity(unidade_desigual)
  expect_true(all(diss$dissimilarity >= 0))
})

test_that("index H (unit aggregate) is non-negative in this case", {
  # Local index H per tract can be negative (Theil decomposition property),
  # but the unit aggregate sums local contributions.
  local <- calculate_local_h(unidade_desigual)
  global <- calculate_global_h(local)
  
  expect_true(global$index_h >= 0)
})

test_that("global dissimilarity is the sum of local contributions", {
  local <- calculate_local_dissimilarity(unidade_desigual)
  global <- calculate_global_dissimilarity(local)
  
  expect_equal(global$dissimilarity, sum(local$dissimilarity), tolerance = 1e-9)
})

test_that("exposure of a group to all groups sums back to its tract fraction", {
  resultado <- calculate_local_exposure(unidade_desigual)
  
  soma_exposicao_branca <- resultado$iso_branca_branca +
    resultado$exp_branca_pp +
    resultado$exp_branca_amarela +
    resultado$exp_branca_indigena
  
  esperado <- unidade_desigual$branca / unidade_desigual$branca_total
  
  expect_equal(soma_exposicao_branca, esperado, tolerance = 1e-9)
})

test_that("all exposure and isolation columns are bounded between 0 and 1", {
  resultado <- calculate_local_exposure(unidade_desigual)
  colunas_expo <- resultado %>%
    dplyr::select(dplyr::starts_with(c("iso_", "exp_")))
  
  expect_true(all(colunas_expo >= 0 & colunas_expo <= 1))
})