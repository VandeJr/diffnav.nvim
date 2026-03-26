local M = {}
local git = require("diffnav.git")
local render = require("diffnav.render")

-- Configurações padrão do plugin
local default_config = {
    -- Aqui colocaremos configurações como atalhos, cores, etc.
}

M.is_active = false
local augroup_id = vim.api.nvim_create_augroup("DiffnavGroup", { clear = true })

-- Função de setup para o lazy.nvim
function M.setup(user_config)
    M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
    
    -- Autocmd para atualizar automaticamente as marcações caso o plugin esteja ativo
    vim.api.nvim_create_autocmd({"BufWritePost", "BufEnter"}, {
        group = augroup_id,
        pattern = "*",
        callback = function()
            if M.is_active then
                M.show_diff()
            end
        end,
    })
end

-- Limpa as marcações do buffer atual
function M.clear_diff()
    local bufnr = vim.api.nvim_get_current_buf()
    render.clear(bufnr)
end

-- Extrai do git e renderiza as marcas
function M.show_diff()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    
    if filepath == "" then
        print("Diffnav: O buffer atual não tem um arquivo associado.")
        return
    end

    git.get_diff(filepath, function(hunks)
        if not hunks or #hunks == 0 then
            render.clear(bufnr)
            print("Diffnav: Nenhuma alteração detectada no git ou arquivo não rastreado.")
            return
        end

        render.draw(bufnr, hunks)
    end)
end

-- Função que atua como interruptor liga/desliga
function M.toggle_diff()
    M.is_active = not M.is_active
    
    if M.is_active then
        M.show_diff()
        print("Diffnav: ON")
    else
        M.clear_diff()
        print("Diffnav: OFF")
    end
end

return M