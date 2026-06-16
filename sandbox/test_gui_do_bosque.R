# sandbox/test_gui_do_bosque.R
# -----------------------------------------------------------------------------
# Arquivo de TESTE TEMPORÁRIO para exercitar o Gui do Bosque.
# Contém defeitos propositais. APAGAR após validar o bot.
# -----------------------------------------------------------------------------

library(sf)

# [Portabilidade] Caminho absoluto + setwd: deve ser reprovado.
setwd("/Users/pesquisa/AfroCebrap/dados")

# [Censo 2022] Ano fixo em 2010, divergente do escopo do projeto.
ano <- 2010

dados <- read.csv("setores.csv")

# [QuantiCrit] Descarte silencioso de registros sem cor/raça (apagamento algorítmico).
dados <- na.omit(dados)

# [Robustez] Proporção sem proteger denominador zero.
dados$prop_negra <- (dados$preto + dados$pardo) / dados$total

# [Eficiência] Laço não-vetorizado; e isto NÃO é a fórmula de dissimilaridade.
d <- 0
for (i in 1:nrow(dados)) {
  d <- d + abs(dados$prop_negra[i] - mean(dados$prop_negra, na.rm = TRUE))
}

print(d)
