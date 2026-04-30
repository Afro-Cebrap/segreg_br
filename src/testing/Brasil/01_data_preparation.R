#install.packages("censobr")
#install.packages("sf")
#install.packages("geobr")

library(censobr)
library(dplyr)
library(stringr)

#shapefile
library(geobr)
library(sf)

year <- 2010   

tracts <- read_tracts(year = year, dataset = "Pessoa", as_data_frame = TRUE, cache = TRUE)

#Checking dictionary is up to date
#data_dictionary(year = year, dataset = "tracts")
#names(tracts)[str_detect(names(tracts), "^pessoa03")]

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
#max(tracts_segreg$Branca, na.rm = TRUE)
#nrow(tracts_segreg)

#data preprocessing
tracts_segreg$cod_setor <- as.character(tracts_segreg$cod_setor)
tracts_segreg[is.na(tracts_segreg)] <- 0

saveRDS(tracts_segreg, "data/tracts_segreg.rds")

write.csv(tracts_segreg, "data/tracts_segreg.csv", row.names = FALSE)



#Shapefile

ufs <- c("AC","AL","AP","AM","BA","CE","DF","ES","GO","MA","MT","MS",
         "MG","PA","PB","PR","PE","PI","RJ","RN","RS","RO","RR","SC",
         "SP","SE","TO")

#Download and join all ufs
setores_br <- lapply(ufs, function(uf) {
  read_census_tract(code_tract = uf, year = 2010)
}) %>% bind_rows()


# CRS 5880 - used in the segreg plugin, very important!!
setores_br <- st_transform(setores_br, 5880)
setores_br <- st_make_valid(setores_br)

st_write(setores_br, "output/setores_censitarios.shp")


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



