import("ca")

--[[ ============================================================================
  MODELO CSR EM AUTÔMATO CELULAR (TerraME)
  ==============================================================================

  AUTOR: Diego Pinheiro de Menezes, Celso Graminha e Pedro Andrade
  DATA: 10 de setembro de 2025
  VERSÃO: 1.0

    DESCRIÇÃO
    Autômato 2D 66×66 com miolo ativo 64×64 (borda inerte de 1 célula). baseado na teoria C–S–R de Grime. Estados: C, S, R e combinações
    (CS, CR, SR, CSR).
    Cada passo tem duas fases: (1) perturbação/manutenção e (2) crescimento/dispersão com prioridade ao crescimento vegetativo.

    OBJETIVO
    Investigar como três atributos — crescimento vegetativo, longevidade tecidual e fecundidade por sementes — moldam a dinâmica comunitária,
    por regras probabilísticas aplicadas à vizinhança de Moore (3×3).

   REFERÊNCIA:
    COLASANTI, R. L.; HUNT, R.; WATRUD, L. A simple cellular automaton model for high-level vegetation dynamics.
    Ecological Modelling, v. 203, n. 3–4, p. 363–374, 2007. DOI: 10.1016/j.ecolmodel.2006.12.039.

  TEORIA CSR:
  - C (Competidor): Plantas com alto crescimento vegetativo, boa em competir
    por recursos em ambientes favoráveis.
  - S (Tolerante ao Estresse): Plantas com alta longevidade tissular, adaptadas
    a ambientes com estresse (nutrientes, água, luz limitados).
  - R (Ruderal): Plantas com alta produção de sementes, adaptadas a ambientes
    com distúrbios frequentes.

  ESTRUTURA DO MODELO:
  - Espaço: Grade 66x66 células com miolo ativo 64×64 para evitar extrapolar índices.
  - Tempo: Passos discretos com duas fases por iteração
  - Estados: 8 tipos (vazio + 7 estratégias CSR e combinações)

  FASES POR PASSO DE TEMPO:
  1. Fase de Perturbação e Manutenção
         - Distúrbio: com prob. 'dist', a célula zera (morte)
       - Manutenção: se não houve distúrbio, a planta persiste se há recurso
         (prob. 'rec') OU se o tecido sobrevive (prob. 'tissue[estado]')

  2. Fase de Crescimento e Dispersão (com prioridade para crescimento vegetativo)
         - **Prioridade vegetativa**: se Σgrow>0 na vizinhança, ocupa por roleta
         ponderada em grow[.].
       - **Sementes**: se ainda vazio e Σseed>0, primeiro sorteia p = 1 - exp(-Σseed/decaimento),
         e se aprovado, ocupa por roleta em seed[.].

  PARÂMETROS AJUSTÁVEIS:
  - grow[]: Pesos de crescimento vegetativo (rizomas/estolões)
  - seed[]: Pesos de produção e dispersão de sementes
  - tissue[]: Probabilidades de sobrevivência tissular
  - decaimento: Constante para cálculo de estabelecimento por sementes
  - rec: Probabilidade de acesso a recursos
  - dist: Probabilidade de distúrbio
  - ptipo: Número inicial de indivíduos por tipo
  - npassos: Número total de iterações

  SAÍDAS:
  - Arquivo CSV com séries temporais de cobertura por classe
  - Sequência de imagens PNG da distribuição espacial
============================================================================ ]]--

-------------------------------------------------------------------------------
-- PARÂMETROS DO MODELO - ESTRATÉGIAS DE VIDA VEGETAL
-------------------------------------------------------------------------------
-- Tabela de pesos para crescimento vegetativo (propagação clonal)
-- Representa a capacidade de ocupação via rizomas, estolões e outros
-- mecanismos de crescimento vegetativo
local grow = {
    [0] = 0.0,   -- Vazio: sem crescimento
    [1] = 1.0,   -- C (Competidor): Alto crescimento vegetativo
    [2] = 0.2,   -- S (Tolerante ao Estresse): Baixo crescimento vegetativo
    [3] = 0.0,   -- R (Ruderal): Sem crescimento vegetativo (prioridade a sementes)
    [4] = 0.6,   -- CS: Intermediário entre Competidor e Tolerante
    [5] = 0.6,   -- CR: Intermediário entre Competidor e Ruderal
    [6] = 0.1,   -- SR: Intermediário entre Tolerante e Ruderal
    [7] = 0.4    -- CSR: Estratégia geral/intermediária
}

-- Tabela de pesos para produção e dispersão de sementes
-- Representa a capacidade de reprodução sexuada e colonização a longa distância
local seed = {
    [0] = 0.0,   -- Vazio: sem sementes
    [1] = 0.2,   -- C: Baixa produção de sementes (prioridade ao crescimento)
    [2] = 0.2,   -- S: Baixa produção de sementes (prioridade à sobrevivência)
    [3] = 1.0,   -- R: Alta produção de sementes (estratégia ruderal)
    [4] = 0.2,   -- CS: Baixa produção (herança de C e S)
    [5] = 0.6,   -- CR: Intermediária (balanceamento entre C e R)
    [6] = 0.6,   -- SR: Intermediária (balanceamento entre S e R)
    [7] = 0.5    -- CSR: Produção moderada (estratégia geral)
}

-- Tabela de probabilidades de sobrevivência tissular
-- Representa a longevidade e resistência a condições adversas
local tissue = {
    [0] = 0.0,   -- Vazio: não aplicável
    [1] = 0.0,   -- C: Baixa sobrevivência (estrategista oportunista)
    [2] = 0.95,  -- S: Alta sobrevivência (adaptado ao estresse)
    [3] = 0.0,   -- R: Baixa sobrevivência (ciclo de vida curto)
    [4] = 0.8,   -- CS: Alta sobrevivência (herança de S)
    [5] = 0.0,   -- CR: Baixa sobrevivência (herança de C e R)
    [6] = 0.8,   -- SR: Alta sobrevivência (herança de S)
    [7] = 0.75   -- CSR: Sobrevivência moderada
}

-- Parâmetros gerais do modelo
local decaimento = 3.0    -- Constante de decaimento para estabelecimento de sementes
                          -- Controla a curva: p = 1 - exp(-Σseed / decaimento)
                          -- Valores maiores = menor probabilidade de estabelecimento

local rec = 0.80          -- Probabilidade de acesso a recursos
                          -- Gate que controla se o crescimento/dispersão pode ocorrer

local dist = 0.10         -- Probabilidade de distúrbio (evento que zera a célula)
                          -- Representa perturbações como fogo, pastejo, etc.

local ptipo = 200         -- Número inicial de indivíduos por tipo estratégico
                          -- Define a fundação inicial da comunidade

local npassos = 500       -- Número total de passos de simulação
                          -- Determina a duração do experimento

--------------------------------------------------------------------------------
-- CONFIGURAÇÃO ESPACIAL E VISUAL
--------------------------------------------------------------------------------
-- Dimensões do espaço de simulação
local n = 66              -- Grade total 66x66
local a1, a2 = 2, 65      -- área ativa: 2..65 (borda inerte: linhas/colunas 1 e 66) - adaptado de Java para Lua

-- Paleta de cores para visualização dos tipos estratégicos
-- Mapeamento estado → cor RGB para visualização
local cores = {
    {250,250,250},  -- 0: Vazio - Branco
    {0,250,0},      -- 1: C (Competidor) - Verde
    {0,0,250},      -- 2: S (Tolerante) - Azul
    {250,0,0},      -- 3: R (Ruderal) - Vermelho
    {0,160,160},    -- 4: CS - Ciano
    {120,160,0},    -- 5: CR - Verde-amarelado
    {160,0,160},    -- 6: SR - Magenta
    {80,80,80}      -- 7: CSR - Cinza escuro
}

--------------------------------------------------------------------------------
-- INICIALIZAÇÃO DO MODELO
--------------------------------------------------------------------------------
-- Configuração da semente aleatória para reproducibilidade
math.randomseed(42)

-- Criação do espaço celular inicial
local grd = CellularSpace{ xdim = n}
forEachCell(grd, function(c)
    c.state = 0  -- Inicializa todas as células como vazias (estado 0)
end)

-- Função auxiliar: estado seguro da célula
-- Retorna o estado de uma célula, tratando posições inválidas como vazias
-- @param sp: Espaço celular
-- @param x: Coordenada x (pode estar fora dos limites)
-- @param y: Coordenada y (pode estar fora dos limites)
-- @return: Estado da célula (0 se inválida ou fora dos limites)
local function est(sp, x, y)
    local c = sp:get(x, y)
    return (c and c.state) or 0
end

---------------------------------------------------------------------------
-- INICIALIZAÇÃO: Distribuição inicial das estratégias
---------------------------------------------------------------------------
-- Configura a fundação inicial com ptipo indivíduos de cada estratégia
-- distribuídos aleatoriamente pelo espaço
do
    local falta = {
        [1] = ptipo,  -- C
        [2] = ptipo,  -- S
        [3] = ptipo,  -- R
        [4] = ptipo,  -- CS
        [5] = ptipo,  -- CR
        [6] = ptipo,  -- SR
        [7] = ptipo   -- CSR
    }
    local resto = ptipo * 7  -- Total de indivíduos a distribuir

    -- Distribuição aleatória até preencher todos os indivíduos (somente no miolo 2..65), , deixando a
    -- borda (linhas/colunas 1 e 66) inerte (=0) para atuar como buffer.
    while resto > 0 do
    -- Sorteia uma célula até cair DENTRO do miolo (2..65).
        local cel
        repeat
            cel = grd:sample()   -- célula aleatória em 66×66
        until cel.x >= a1 and cel.x <= a2 and cel.y >= a1 and cel.y <= a2

        -- Só planta em célula vazia (state==0) para não sobrescrever.
        if cel.state == 0 then
            -- Escolhe um tipo estratégico aleatório (1..7).
            local t = 1 + math.random(0, 6)  -- 1..7

            -- Respeita a cota por tipo: só planta se ainda falta[t] > 0.
            if falta[t] > 0 then
                cel.state = t                   -- planta o tipo sorteado
                falta[t] = falta[t] - 1
                resto = resto - 1           -- atualiza total que falta plantar
            end         -- Se a cota daquele tipo já estiver cheia, não planta e volta ao loop.
        end             -- Se a célula sorteada não estava vazia, apenas repete o processo.
    end
end

--------------------------------------------------------------------------------
-- CONFIGURAÇÃO DE SAÍDAS
--------------------------------------------------------------------------------
-- Mapa para visualização espacial
local mapa = Map{
    target = grd,
    select = "state",
    value  = {0, 1, 2, 3, 4, 5, 6, 7},
    color  = cores
}
mapa:save("frame_0000.png")  -- Salva estado inicial

-- Arquivo CSV para séries temporais
local csv = io.open("resultados.csv", "w")
csv:write("time_step,empty,C,S,R,CS,CR,SR,CSR\n")

-- Função: Salva estatísticas temporais no CSV
-- Contabiliza células por estado e registra no arquivo
-- @param t: Passo de tempo atual
local function salva_csv(t)
    local contadores = {0, 0, 0, 0, 0, 0, 0, 0}  -- Um para cada estado (0-7)

    -- Contagem de células por estado
    for x = a1, a2 do
        for y = a1, a2 do
            local s = est(grd, x, y)
            contadores[s + 1] = contadores[s + 1] + 1
        end
    end

    -- Formato: tempo, vazio, C, S, R, CS, CR, SR, CSR
    csv:write(("%d,%d,%d,%d,%d,%d,%d,%d,%d\n"):format(
        t, contadores[1], contadores[2], contadores[3], contadores[4],
        contadores[5], contadores[6], contadores[7], contadores[8]
    ))
end
salva_csv(0)  -- Salva estado inicial

--------------------------------------------------------------------------------
-- FASE 2: CRESCIMENTO E DISPERSÃO
--------------------------------------------------------------------------------
-- Processa colonização vegetativa e por sementes para uma célula-alvo
-- @param now: Buffer do estado atual (leitura)
-- @param nxt: Buffer do próximo estado (escrita)
-- @param x: Coordenada x da célula-alvo
-- @param y: Coordenada y da célula-alvo
local function crescer(now, nxt, x, y)
    -- Verificação de limites: só processa células dentro do domínio
    if x < a1 or x > a2 or y < a1 or y > a2 then return end

    -- Só processa células de destino que existam e estejam vazias
    local celula_destino = nxt:get(x, y)
    if not celula_destino or celula_destino.state ~= 0 then return end

    -- Análise da vizinhança Moore 3x3 (incluindo centro)
    local vizinhos = {}          -- Estados dos vizinhos
    local peso_vegetativo = 0.0  -- Soma dos pesos de crescimento vegetativo
    local peso_sementes = 0.0    -- Soma dos pesos de produção de sementes

    for xx = x-1, x+1 do
        for yy = y-1, y+1 do
            local estado_vizinho = est(now, xx, yy)
            table.insert(vizinhos, estado_vizinho)
            peso_vegetativo = peso_vegetativo + grow[estado_vizinho]
            peso_sementes = peso_sementes + seed[estado_vizinho]
        end
    end

    -- (1) COLONIZAÇÃO VEGETATIVA (prioridade)
    -- Ocorre se houver potencial vegetativo na vizinhança
    if peso_vegetativo > 0.0 then
        local roleta = math.random() * peso_vegetativo
        local acumulado = 0.0

        -- Seleção por roleta ponderada: maior grow[s] = maior probabilidade
        for i = 1, #vizinhos do
            acumulado = acumulado + grow[vizinhos[i]]
            if acumulado >= roleta then
                celula_destino.state = vizinhos[i]
                break
            end
        end
    end

    -- (2) ESTABELECIMENTO POR SEMENTES (só se ainda vazio)
    -- Ocorre se a célula permaneceu vazia após tentativa vegetativa
    -- e há potencial de sementes na vizinhança
    if celula_destino.state == 0 and peso_sementes > 0.0 then
        -- Probabilidade não-linear de estabelecimento
        local prob_estabelecimento = 1.0 - math.exp(-peso_sementes / decaimento)

        if math.random() < prob_estabelecimento then
            local roleta = math.random() * peso_sementes
            local acumulado = 0.0

            -- Seleção por roleta ponderada: maior seed[s] = maior probabilidade
            for i = 1, #vizinhos do
                acumulado = acumulado + seed[vizinhos[i]]
                if acumulado >= roleta then
                    celula_destino.state = vizinhos[i]
                    break
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- LOOP PRINCIPAL DE SIMULAÇÃO
--------------------------------------------------------------------------------
for passo = 1, npassos do
  print("passo "..passo)
    -- Criação do buffer para o próximo estado
    local prox_estado = CellularSpace{ xdim = n }
    forEachCell(prox_estado, function(c)
        c.state = 0  -- Inicializa como vazio
    end)

    -- FASE 1: PERTURBAÇÃO E MANUTENÇÃO
    -- Aplica distúrbios e verifica sobrevivência tissular
    for x = a1, a2 do
        for y = a1, a2 do
            local estado_atual = est(grd, x, y)      -- Estado no buffer atual
            local celula_prox = prox_estado:get(x, y) -- Célula no próximo buffer

            -- Verificação de segurança (célula deve existir)
            if celula_prox then
                -- Aplica distúrbio com probabilidade 'dist'
                if math.random() < dist then
                    celula_prox.state = 0  -- Distúrbio zera a célula
                else
                    -- Célula vazia permanece vazia
                    if estado_atual == 0 then
                        celula_prox.state = 0
                    else
                        -- Célula ocupada: verifica sobrevivência
                        -- Sobrevive se: tem acesso a recursos OU tecido persiste
                        local sobrevive = (math.random() < rec) or
                                        (math.random() < tissue[estado_atual])
                        celula_prox.state = sobrevive and estado_atual or 0
                    end
                end
            end
        end
    end

    -- FASE 2: CRESCIMENTO E DISPERSÃO
    -- Aplica colonização vegetativa e por sementes
    for x = a1, a2 do
        for y = a1, a2 do
            -- Só tenta colonizar se houver acesso a recursos
            if math.random() < rec then
                crescer(grd, prox_estado, x, y)
            end
        end
    end

    -- ATUALIZAÇÃO DO ESTADO
    forEachCellPair(grd, prox_estado, function(c1, c2)
        c1.state = c2.state
    end)

    -- SAÍDAS E REGISTRO
    mapa:update()               -- Atualiza visualização
    salva_csv(passo)            -- Registra estatísticas temporais

    -- Salva frame a cada 50 passos para animação
    if passo % 50 == 0 then
        mapa:save(("frame_%04d.png"):format(passo))
    end
end
--------------------------------------------------------------------------------
-- FINALIZAÇÃO
--------------------------------------------------------------------------------
csv:close()
print("Simulação concluída com sucesso!")
print("Saídas geradas: resultados.csv + frames PNG")