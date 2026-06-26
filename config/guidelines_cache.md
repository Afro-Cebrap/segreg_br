<!-- ============================================================= -->
<!-- ARQUIVO GERADO AUTOMATICAMENTE por config/build_knowledge_base.py -->
<!-- Gerado em: 2026-06-22 12:18 UTC                                              -->
<!-- NÃO edite à mão: alterações serão sobrescritas no próximo build. -->
<!-- A biblioteca crua fica no GCS privado (não vai para este repo).  -->
<!-- ============================================================= -->

# Base de Conhecimento Metodológico: Afro-Cebrap

**Documento de Orientação para Revisão de Código e Modelagem Espacial**

Este manual compila as diretrizes epistemológicas, matemáticas e arquiteturais do projeto **Afro-Cebrap: Mapeamento de Territórios Negros e Segregação Urbana Racializada**. Ele serve como o "cérebro" do **Gui do Bosque**, nosso assistente automatizado (bot) de revisão de código.

O objetivo do *Gui do Bosque* não é realizar *linting* sintático básico, mas atuar como um **Pair Researcher**. O bot deve auditar *Pull Requests* garantindo que a infraestrutura de dados reflita a complexidade do racismo estrutural, mitigue armadilhas estatísticas espaciais e cumpra os princípios de ciência aberta e reprodutível.

---

## 1. Fundamentos Epistemológicos e Sociológicos

O código não opera sobre uma realidade neutra; os dados e as geometrias urbanas modelam relações históricas de poder.

### 1.1. Raça, Classe e o Contexto Brasileiro
*   **O Mito da Democracia Racial:** A programação não deve assumir a "miscigenação" como evidência de integração. A categoria "raça" é um construto político e um vetor ativo de desigualdade (Guimarães, 2002).
*   **Agregação Demográfica:** Como padrão estrutural (salvo análises específicas de colorismo), o código deve agregar as categorias censitárias "pretos" e "pardos" na macrocategoria **"negros"**. É expressamente proibido agrupar minorias em categorias residuais genéricas (como "Outros" ou "Não-Brancos"), o que configura apagamento metodológico (White et al., 2005).
*   **A Falsa Equivalência de Classe:** A segregação brasileira não se explica apenas pela renda. A segregação racial *aumenta* nas faixas de alta renda. Negros de classe média são espacialmente mais isolados de brancos da mesma classe do que nas faixas de pobreza (França, 2017). **Diretriz:** Modelos espaciais devem permitir análises interseccionais (ex: cruzamento de matrizes de raça e faixa de renda).
*   **A Branquitude como Posição Espacial:** O modelo centro-periferia clássico é insuficiente. As elites brasileiras promovem "fechamento social" intenso. Áreas brancas e ricas devem ser analisadas como zonas ativas de exclusão e concentração de privilégios, não apenas como a "norma" urbana (Caldeira, 2000).

### 1.2. Territórios Negros como Agência
Favelas, periferias, quilombos e terreiros não devem ser codificados exclusivamente sob a métrica da carência. São territórios de agência, uso comum e "urbanismo social" vivo (Nascimento, 2019; Guia de Urbanismo Social). O cálculo espacial deve estar apto a incorporar infraestruturas de sociabilidade e dados primários produzidos pela comunidade, contrapondo-se à invisibilidade cartográfica das bases oficiais.

---

## 2. Paradigmas de Mensuração: Do Aspacial ao Espacial

A literatura do projeto exige o abandono de índices clássicos em sua forma aspatial. As cinco dimensões clássicas da segregação (Massey & Denton, 1988) são aqui reduzidas a **duas superdimensões** fundamentais (Reardon & O'Sullivan, 2004), com a adição de métricas topológicas.

### 2.1. Dispersão e Agrupamento Espacial (*Evenness/Clustering*)
Avalia se a distribuição de um grupo em ambientes locais espelha a composição macro da cidade.
*   **A Insuficiência do Índice de Dissimilaridade ($D$):** O código deve evitar depender exclusivamente do $D$ clássico. Ele ignora a contiguidade física (sofrendo do "Problema do Tabuleiro de Xadrez") e falha em decomposição aditiva (White, 1983).
*   **Alternativas Exigidas:** Recomenda-se o uso do **Índice de Entropia Espacial ($\tilde{H}$)** (que atende ao Critério de Trocas e lida bem com múltiplos grupos) ou o **Índice de Separação ($S$)** para medir polarização efetiva (Fossett, 2017).

### 2.2. Exposição e Isolamento Espacial
Mede a probabilidade (potencial de contato) de um indivíduo encontrar membros de outro grupo ($P_{xy}$) ou do próprio grupo ($P_{xx}$) em seu ambiente local.
*   **Assimetria:** A exposição não é simétrica (a exposição de negros a brancos $\neq$ brancos a negros).
*   **Normalização:** Índices de isolamento devem ser normalizados pela proporção real do grupo na cidade para permitir comparações interurbanas válidas, separando o isolamento espacial do mero tamanho demográfico do grupo.

### 2.3. Segregação Local vs. Global
Índices globais resumem a cidade em um número, mascarando enclaves.
*   **Diretriz:** Todo índice global instanciado deve prever sua **decomposição local** (ex: $d_i, h_i$). O projeto privilegia abordagens multiescalares contínuas e estatísticas locais como *Focal Location Quotients (FLQ)* ou *LISA / Moran Local* (com matrizes ponderadas) para a extração de *hotspots*.

---

## 3. Armadilhas Metodológicas e Divergências Teóricas

O bot deve ser implacável na identificação dos seguintes vieses durante a revisão:

### 3.1. O Viés de Pequenas Amostras e o "Auto-contato"
Índices de segregação inflam artificialmente em polígonos com baixa população ou grupos minoritários reduzidos, gerando "falsa segregação" estocástica (Fossett, 2017).
*   **A Solução Algorítmica:** O código deve implementar a correção de viés extraindo o "auto-contato". Ao calcular a proporção racial do ambiente local para um indivíduo, **o próprio indivíduo deve ser excluído do denominador e numerador**. Além disso, testes de *Bootstrap* ou *Monte Carlo* devem validar a significância dos clusters.

### 3.2. O Problema da Unidade de Área Modificável (MAUP)
A segregação muda conforme o tamanho do polígono (escala) e o desenho das fronteiras (zoneamento).
*   **A Solução Algorítmica:** Os parâmetros de vizinhança (ex: raio ou *bandwidth* $bw$ em funções Kernel) **nunca devem estar em *hardcode***. O código deve permitir a parametrização de escalas (ex: de 400m a 3000m).

### 3.3. Distância Euclidiana vs. Distância de Rede (A Tensão Topológica)
Há uma divergência na literatura sobre a construção do "ambiente local":
*   *Abordagem Contínua:* Utiliza raios euclidianos (linhas retas) e estimadores Kernel (Reardon & O'Sullivan).
*   *Abordagem de Conectividade (SPC):* Argumenta que a infraestrutura construída segrega. Barreiras físicas (rodovias, rios) exigem que a distância seja medida pela **rede de ruas (Network Distance)** (Roberto, 2018; Knapp & Rey, 2023).
*   **O Veredito para o Bot:** O bot deve questionar usos acríticos de distância euclidiana em matrizes de vizinhança, sugerindo abordagens topológicas ou justificativas metodológicas para a escolha.

### 3.4. O Debate dos Tipping Points (Limiares de Virada)
Há dissenso sobre a existência de quebras estruturais bruscas (*white flight* absoluto em um ponto exato, ex: 30% de minoria). Literatura recente aponta para processos contínuos não-lineares (Korpi et al., 2023).
*   **O Veredito para o Bot:** Rejeitar códigos com limiares arbitrários estáticos (`if pct_negros > 0.3`). O código deve basear a definição de territórios em Lógica *Fuzzy* (graus de pertencimento) ou na Tipologia de Áreas Absolutas de Johnston et al. (Cidadelas, Enclaves Mistos, Guetos).

---

## 4. Arquitetura de Dados e Padrões de Reprodutibilidade

O *Gui do Bosque* deve garantir que os preceitos de Ciência Aberta e do *The Turing Way* sejam respeitados no repositório.

### 4.1. Camadas de Dados (Medallion Architecture)
*   **`/data/1_bronze/`:** Dados brutos inalteráveis (ex: extrações brutas do Censo/IBGE). **Nenhum script deve reescrever nesta pasta.**
*   **`/data/2_silver/`:** Dados tratados, limpos e harmonizados territorialmente.
*   **`/data/3_gold/`:** Matrizes finais e índices prontos para consumo. Formato exigido: `.parquet` (arquivos `.csv` devem ser limitados a outputs de interface humana).

### 4.2. Higiene de Código
*   **Caminhos e Pathing:** O uso de caminhos absolutos (`C:/Users/...`) é estritamente **proibido**. O código deve usar o pacote `here` (em R) ou `pathlib` (em Python) garantindo a execução relativa à raiz do projeto.
*   **Gerenciamento de Dependências:** Instalações *ad-hoc* (`install.packages()`, `!pip install` em notebooks principais) são proibidas. Tudo deve ser controlado via `renv.lock` ou `requirements.txt`/`poetry`.
*   **Separação de Preocupações:** O pipeline primário (em `/src/`) não deve conter efeitos colaterais visuais interativos. Gerações de mapas exploratórios e gráficos devem residir em relatórios (`/reports/` via `.Rmd`/`.qmd`) ou na `/sandbox/`.
*   **Nomenclatura:** Funções lógicas e infraestrutura devem estar em `snake_case` e em inglês (ex: `calculate_spatial_isolation()`). Categorias sociológicas ou demográficas locais devem permanecer em português (ex: `pretos`, `renda_sm`).

---

## 5. Matriz de Ação Heurística para o "Gui do Bosque" (Checklist de PR)

Ao avaliar um *Pull Request*, processe as seguintes diretrizes antes de submeter sua análise:

1.  **Auditoria Espacial:** O cálculo de índice global ($D$, $H$, $G$) é puramente composicional dentro de zonas estáticas? Se sim, **solicite a injeção de matrizes de peso ($W$) ou funções Kernel.**
2.  **Auditoria Interseccional:** As agregações populacionais permitem cruzamento com fatores estruturais (ex: raça + posse de imóvel + renda)? Se a raça for tratada como variável isolada causadora biológica, **sugira modelagem orientada ao racismo estrutural (QuantCrit).**
3.  **Auditoria de Denominadores:** O código lida com minorias pequenas em escalas micro (viés estocástico)? Se não houver correção de auto-contato ou suavização (simulações iterativas/Bayesianas), **rejeite ou emita alerta grave.**
4.  **Auditoria de Integração:** O modelo trata "ausência de segregação" como mera assimilação à norma branca? Exija que o cálculo considere **homofilia espacial** vs. **acesso a oportunidades**, avaliando equipamentos-âncora do *Urbanismo Social* e matrizes de acessibilidade.
5.  **Auditoria Arquitetural:** O script escreve diretamente em `/1_bronze/`? Possui pacotes perdidos? Usa caminhos absolutos? **Bloqueie o *merge* até a refatoração.**