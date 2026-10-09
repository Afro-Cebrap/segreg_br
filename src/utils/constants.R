
# Years processed by the pipeline
CENSO_YEARS <- c(2010, 2022)


# States processed by the pipeline.
TARGET_STATES <- c(
  "AC", "AL", "AP", "AM", "BA", "CE", "DF", "ES", "GO", "MA", "MT",
  "MS", "MG", "PA", "PB", "PR", "PE", "PI", "RJ", "RN", "RS", "RO",
  "RR", "SC", "SP", "SE", "TO"
)


# censobr population dataset name by year
CENSO_DATASET_BY_YEAR <- list(
  "2010" = "Pessoa",
  "2022" = "Pessoas"
)


# Race columns in censobr by year
RACE_COLUMNS_BY_YEAR <- list(
  "2010" = c(
    branca   = "pessoa03_V002",
    preta    = "pessoa03_V003",
    amarela  = "pessoa03_V004",
    parda    = "pessoa03_V005",
    indigena = "pessoa03_V006"
  ),
  
  "2022" = c(
    branca   = "raca_V01317",
    preta    = "raca_V01318",
    amarela  = "raca_V01319",
    parda    = "raca_V01320",
    indigena = "raca_V01321"
  )
)


# Rules used to identify RIDEs
REGEX_RIDE_NAME <- "\\bride\\b"
REGEX_RIDE_TYPE <- "^(raide|ride)"

# Rule used to harmonize metropolitan area names in 2022
REGEX_METRO_NAME_2022 <- "^Recorte Metropolitano d[eoa]\\s+"


# Data layer directories
BRONZE_DIR <- here("data", "1_bronze")
SILVER_DIR <- here("data", "2_silver")
GOLD_DIR   <- here("data", "3_gold")


# Segregation index columns
SEGREGATION_METRICS <- c(
  "dissimilarity",
  "index_h",
  "exp_branca_pp",
  "exp_pp_branca",
  "iso_branca_branca",
  "iso_pp_pp",
  "exp_branca_amarela",
  "exp_amarela_branca",
  "iso_amarela_amarela",
  "exp_branca_indigena",
  "exp_indigena_branca",
  "iso_indigena_indigena"
)

# Metropolitan areas excluded to avoid overlapping territorial definitions
# The RM Norte/Nordeste Catarinense overlaps with the RMs of
# Joinville, Jaragua do Sul and Planalto Norte.
# The older RM remains in the source data, so it is excluded here to keep
# one metropolitan-area assignment per municipality in the analysis
EXCLUDED_METRO_AREAS <- c(
  "RM Norte/Nordeste Catarinense"
)
