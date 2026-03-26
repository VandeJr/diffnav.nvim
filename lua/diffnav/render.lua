local M = {}

local ns_id = vim.api.nvim_create_namespace("diffnav")

-- Define highlights baseados nos padrões do Neovim.
-- "DiffDelete" e "DiffAdd" são nativos de qualquer colorscheme.
vim.api.nvim_set_hl(0, "DiffnavDelete", { link = "DiffDelete", default = true })
vim.api.nvim_set_hl(0, "DiffnavAdd", { link = "DiffAdd", default = true })

-- Limpa todas as marcas e linhas virtuais do buffer atual
function M.clear(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

-- Renderiza o diff no buffer injetando linhas virtuais para remoções
-- e colorindo o fundo das linhas adicionadas.
function M.draw(bufnr, hunks)
    M.clear(bufnr)

    for _, hunk in ipairs(hunks) do
        -- 1. Renderiza linhas deletadas usando virt_lines
        if #hunk.deleted_lines > 0 then
            local vlines = {}
            for _, line in ipairs(hunk.deleted_lines) do
                -- Adicionamos um "-" na frente como indicativo visual, colorido como vermelho.
                table.insert(vlines, { { "- " .. line, "DiffnavDelete" } })
            end

            local target_line
            local virt_lines_above
            
            if hunk.new_count == 0 then
                -- É uma deleção pura. O 'new_start' aponta para a linha ANTERIOR à deleção.
                target_line = hunk.new_start - 1
                virt_lines_above = false
                
                -- Tratamento de borda para o topo do arquivo
                if target_line < 0 then
                    target_line = 0
                    virt_lines_above = true
                end
            else
                -- É uma substituição (change) ou adição pura com contexto. 
                -- Queremos colocar as linhas deletadas logo ACIMA do novo bloco de código.
                target_line = hunk.new_start - 1
                virt_lines_above = true
            end
            
            -- Garantir que não estoure o limite de linhas do buffer
            local line_count = vim.api.nvim_buf_line_count(bufnr)
            target_line = math.max(0, math.min(target_line, line_count - 1))

            vim.api.nvim_buf_set_extmark(bufnr, ns_id, target_line, 0, {
                virt_lines = vlines,
                virt_lines_above = virt_lines_above,
            })
        end

        -- 2. Renderiza highlight de fundo para as linhas adicionadas
        if #hunk.added_lines > 0 then
            local start_row = hunk.new_start - 1
            local end_row = start_row + hunk.new_count

            for i = start_row, end_row - 1 do
                if i >= 0 and i < vim.api.nvim_buf_line_count(bufnr) then
                    vim.api.nvim_buf_set_extmark(bufnr, ns_id, i, 0, {
                        line_hl_group = "DiffnavAdd",
                        hl_mode = "combine", -- Combina a cor verde com a sintaxe do treesitter
                    })
                end
            end
        end
    end
end

return M