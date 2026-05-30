# Makefile for territorios_negros project

.PHONY: all setup geo population indices clean

all: geo population indices

setup:
	Rscript src/utils/setup.R

geo:
	Rscript src/01_geo_br.R

population:
	Rscript src/02_population.R

indices:
	Rscript src/03_mvp_segregation_indices.R

clean:
	rm -rf data/1_bronze/*
	rm -rf data/2_silver/*
	rm -rf data/3_gold/*
