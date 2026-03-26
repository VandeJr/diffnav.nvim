local M = {}

-- Configurações padrão do plugin
local default_config = {
    -- Aqui colocaremos configurações como atalhos, cores, etc.
}

-- Função de setup para o lazy.nvim
function M.setup(user_config)
    M.config = vim.tbl_deep_extend("force", default_config, user_config or {})
end

-- Função principal provisória
function M.show_diff()
    -- No futuro, aqui leremos o `git diff` e renderizaremos as extmarks.
    print("Camarada, o módulo Diffnav foi acionado! Em breve: Diffs visuais aqui.")
end

return M