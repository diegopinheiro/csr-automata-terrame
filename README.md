# terrame-csr-lua

[![language](https://img.shields.io/badge/language-Lua-blue.svg)](https://www.lua.org/)
[![platform](https://img.shields.io/badge/platform-TerraME-success.svg)](https://www.terrame.org/)
[![license](https://img.shields.io/badge/license-MIT-lightgrey.svg)](LICENSE)

> **EN** · Implementation of a cellular automata (CA) model of vegetation dynamics under the C–S–R framework (Grime) in **Lua** for the **TerraME** platform.  
> **PT-BR** · Implementação de um modelo de autômato celular (AC) de dinâmica da vegetação no arcabouço **C–S–R** (Grime) em **Lua** para a plataforma **TerraME**.

---

## ✨ Overview / Visão Geral

- **Grid:** 66×66 com **núcleo ativo 2..65** (borda inerte para evitar checagens de limite).
- **Estados (8):** `0` vazio; `1` C; `2` S; `3` R; `4` CS; `5` CR; `6` SR; `7` CSR.
- **Parâmetros globais:** `rec=0.80`, `dist=0.10`, `decaimento=3.0` (p. sementes: `p = 1 − exp(−Σ seed / decaimento)`).
- **Inicialização:** 200 indivíduos por tipo (1..7) no núcleo; demais células vazias; **semente pseudoaleatória fixa**.
- **Dinâmica por passo (t=1..500):**
  - **Fase 1 – Manutenção:** se ocorrer **distúrbio** (prob. `dist`) → turnover local; caso contrário, **persistência** por `rec` ou `tissue[s]`.
  - **Fase 2 – Colonização:** vizinhança de **Moore 3×3**; prioridade para **crescimento vegetativo (grow)**; se alvo vazio → estabelecimento por **semente** com `p` e roleta em `seed`.
- **Saídas:** mapas/figuras por passo e **CSV** de contagens por classe (comparáveis à versão Java).

---

## 📁 Repository Structure / Estrutura

```
terrame-csr-lua/
├─ src/
│  ├─ main.lua              # ponto de entrada da simulação (AC C–S–R)
│  ├─ model.lua             # definição de estados, regras e parâmetros
│  ├─ utils.lua             # utilidades (aleatoriedade, I/O, vizinhança, etc.)
│  └─ viz.lua               # geração de mapas/figuras por passo (opcional)
├─ scripts/
│  ├─ experiment.lua        # execuções por cenário, múltiplas réplicas
│  └─ validate.lua          # comparação com séries do Java (se disponível)
├─ data/
│  └─ inputs/               # parâmetros externos, seeds, etc. (opcional)
├─ output/
│  ├─ csv/                  # contagens por classe a cada t
│  └─ figs/                 # imagens dos estados por passo
├─ docs/
│  ├─ figures/              # figuras para o banner/artigo
│  ├─ fluxo.drawio          # fluxograma (diagramas.net)
│  └─ fluxo.mmd             # fluxograma (Mermaid)
├─ .gitignore
├─ LICENSE
└─ README.md
```

> Substitua/ajuste os nomes de arquivos caso o seu projeto já tenha um `main.lua` e bibliotecas próprias.

---

## ⚙️ Requirements / Requisitos

- **TerraME** (ambiente de modelagem baseado em **Lua**).  
- **Lua 5.3+** (já embarcado no TerraME em muitas distribuições).  
- **ZeroBrane Studio** (opcional, para depuração/IDE).

> Em sistemas com CLI do TerraME disponível no PATH, você pode chamar `terrame` diretamente no terminal.

---

## ▶️ How to Run / Como Executar

**Terminal (CLI):**
```bash
# 1) clone o repositório
git clone https://github.com/<seu-usuario>/terrame-csr-lua.git
cd terrame-csr-lua

# 2) execute a simulação (ajuste o caminho do TerraME/arquivo se necessário)
terrame src/main.lua

# opções comuns:
# terrame --seed 42 src/main.lua
# terrame -e scripts/experiment.lua   # roda experimentos/repetições
```

**ZeroBrane Studio (opcional):**
1. File → Open → selecione `src/main.lua`.  
2. Run → **Run** (ou F6).  
3. Verifique **Console** e saída em `output/`.

---

## 🔬 Reproducibility / Reprodutibilidade

- Semente pseudoaleatória fixa (ex.: `math.randomseed(42)`) para reduzir variação entre execuções.
- CSVs com contagens por classe permitem comparar séries temporais Lua/TerraME vs. Java.

---

## 📊 Validation / Validação

- Concordância **qualitativa** esperada (padrões espaciais, pulsos pós-distúrbio etc.).  
- Diferenças residuais podem ocorrer por: ordem de varredura, empates estocásticos e PRNG.

---

## 🧭 Roadmap / Próximos Passos

- Múltiplas **réplicas** por cenário; análise de **sensibilidade** (rec, dist, decaimento).  
- Métricas de **paisagem** (manchas, contágio, etc.).  
- Exportes adicionais (GeoTIFF/PNG), benchmarks e profiling.

---

## 📄 References / Referências

- Grime, J. P. (1977, 2001) – **C–S–R** plant strategies.  
- Colasanti, R. L., Hunt, R., & Watrud, L. (2007). *A simple cellular automaton model...* (modelo base C–S–R).  
- TerraME – Plataforma de modelagem espacial baseada em Lua.

> Adapte os metadados completos (título, periódico, DOI) conforme sua bibliografia.

---

## 📜 License / Licença

Distribuído sob **MIT License**. Consulte `LICENSE` para detalhes.

---

## 🤝 Contributing / Contribuindo

Contribuições são bem-vindas! Abra uma **Issue** para discutir mudanças ou envie um **Pull Request**.

---

## 🙌 Acknowledgments / Agradecimentos

- CST–INPE (curso/projeto).  
- Docentes e colegas que apoiaram a implementação/validação.
