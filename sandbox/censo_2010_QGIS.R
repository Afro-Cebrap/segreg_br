
# Setup -------------------------------------------------------------------

options(scipen = 999999)

#install.packages("censobr")
#install.packages("sf")
#install.packages("geobr")

library(censobr)
library(dplyr)
library(stringr)
library(geobr)
library(sf)

# Inputs -----------------------------------------------------------------

# Parameters
year <- 2010   
ufs <- c("AC","AL","AP","AM","BA","CE","DF","ES","GO","MA","MT","MS",
         "MG","PA","PB","PR","PE","PI","RJ","RN","RS","RO","RR","SC",
         "SP","SE","TO")
CRS <- 5880 # CRS SIRGAS 2000 EPSG:5880 - used in the segreg plugin, very important!!

# Data
tracts <- read_tracts(year = year, dataset = "Pessoa", as_data_frame = TRUE, cache = TRUE)

## Download and join all ufs
# Slow process!
# setores_br <- lapply(ufs, function(uf) {
#   read_census_tract(code_tract = uf, year = 2010)
# }) %>% bind_rows()


# Dictionary
#data_dictionary(year = year, dataset = "tracts")
#Checking dictionary is up to date
#names(tracts)[str_detect(names(tracts), "^pessoa03")]

# Data Preparation --------------------------------------------------------

# CRS SIRGAS 2000 EPSG:5880 - used in the segreg plugin, very important!!
# setores_br <- st_transform(setores_br, CRS)
# setores_br <- st_make_valid(setores_br)
setores_br <- st_read(
  #"C:/Users/maysa/OneDrive/Documents/Afro-CEBRAP/setores_censitarios.shp",
  here::here("setores_censitarios.shp"))

#
tracts_segreg <- tracts %>%
  select(
    code_muni = code_muni,
    cod_setor = code_tract, 
    Total_Pop = pessoa03_V001, 
    Branca = pessoa03_V002,
    Preta = pessoa03_V003,
    Amarela = pessoa03_V004,
    Parda = pessoa03_V005,
    Indigena = pessoa03_V006
  )

#check dataframe
max(tracts_segreg$Branca, na.rm = TRUE)
nrow(tracts_segreg)

#data preprocessing
tracts_segreg$cod_setor <- as.character(tracts_segreg$cod_setor)
tracts_segreg[is.na(tracts_segreg)] <- 0

#group by municipality
# municipal_race_distribution <- tracts %>%
#   select(code_muni,
#          pessoa03_V001, pessoa03_V002, pessoa03_V003,
#          pessoa03_V004, pessoa03_V005, pessoa03_V006) %>%
#   group_by(code_muni) %>%
#   summarise(across(starts_with("pessoa03_"), ~ sum(.x, na.rm = TRUE))) %>%
#   rename(
#     pop_total   = pessoa03_V001,
#     branca      = pessoa03_V002,
#     preta       = pessoa03_V003,
#     amarela     = pessoa03_V004,
#     parda       = pessoa03_V005,
#     indigena    = pessoa03_V006
#   ) %>%
#   ungroup()


# Calculate ---------------------------------------------------------------

# Estimated with QGIS 'segreg' Plugin

#
resultado_final_global <- read.csv(here::here("resultado_final_global.csv"))

#
resultado_final <- read.csv(here::here("resultado_final.csv"))

#
indices_segreg_no_geometry <- resultado_final %>%
  rename(
    "cod_setor" = X..id,
    "n_branca" = group_0,
    "n_preta" = group_1,
    "n_amarela" = group_2,
    "n_parda" = group_3,
    "n_indigena" = group_4
  ) %>%
  rowwise() %>%
  mutate(
    n_total = sum(c_across(starts_with("n_")))
  ) %>%
  ungroup() %>%
  mutate(
    percent_branca = n_branca / n_total,
    percent_preta_ou_parda = (n_preta + n_parda) / n_total,
    percent_preta = n_preta / n_total,
    percent_amarela = n_amarela / n_total,
    percent_parda = n_parda / n_total,
    percent_indigena = n_indigena / n_total
  ) %>%
  transmute(
    cod_setor,
    n_branca,
    n_preta_ou_parda = n_preta + n_parda,
    n_preta,
    n_amarela,
    n_parda,
    n_indigena,
    n_total, 
    percent_branca,
    percent_preta_ou_parda,
    percent_preta,
    percent_amarela,
    percent_parda,
    percent_indigena,
    dissimil,
    entropy,
    "index_h" = indexh
  )

#
indices_segreg <- setores_br %>%
  transmute(
    code_muni = code_mn,
    cod_setor = as.numeric(cd_trct)
  ) %>%
  left_join(indices_segreg_no_geometry,
            by = "cod_setor")

# Testing -----------------------------------------------------------------

#checking which sectors don't have match shapefile.

#glimpse(setores_br$code_tract)
#glimpse(tracts_segreg$cod_setor)
#
#setores_br <- setores_br %>%
#  mutate(code_tract = as.character(code_tract))
#
#tracts_segreg <- tracts_segreg %>%
#  mutate(cod_setor = as.character(cod_setor))
#
#joined <- setores_br %>%
#  left_join(tracts_segreg, by = c("code_tract" = "cod_setor"))
#
#joined %>%
#  filter(is.na(Total_Pop)) %>%
#  select(code_tract) %>%
#  head(20)

# Outputs ------------------------------------------------------------------

#
st_write(setores_br,
         #"C:/Users/maysa/OneDrive/Documents/Afro-CEBRAP/setores_censitarios.shp",
         here::here("setores_censitarios.shp"))

#
write.csv(tracts_segreg, 
          #"C:/Users/maysa/OneDrive/Documents/Afro-CEBRAP/dados_raca_setor.csv", 
          here::here("dados_raca_setor.csv"),
          row.names = FALSE)

#
sfarrow::st_write_parquet(
  indices_segreg,
  here::here("indices_segreg.parquet")
)
