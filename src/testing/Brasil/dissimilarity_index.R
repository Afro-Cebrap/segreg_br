#install.packages("matrixStats")

library(dplyr)
library(matrixStats)

tracts_segreg <- readRDS("data/tracts_segreg.rds")

pop <- tracts_segreg %>%
  select(Branca, Preta, Amarela, Parda, Indigena) %>%
  as.matrix()

#Pop by tracts (P_i)
pop_sum <- rowSums(pop)

pop_sum[pop_sum == 0] <- NA

#Prop m in tract i (t_im)
tim <- pop / pop_sum

#prop m in Brazil (T_m)
tm <- colSums(pop) / sum(pop)

# Global diversity index (I)
index_i <- sum(tm * (1 - tm))

pop_total <- sum(pop)

# Local dissimilarity calculation
local_diss <- rowSums(
  abs(tim - matrix(tm,
                   nrow = nrow(tim),
                   ncol = length(tm),
                   byrow = TRUE)) *
    pop_sum /
    (2 * pop_total * index_i),
  na.rm = TRUE
)

result <- tracts_segreg %>%
  mutate(dissimil = local_diss) %>%
  select(cod_setor, dissimil)

write.csv(result, "output/local_dissimilarity.csv", row.names = FALSE)

#Check result
#result %>%
#  filter(cod_setor == "120020305000014")


#Global dissimilarity
index_global <- sum(result$dissimil)

write.csv(index_global, "output/global_dissimilarity.csv", row.names = FALSE)
