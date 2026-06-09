#'-------------------------------------------------------------------------
#'@project TerritoriosNegros2022
#'@author Thiago Cordeiro-Almeida
#'@description Exploring metropolitan regions over time since 2010
#'-------------------------------------------------------------------------

# 0. Setup ----------------------------------------------------------------

#
options(scipen = 999) # Disable scientific notation for numbers

library(here) # For file path management
library(geobr) # For accessing Brazilian census data
library(tidyverse) # For data manipulation and visualization
library(tidylog) # For logging tidyverse operations
library(arrow) # For reading and writing data in Parquet format
library(sf)


# Metropolitan regions over the years -------------------------------------

# Parameters
year = c(2010,2013,2014,2015,2016,2017,2018,2019,2020,2021,2022,2023,2024)

# Pooling summary of metropolitan regions
for(i in seq_along(year)){
  if(i == 1){
    # reading metropolitan regions for an specific year in geobr package
    t <- geobr::read_metro_area(year[i]) |> 
      # summarising it to obtain number of metrop. regions and municipalities for each year
      summarise(
        year = max(year),
        n_metro = n_distinct(name_metro),
        n_munic = n_distinct(code_muni)
      ) |> 
      st_drop_geometry() |>  
      as_tibble()
  } else{
    t <- t |> bind_rows(
      geobr::read_metro_area(year[i]) |> 
        summarise(
          year = max(year),
          n_metro = n_distinct(name_metro),
          n_munic = n_distinct(code_muni)
        ) |> 
        st_drop_geometry() |>  
        as_tibble()
    )
  }
}

### plotting it

t |> 
  pivot_longer(
    n_metro:n_munic,
    names_to = "type",
    values_to = "value"
  ) |> 
  mutate(
    type = factor(type, levels = c("n_metro","n_munic"), labels = c("Number of metrop. regions", "Number of cities within metrop. regions"))
  ) |> 
  ggplot() +
  aes(x = year, y = value) +
  geom_line(linewidth = 1.1) +
  geom_point(size = 4) +
  facet_wrap(. ~ type, scales = "free_y") +
  scale_x_continuous(breaks = year) +
  theme_light()
