
# tests/run_tests.R: run all tests of the pipeline

library(testthat)
library(here)
library(tidyverse)
library(sf)
library(sfarrow)

source(here("src", "utils", "constants.R"))
source(here("src", "utils", "utils_segregation.R"))

test_dir(here("tests", "tests"), stop_on_failure = FALSE)
