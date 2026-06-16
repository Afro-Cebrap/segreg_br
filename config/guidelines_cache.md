



# Manual Metodológico e Conceitual: Mapeamento de Territórios Negros e Segregação Urbana
**Projeto:** Afro-Cebrap
**Status:** Base de Conhecimento Canônica (Consolidada)

Este manual estabelece as diretrizes fundacionais, epistemológicas, matemáticas e algorítmicas para o cálculo de índices de segregação e modelagem espacial no Projeto Afro-Cebrap. Ele serve como o guia definitivo para pesquisadores, engenheiros de dados e agentes automatizados de revisão de código (*Code-Review Bots*, ex: "Gui do Bosque"). 

O código aqui produzido não é neutro: ele modela a geografia do racismo estrutural brasileiro.

---

## PARTE I: FUNDAMENTOS EPISTEMOLÓGICOS (QuantCrit)

A implementação algorítmica deve ser regida pela **Teoria Racial Crítica Quantitativa (QuantCrit)**, reconhecendo a herança colonial e eugênica da estatística clássica.

### 1.1. Categorias Raciais e Interseccionalidade
*   **A Categoria "Negro":** Operacionalizada analiticamente e politicamente pela soma de **Pretos + Pardos** (IBGE). O código não deve cindir essas categorias para atenuar a segregação ou postular privilégios estruturais aos pardos (falácia do colorismo estrutural). As categorias *Amarela* e *Indígena* não devem ser aglutinadas em lógicas binárias de forma invisível.
*   **Raça e Classe como Vetores Independentes:** A segregação no Brasil opera simultaneamente por raça e classe. O código **não deve** subsumir a raça à renda. O isolamento racial agudiza-se nas classes médias e altas. Negros de classe média habitam espaços radicalmente distintos de brancos de classe média.
*   **A Branquitude como Propriedade:** A segregação não é apenas a dispersão da população negra; é ativamente mantida pelo *isolamento da elite branca*. Algoritmos devem ser capazes de mapear "cidadelas brancas" com o mesmo rigor metodológico que mapeiam periferias.

### 1.2. Territórios de Agência (Decolonialidade)
A modelagem não deve tratar os territórios negros (favelas, quilombos) puramente como polígonos de déficit ou escassez.
*   **Apropriação e Associativismo:** Terreiros, clubes sociais, escolas de samba e redes de solidariedade feminina devem ser codificados como *infraestruturas-âncora* de resistência e produção epistêmica, não apenas como pontos de interesse geográfico.

---

## PARTE II: A TAXONOMIA DA SEGREGAÇÃO (Dimensões em Disputa)

O código deve explicitar a qual paradigma e dimensão a métrica pertence, lidando ativamente com as tensões da literatura.

### 2.1. O Colapso das Dimensões Clássicas
A taxonomia clássica de Massey & Denton (1988) propõe 5 dimensões (Uniformidade, Exposição, Concentração, Centralização, Agrupamento). **[DIVERGÊNCIA METODOLÓGICA]:** O Afro-Cebrap alinha-se à crítica espacial contemporânea (Reardon & O'Sullivan, 2004; Sabatini, 2006):
*   A dimensão de **Centralização** é rejeitada ou deve ser localmente adaptada, pois cidades latino-americanas são policêntricas e as elites não se concentram necessariamente no centro histórico (frequentemente formam "cones de alta renda" para as bordas).
*   Em modelos estritamente espaciais, as dimensões colapsam em dois macro-eixos:
    1.  **Uniformidade/Agrupamento Espacial (*Evenness/Clustering*):** Distribuição dos grupos.
    2.  **Exposição/Isolamento Espacial (*Exposure/Isolation*):** Probabilidade de contato/interação.

### 2.2. Tipologias Absolutas vs. Índices Relativos
Além de índices matemáticos contínuos, o código deve suportar **Classificações Tipológicas Absolutas** (Johnston et al., 2007; Poulsen et al., 2001).
*   Um *Gueto* (Tipo IV/V) exige **dois critérios cumulativos** no código: (a) o grupo minoritário forma $\ge$ 60-70% da população local **E** (b) pelo menos 30% da população total daquele grupo na cidade reside em áreas com esse nível de concentração.

---

## PARTE III: ESPECIFICAÇÕES DOS ÍNDICES DE SEGREGAÇÃO

A base da implementação deve seguir o **Paradigma da Diferença de Médias** (Fossett, 2017). Todo índice clássico ($D, G, S, H$) pode ser codificado como a diferença aritmética simples entre as médias de um "resultado residencial" para indivíduos do Grupo 1 e Grupo 2 ($Y_1 - Y_2$).

### 3.1. O Conflito Crítico: Dissimilaridade (D) vs. Separação (S)
Esta é a distinção algorítmica mais vigiada no projeto. **Deslocamento $\neq$ Separação**.
*   **Índice de Dissimilaridade (D):** Mede *deslocamento* (proporção que precisa se mudar). É uma função degrau (0 ou 1) ao cruzar a paridade. **Limitação:** Gera falsos-positivos de "alta segregação" em cenários de *Deslocamento Disperso* (minorias espalhadas, mas abaixo da paridade). Ignora a polarização real.
*   **Índice de Separação / Razão de Variância (S / $\eta^2$):** Mede a *polarização estrita*. Mantém a métrica natural de contato ($y = p$). Um valor alto de $S$ garante a existência de guetos/enclaves fortemente racializados.
*   **Implementação Exigida:** O código *não pode* basear alertas de guetização apenas em $D$. Deve-se avaliar a convergência: Segregação estrutural ocorre quando $S \ge 95\%$ de $D^{3/2}$.

### 3.2. Índices de Exposição ($P_{xy}$) e Isolamento ($P_{xx}$)
*   **Assimetria Matemática:** A exposição do grupo X a Y *não é igual* à de Y a X ($P_{xy} \neq P_{yx}$). O código não deve tratar essas matrizes como simétricas.
*   **Normalização:** Índices brutos sofrem viés do tamanho populacional da cidade. O código deve implementar a versão normalizada dividindo o índice pela proporção geral do grupo ($\tau_m$). **Atenção:** Versões normalizadas sem viés (*unbiased*) podem resultar em valores negativos sob forte integração institucional; o código não deve truncar os resultados em `0`.

### 3.3. Teoria da Informação / Entropia (H)
*   Considerado o padrão-ouro para análise **multigrupo** (Reardon & O'Sullivan, 2004).
*   Altamente decomponível (espacialmente e inter/intra-grupos).
*   **Exceção de Divisão por Zero:** O código deve tratar o limite quando $p = P$ (onde a fórmula teórica gera divisão por zero), utilizando aproximações assintóticas ($\pm 0.0000001$).

### 3.4. Índice de Concentração nos Extremos (ICE)
*   **Fórmula:** $ICE_i = (A_i - P_i) / T_i$
*   Ideal para interseccionalidade (ex: *Brancos de Alta Renda* vs. *Negros de Baixa Renda*), evitando distorções de multiplicações de variáveis de dummy. Varia de -1 a 1.

---

## PARTE IV: IMPLEMENTAÇÃO ESPACIAL E VIZINHANÇA (O "COMO")

Índices de 1ª Geração (aspaciais) são considerados obsoletos por sofrerem do **Problema do Tabuleiro de Xadrez** e do **MAUP** (Modifiable Areal Unit Problem). O código deve adotar arquiteturas de 2ª ou 3ª Geração.

### 4.1. Intensidade Populacional Local e Estimadores Kernel
*   O cálculo de exposição ($p$) não deve usar a contagem bruta do polígono isolado, mas a **Intensidade Populacional Local ($\breve{L}_j$)**.
*   **Implementação:** Utilizar estimadores KDE (Kernel Density Estimators) nos centroides ou *grid data* de alta resolução (ex: 100x100m).
*   **Multiescalaridade:** O raio de busca (*bandwidth*) não deve ser *hardcoded*. O código deve calcular *perfis de segregação* iterando sobre múltiplas escalas (ex: de 700m a 7000m).

### 4.2. A Transição para Redes (Método SPC e CHASM)
Distâncias euclidianas (linha reta) invisibilizam barreiras estruturais do racismo (rodovias, muros, rios, escadarias sem calçada).
*   **Grafos e Roteamento:** O código deve calcular proximidade ($W_{ij}$) utilizando **distância de rede viária**.
*   **A Perspectiva da 1ª Infância (Urban95):** Em favelas, as rotas devem ser calculadas com impedâncias topográficas e considerando a cota visual de 95cm.
*   **Função de Impedância (Tempo de Viagem):** Utilizar matrizes de tempo (ex: corte máximo de 20 min de caminhada a 4.5km/h), aplicando decaimento quadrático, rejeitando decaimentos lineares irreais.

### 4.3. Viés de Pequenas Amostras (Upward Bias)
Unidades espaciais com baixa população geram falsa segregação matemática.
*   **Prática Rejeitada:** Excluir polígonos com $N$ pequeno.
*   **Soluções Aceitas no Código:** 
    1.  *Unbiased Indices (Fossett):* Remoção do "autocontato" subtraindo o indivíduo do denominador ($t-1$).
    2.  *Bootstrapping / Monte Carlo:* Reamostragem espacial simulada.
    3.  *Modelos Multinível Hierárquicos:* Absorção do ruído no nível estocástico base.

---

## PARTE V: AVISOS METODOLÓGICOS E DISPUTAS (Caveats)

O código não deve resolver disputas acadêmicas com heurísticas silenciosas. Divergências devem ser documentadas.

1.  **Co-presença $\neq$ Interação Social:** O processamento de Big Data (GPS/Celular) pode identificar Brancos e Negros na mesma coordenada de "espaço de atividade". O código deve nomear isso como `co-presence` ou `exposure`, nunca como `social_interaction`, pois o espaço pode ser compartilhado sob hierarquias violentas (ex: regime de convivialidade subordinada / "quartinho de empregada").
2.  **Modelos Causal-Agregados (Falácia Ecológica):** O bot rejeitará regressões OLS de nível macro (cidade) que tentem prever a segregação usando rendas médias agregadas. Controles socioeconômicos devem ser modelados em nível *micro* (indivíduo/domicílio) através de Diferença de Médias ou HLM.
3.  **Dinâmica de Tipping Point [PROVISIONAL]:** A busca algorítmica por um limiar exato (ex: 20%) que engatilha a "fuga branca" (*white flight*) usando o método *Fixed-Point* falha em micro-escalas. O código deve preferir R²-Maximization com validação cruzada de Monte Carlo, reconhecendo que a segregação frequentemente é contínua e não-linear, não uma ruptura binária.
4.  **Convergência de Modelos de Agentes (MASUS/Schelling):** Não assuma que simulações de preferência atingirão um equilíbrio perfeito. Sistemas multirraciais podem entrar em Ciclos Contínuos de Melhoria (IRCs). Adicione *circuit-breakers* nos loops `while`.

---

## PARTE VI: GOVERNANÇA DE CÓDIGO E ARQUITETURA DE DADOS

Para manter o rigor metodológico, a engenharia de software do Afro-Cebrap obedece a regras sociotécnicas estritas:

### 6.1. Arquitetura Medallion (Isolamento de Dados)
*   **`/data/1_bronze`:** Dados originais (IBGE, CadÚnico). Imutáveis e somente leitura. O código jamais escreve nesta camada.
*   **`/data/2_silver`:** Tratamento, higienização de categorias (ex: junção de Pretos+Pardos = Negros) e harmonização espacial.
*   **`/data/3_gold`:** Índices processados e matrizes finais em formato `.parquet`. Acompanhados obrigatoriamente de metadados FAIR (`datapackage.json`).

### 6.2. Reprodutibilidade e Integração (GCP/CI-CD)
*   **Zero *Hardcoding*:** Caminhos devem ser relativos (uso do pacote `here` em R ou equivalentes em Python). Limiares metodológicos (ex: cutoff de renda de 2 salários mínimos, *bandwidth* do Kernel) devem ser carregados de arquivos de configuração, não embutidos nas funções.
*   **Gestão de Pacotes:** Estritamente via `renv.lock` ou `requirements.txt`/`poetry`. É terminantemente proibido o uso de `install.packages()` ou `pip install` soltos em scripts de *pipeline*.
*   **Separação Exploratória:** Scripts na pasta `src/` (pipeline CRISP-DM numerado) não podem conter código de visualização ad-hoc (`ggplot`, `matplotlib.show`). Experimentos pertencem exclusivamente à pasta `sandbox/`.

### 6.3. O Papel do "Gui do Bosque" (Revisor Automatizado)
O bot operará avaliando PRs integrados via Workload Identity Federation (GCP). Sua resposta a falhas não deve ser apenas punitiva-sintática, mas **pedagógica e bibliográfica**. Se um desenvolvedor usar um Índice de Dissimilaridade (D) aspacial para mapear guetos, o bot não apenas apontará o erro técnico, mas citará o *Checkerboard Problem*, a diferença sociológica entre *Deslocamento e Separação (S)*, e exigirá a implementação de uma matriz de contiguidade de rede.