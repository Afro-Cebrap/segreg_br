# Troubleshooting

Guia rápido de problemas comuns no setup e na execução do pipeline.
(Referenciado por `src/utils/setup.R`.)

## `renv::restore()` falha ou pacotes faltando
- Rode `renv::status()` para ver o que está fora de sincronia.
- Se um pacote novo é legítimo, adicione-o e rode `renv::snapshot()` para gravar no `renv.lock`.
- **Não** use `install.packages()` direto: isso dessincroniza o lockfile (o `setup.R` agora falha de propósito nesse caso).

## Erro de caminho ao rodar `03` antes de `01`/`02`
- O pipeline é sequencial. Rode na ordem: `01_geo_br.R` → `02_population.R` → `03_mvp_segregation_indices.R` (ou `make all`).
- Cada script cria seu subdiretório de saída, mas `03` depende das saídas de `01` (silver) e `02` (bronze).

## Camadas de dados (medallion)
- `data/1_bronze/` — leituras cruas (censobr).
- `data/2_silver/` — dados transformados/integrados (geo_br).
- `data/3_gold/` — índices consolidados para consumo.
- O conteúdo das camadas é git-ignored; só o skeleton (`.gitkeep`) e `data/metadata/` são versionados.
