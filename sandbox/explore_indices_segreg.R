options(scipen = 999)

library(here)
library(tidyverse)
library(sf)
library(sfarrow)
library(gridExtra)

# Import data
indices_segreg <- sfarrow::st_read_parquet(
  here::here(
    "indicadores QGIS",
    "data",
    "indices_segreg.parquet")
)

#
teste <- read.csv(
  here::here("Indicadores R" ,"output", "MG", "local_exposure_isolation_mg.csv")
)

# Correlation -------------------------------------------------------------

# calculate pearlson correlation between indices
correlation_matrix <- indices_segreg %>%
  st_set_geometry(NULL) %>%
  select(percent_branca, percent_preta_ou_parda, 
         #percent_preta, percent_parda, 
         index_h, dissimil) %>%
  rename(
    "% Brancos" = percent_branca,
    "% Preto ou pardo" = percent_preta_ou_parda,
    #"% Pretos" = percent_preta,
    #"% Pardos" = percent_parda,
    #"Entropy" = entropy,
    "Dissimilarity" = dissimil,
    "Index H" = index_h,
  ) %>%
  cor(method = "pearson", use = "complete.obs") %>%
  as.data.frame()

# View as gt table
correlation_matrix %>%
  rownames_to_column(var = "Index") %>%
  gt::gt() %>%
  gt::fmt_number(
    columns = -Index,
    decimals = 3
  ) %>%
  gt::tab_header(
    title = "Pearson Correlation Matrix of Segregation Indices"
  ) %>%
  ## add colors to correlation values
  # more negative values in red, more positive values in blue
  gt::data_color(
    columns = -Index,
    fn = scales::col_numeric(
      palette = c("red", "white", "blue"),
      domain = c(-1, 1)
    )
  ) %>%
  # font size must be 12
  gt::tab_options(
    table.font.size = gt::px(12)
  ) %>%
  # columns must have equal width
  gt::cols_width(
    gt::everything() ~ gt::px(75)
  )
  

# Maps -----------------------------------------------------------------

# Test as a ggplot map for entropy
plot_entropy_bh <- ggplot() +
  geom_sf(
    data = indices_segreg %>%
      filter(code_muni == 3106200),
    aes(fill = entropy),
    color = NA
  ) +
  scale_fill_viridis_c(option = "magma") +
  theme_void() +
  labs(fill = "Entropy")

# test as ggplot map for index_h
plot_index_h_bh <- ggplot() +
  geom_sf(
    data = indices_segreg %>%
      filter(code_muni == 3106200),
    aes(fill = index_h),
    color = NA
  ) +
  scale_fill_viridis_c(option = "magma") +
  theme_void() +
  labs(fill = "Index H")

# test as ggplot map for dissimil
plot_dissimil_bh <- ggplot() +
  geom_sf(
    data = indices_segreg %>%
      filter(code_muni == 3106200),
    aes(fill = dissimil),
    color = NA
  ) +
  scale_fill_viridis_c(option = "magma") +
  theme_void() +
  labs(fill = "Dissimilarity")

# test as ggplot map for percent_branca
plot_percent_branca_bh <- ggplot() +
  geom_sf(
    data = indices_segreg %>%
      filter(code_muni == 3106200),
    aes(fill = percent_branca),
    color = NA
  ) +
  scale_fill_viridis_c(option = "magma", labels = scales::label_percent()) +
  theme_void() +
  labs(fill = "% Brancos")

# test as ggplot map for percent_preta_ou_parda
plot_percent_preta_ou_parda_bh <- ggplot() +
  geom_sf(
    data = indices_segreg %>%
      filter(code_muni == 3106200),
    aes(fill = percent_preta_ou_parda),
    color = NA
  ) +
  scale_fill_viridis_c(option = "magma", labels = scales::label_percent()) +
  theme_void() +
  labs(fill = "% Preto ou pardo")

# Arrange plots
grid.arrange(
  plot_dissimil_bh + ggtitle("Dissimilarity Index - Belo Horizonte"),
  #plot_entropy_bh + ggtitle("Entropy Index - Belo Horizonte"),
  plot_index_h_bh + ggtitle("Index H - Belo Horizonte"),
  ncol = 2
)

grid.arrange(
  plot_percent_branca_bh + ggtitle("% White Population - Belo Horizonte"),
  plot_percent_preta_ou_parda_bh + ggtitle("% Black or Mixed Race Population - Belo Horizonte"),
  ncol = 1
)


