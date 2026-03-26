local M = {}
local view = require("diffnav.view")

-- Módulo responsável por popular a aba de visão geral estilo "Diffnav/Diffview"

local state = {
    current_tab = nil,
    files = {},         -- Lista de arquivos alterados (com status)
    active_file = nil,  -- Arquivo atualmente selecionado
    wins = nil,         -- Tabela contendo win_sidebar, win_old, win_new
}

-- Busca todos os arquivos alterados (Staged e Unstaged)
local function fetch_changed_files(callback)
    vim.system({"git", "status", "--porcelain"}, { text = true }, function(obj)
        if obj.code ~= 0 then
            vim.schedule(function() callback({}) end)
            return
        end

        local files = {}
        local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })
        for _, line in ipairs(lines) do
            local x = line:sub(1, 1) -- Staged status
            local y = line:sub(2, 2) -- Unstaged status
            local filepath = line:sub(4)
            table.insert(files, { filepath = filepath, x = x, y = y })
        end

        vim.schedule(function() callback(files) end)
    end)
end

-- Renderiza a sidebar lateral
local function render_sidebar()
    if not state.wins or not vim.api.nvim_buf_is_valid(state.wins.buf_sidebar) then return end
    
    local lines = { " DIFFNAV ", "===========", "" }
    for i, f in ipairs(state.files) do
        local prefix = (f.x ~= " " and f.x ~= "?" and "[S] " or "[U] ")
        local marker = (f.filepath == state.active_file) and "> " or "  "
        table.insert(lines, marker .. prefix .. f.filepath)
    end

    vim.api.nvim_set_option_value("modifiable", true, { buf = state.wins.buf_sidebar })
    vim.api.nvim_buf_set_lines(state.wins.buf_sidebar, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.wins.buf_sidebar })
end

-- Abre o diff (lado a lado) do arquivo selecionado na janela principal
local function open_file_diff(filepath)
    if not state.wins then return end
    
    -- Painel da Direita (Working Tree)
    vim.api.nvim_set_current_win(state.wins.win_new)
    vim.cmd("edit " .. filepath)
    
    -- Painel da Esquerda (Head/Index)
    vim.api.nvim_set_current_win(state.wins.win_old)
    -- Para ver a versão de como era, pegamos o arquivo do HEAD
    -- Se o arquivo não existir no head (novo), abrimos um buffer vazio
    vim.cmd("enew")
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = 0 })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = 0 })
    
    -- Executa git show HEAD:filepath
    vim.system({"git", "show", "HEAD:" .. filepath}, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                local content = vim.split(obj.stdout, "\n")
                vim.api.nvim_buf_set_lines(0, 0, -1, false, content)
            else
                vim.api.nvim_buf_set_lines(0, 0, -1, false, {"(Arquivo novo)"})
            end
            
            -- Ativa o diff nativo do Neovim entre essas duas janelas
            vim.api.nvim_set_current_win(state.wins.win_old)
            vim.cmd("diffthis")
            vim.api.nvim_set_current_win(state.wins.win_new)
            vim.cmd("diffthis")
        end)
    end)
end

-- Atalho ativado quando o usuário clica Enter na sidebar
function M.select_file()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_idx = cursor[1] - 4 -- 3 linhas de header

    if line_idx >= 0 and line_idx < #state.files then
        state.active_file = state.files[line_idx + 1].filepath
        render_sidebar()
        open_file_diff(state.active_file)
    end
end

-- Função principal para inicializar a tela completa
function M.open_panel()
    fetch_changed_files(function(files)
        if #files == 0 then
            print("Diffnav: Repositório limpo, não há alterações.")
            return
        end

        state.files = files
        state.active_file = files[1].filepath
        state.wins = view.open_diff_view()

        -- Keymaps para a Sidebar
        vim.keymap.set("n", "<CR>", M.select_file, { buffer = state.wins.buf_sidebar, silent = true })

        render_sidebar()
        open_file_diff(state.active_file)
    end)
end

return M