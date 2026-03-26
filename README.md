# Diffnav.nvim 🛠️

*O bisturi soviético para resolução de conflitos e diffs no Neovim.*

## Visão Geral (O Manifesto)
O `diffnav.nvim` é um plugin desenhado para trazer a exata experiência tátil e visual de diff, stage e resolução de merges do VS Code diretamente para o Neovim. Sem depender de ferramentas antigas que dividem a tela em painéis caóticos, o Diffnav opera **dentro do buffer atual** utilizando a moderna engine de Extmarks (Marcas Estendidas) do Neovim.

## 🎯 Objetivos Táticos

1. **Inline Diffing (Estilo VS Code):**
   - Em vez de dividir a tela lado a lado (split view), as linhas apagadas (`deleted`) devem aparecer flutuando logo abaixo ou acima da linha alterada, com uma coloração vermelha e opaca, sem poderem ser editadas pelo usuário.
   - Linhas adicionadas (`added`) ganham um highlight de fundo verde direto no código vivo.

2. **Stage Cirúrgico (Linha a Linha / Hunk):**
   - Possibilidade de dar stage (`git add`) ou unstage em linhas específicas ou blocos (hunks) sob o cursor através de atalhos rápidos.
   - O editor não deve travar; todas as chamadas do git devem ser assíncronas.

3. **Resolução de Merges sem Dor:**
   - Detectar automaticamente marcadores de conflito do Git (`<<<<<<<`, `=======`, `>>>>>>>`).
   - Injetar botões virtuais (Virtual Lines) acima do bloco de conflito com ações rápidas: `[ Aceitar Atual ] | [ Aceitar Recebido ] | [ Aceitar Ambos ]`.
   - Ao acionar a escolha, limpar automaticamente as marcações do Git e o código descartado.

---

## 🏗️ Engenharia e Arquitetura Técnica

Para alcançar a visão delineada, a forja técnica utilizará os seguintes recursos nativos da API do Neovim em Lua:

### 1. Motor de Renderização (Extmarks)
O Neovim possui a API `nvim_buf_set_extmark`. Esta é a espinha dorsal do projeto.
- **`virt_lines`**: Utilizado para injetar texto na tela que não existe no buffer real. Isso será usado tanto para desenhar as linhas antigas (removidas) em vermelho (Inline Diff) quanto para desenhar as interfaces de botões flutuantes durante merges.
- **`hl_group` (Highlights)**: Usaremos grupos de highlight nativos (ex: `DiffAdd`, `DiffDelete`) atrelados às extmarks para pintar o fundo das linhas sem alterar a sintaxe (treesitter) das palavras.

### 2. Comunicação com o Git (Assíncrona)
- Para manter o Neovim rodando a 60fps sem engasgos, usaremos **`vim.system()`** (substituto moderno do antigo `jobstart`).
- Chamaremos `git diff --no-ext-diff -U0` para obter o diff cru e fazer o parse manual do resultado, mapeando os blocos (hunks) linha a linha para renderização imediata.
- Para realizar o stage cirúrgico, o plugin usará **`git apply --cached`** com patches gerados dinamicamente em Lua.

### 3. Automação e Eventos
- Usaremos **Autocmds** (`vim.api.nvim_create_autocmd`) atrelados a eventos como `BufWritePost` (salvar arquivo), `BufEnter` ou `FocusGained` para engatilhar um redraw assíncrono do diff na tela sempre que o arquivo for modificado.
- A resolução de merges utilizará `vim.fn.search()` para escanear os buffers em busca dos marcadores de conflito assim que eles forem abertos.

## 🚀 Próximos Passos (Roadmap de Execução)
- [x] Inicializar estrutura base do plugin e carregar no `lazy.nvim`.
- [x] Construir o módulo de parser assíncrono do `git diff`.
- [x] Renderizar linhas adicionadas e deletadas usando namespace de extmarks.
- [x] Criar a interface tátil para *Stage* e *Unstage*.
- [ ] Criar o detector e os botões virtuais de resolução de conflitos de merge.
