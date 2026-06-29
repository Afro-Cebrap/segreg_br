<!-- ============================================================= -->
<!-- ARQUIVO GERADO AUTOMATICAMENTE por config/build_knowledge_base.py -->
<!-- Gerado em: 2026-06-29 11:27 UTC                                              -->
<!-- NÃO edite à mão: alterações serão sobrescritas no próximo build. -->
<!-- A biblioteca crua fica no GCS privado (não vai para este repo).  -->
<!-- ============================================================= -->

# Manual Metodológico: Mapeamento de Territórios Negros e Segregação Urbana

**Projeto:** Afro-Cebrap / IPEA-Dirur
**Natureza do Documento:** Base de Conhecimento Canônica (Handbook)
**Destinação:** Diretrizes para Desenvolvedores e Agente de *Code-Review* (Bot) em repositório público.

Este manual consolida os fundamentos epistemológicos, metodológicos e arquiteturais do projeto. O objetivo é garantir que a infraestrutura computacional e os algoritmos desenvolvidos não apenas processem dados, mas operem com rigor sociológico, espacial e matemático. **O código não é neutro; ele materializa escolhas teóricas.**

---

## 1. Fundamentos Epistemológicos e Conceituais

A implementação de métricas no contexto brasileiro exige a ruptura com modelos analíticos importados de forma acrítica e a superação do "mito da democracia racial". O espaço não é um pano de fundo passivo, mas um agente estratificador.

*   **A Abordagem QuantCrit:** Os números e as categorias raciais refletem hierarquias históricas. O código não deve assumir a "branquitude" como norma estatística (ex: hardcoding de categoria "branca" como referência padrão sem justificativa). As categorizações devem ser parametrizáveis.
*   **Interseccionalidade (Raça e Classe):** A segregação no Brasil não se resume à classe social. A distância residencial entre negros e brancos *aumenta* nas camadas sociais médias e altas (França, 2017; Telles, 1993). O código não deve permitir que o controle por renda (modelos *welfaristas*) mascare a dimensão racial como variável independente.
*   **A Categoria "Negros":** Operacionalmente, a junção das categorias censitárias "Pretos" e "Pardos" forma o grupo sociológico e político "Negros". Desagregações no código (ex: para medir colorismo) são bem-vindas, mas a agregação principal deve refletir a lógica de políticas de equidade.
*   **Espaço de Atividade (*Activity Space*):** A segregação extrapola o local de moradia. Modelos contemporâneos devem ser capazes de mensurar a segregação na mobilidade diária, avaliando o acesso a equipamentos-âncora (escolas, parques) e a co-presença em espaços públicos (Liao et al., 2025).

---

## 2. As Dimensões da Segregação: Tensões na Literatura

O código deve organizar os módulos de cálculo respeitando o debate acadêmico sobre a dimensionalidade da segregação:

*   **A Visão Clássica (5 Dimensões):** Massey & Denton (1988) categorizaram a segregação em Uniformidade, Exposição, Concentração, Centralização e Agrupamento.
*   **A Abordagem Espacial Contemporânea (2 Superdimensões):** Reardon & O'Sullivan (2004) provam que, ao introduzir a topologia e o espaço contínuo, essas dimensões colapsam em duas famílias principais, que **devem pautar a arquitetura analítica do projeto**:
    1.  **Uniformidade / Agrupamento Espacial (*Spatial Evenness/Clustering*):** Mede o descompasso entre a composição demográfica local e a global.
    2.  **Exposição / Isolamento Espacial (*Spatial Exposure/Isolation*):** Mede a probabilidade empírica (potencial de contato) de indivíduos encontrarem pares do mesmo grupo ou de outros grupos em sua vizinhança.

*Nota de Implementação:* O projeto opta por organizar a base de código a partir da função matemática e do propósito explicativo, priorizando fortemente métricas de natureza *espacial* sobre as *a-espaciais*.

---

## 3. Especificação de Indicadores e Lógica Matemática

A transição de "fórmulas agregadas" para o paradigma da **Diferença de Médias** (Fossett) exige que os índices sejam calculados a partir dos resultados residenciais no nível do indivíduo/domicílio, integrando as visões micro e macro.

### 3.1. Medidas de Uniformidade (O Problema do Índice $D$)
*   **Índice de Dissimilaridade ($D$):** Tradicionalmente mede a proporção de um grupo que precisaria se mudar para atingir paridade.
    *   *Limitação Sociológica:* $D$ usa uma função degrau binária. Ele mede "deslocamento", mas é cego à magnitude da polarização quantitativa (Fossett). Pode gerar "falsos positivos" em cenários de dispersão.
*   **Índice de Separação ($S$ / Razão de Variância):** Mede a diferença bruta no contato real. Ao contrário de $D$, $S$ possui escalonamento linear. Um valor alto garante a existência de polarização real ("segregação prototípica"). **Sua implementação é fortemente recomendada como balizador de $D$.**
*   **Entropia / Teoria da Informação ($H$):** Mede a diversidade local contra a máxima teórica. É aditivamente decomponível e ideal para análises multigrupo. *Atenção:* É matematicamente sensível ao número de categorias inseridas ($K$); inserir minorias populacionais ínfimas (ex: < 0.1%) exige calibração cuidadosa.

### 3.2. Medidas Locais e Autocorrelação
*   **Quociente Locacional (QL):** Útil para identificar sub/sobre-representação, mas insuficiente isoladamente por ignorar vizinhança. Recomenda-se transformação logarítmica ($\ln QL$) para simetria visual.
*   **Índice de Moran Local (LISA):** Mandatório para mapeamento de "hotspots". Identifica agrupamentos espaciais estatisticamente significativos (alto-alto, baixo-baixo), superando a cegueira geográfica dos índices de primeira geração.

---

## 4. Cavernas Metodológicas: O que o Código Deve Evitar

Ao avaliar algoritmos espaciais, os seguintes vieses e erros clássicos devem ser ativamente prevenidos:

### 4.1. A-espacialidade e o "Tabuleiro de Xadrez"
Índices clássicos tratam unidades censitárias como "ilhas" estanques. Um bairro negro cercado por brancos gera o mesmo índice que um cercado por outros bairros negros.
*   **Diretriz:** A segregação deve ser calculada usando **Intensidade Populacional Local**, aplicando estimadores de *Kernel* (decaimento Gaussiano) ou matrizes de vizinhança ($W$) baseadas em contiguidade.

### 4.2. O Problema da Unidade de Área Modificável (MAUP) e a Falácia Euclidiana
As fronteiras censitárias são arbitrárias, e a distância em linha reta (Euclidiana) ignora a morfologia urbana (barreiras físicas como rodovias e rios).
*   **Diretriz:** Sempre que houver disponibilidade de dados, deve-se priorizar distâncias de rede (algoritmos de roteamento de ruas). Além disso, os algoritmos devem ser **multiescalares** (rodar sobre múltiplos raios/*bandwidths*, ex: 700m a 5000m) em vez de hardcodar uma única escala.

### 4.3. Viés de Pequenas Amostras (Small $N$) e o Autocontato
Aplicar fórmulas clássicas em microáreas (quarteirões) com poucos habitantes inflaciona drasticamente a segregação por variação estocástica. Além disso, a métrica tradicional sofre do viés de "autocontato", onde o próprio indivíduo conta no denominador da sua vizinhança.
*   **Diretriz:** É imperativa a implementação de **Índices Não-Viesados (*Unbiased*)**. O código deve subtrair o indivíduo focal do cálculo da proporção ($p' = \text{vizinhos} / \text{total} - 1$). Como alternativa em modelagens de regressão, utilizar Modelos Lineares Hierárquicos (HLM) para isolar o ruído de Poisson.

---

## 5. Arquitetura de Dados, Implementação e Governança

O repositório do Afro-Cebrap segue padrões rigorosos para garantir reproducibilidade, infraestrutura *cloud-native* e Ciência Aberta (FAIR).

### 5.1. Topologia do Datalake e Padrões
*   **Arquitetura Medallion:**
    *   `bronze/`: Dados oficiais brutos. **Imutáveis.**
    *   `silver/`: Dados padronizados e unidos espacialmente.
    *   `gold/`: Índices calculados e sumarizados para consumo (API/Apps).
*   **Formatos e Convenções:** Uso estrito do formato **`.parquet`** nas esteiras analíticas (CSV apenas para consumo final humano). Código em Inglês (`snake_case`), com exceção de variáveis sociológicas imutáveis do IBGE (ex: `pretos`, `pardos`).
*   **Proibição de Caminhos Absolutos:** O uso de diretórios locais (ex: `C:/Users/...`) é proibido. Uso mandatório de ferramentas de caminhos relativos (ex: pacote `here` no R).

### 5.2. Infraestrutura e Segurança (Keyless)
O projeto opera na Google Cloud Platform (GCP) utilizando princípio de privilégio mínimo.
*   **Regra de Ouro:** Nenhuma chave de API ou token deve ser *hardcoded* ou gravada em texto plano. A autenticação com os serviços (Cloud SQL, Cloud Storage) baseia-se exclusivamente em federação de identidades (Workload Identity Federation / OIDC).

---

## 6. Diretrizes Cognitivas para o Code-Review Bot (Heurísticas)

Ao analisar *Pull Requests* (PRs) e *scripts*, o agente automatizado deve aplicar as seguintes regras heurísticas para emissão de bloqueios ou alertas (*warnings*):

1.  **Auditoria de Espacialidade:** O código aplica um índice global ($D$, $G$) calculando proporções diretas (`df.groupby().sum()`)?
    *   *Ação:* Disparar *warning* alertando para o "Problema do Tabuleiro de Xadrez" e sugerir cálculo via matrizes espaciais (Kernel ou Vizinhança).
2.  **Validação Interseccional:** A rotina calcula "segregação por renda" e "segregação racial" em laços separados de forma universal?
    *   *Ação:* Exigir modelagem que suporte a intersecção (ex: negros de alta renda vs. brancos de alta renda), evitando a armadilha do determinismo puramente econômico.
3.  **Auditoria de MAUP (Multiescalaridade):** A função de cálculo espacial recebe um único parâmetro de distância fixo (`radius = 1000`)?
    *   *Ação:* Recomendar a parametrização para *arrays* de distâncias, a fim de gerar perfis escalares sensíveis à geometria local.
4.  **Detecção de Viés Populacional (Small $N$):** O código gera métricas sobre setores/quarteirões contendo populações minúsculas (ex: < 50 pessoas)?
    *   *Ação:* Checar se há implementação de correção *Unbiased* (remoção do autocontato) ou testes de permutação (Monte Carlo). Se não houver, alertar sobre distorção algorítmica grave.
5.  **Auditoria Semântica de Integração:** O código avalia áreas usando limites hardcoded americanos (ex: `if black_pop > 0.5: is_ghetto = True`)?
    *   *Ação:* Reprovar e sugerir a adoção de métricas de *Tipping Point* flexíveis e adaptadas à matriz demográfica do município analisado (Abordagem Comparativa).
6.  **Violação de Arquitetura de Dados:** Um script (`src/03_analise.R`) salva tabelas modificadas na camada `bronze/` ou utiliza pacotes sem registro em arquivo de dependências (lockfile)?
    *   *Ação:* Bloqueio imediato da esteira de CI/CD. Adequação arquitetural exigida.