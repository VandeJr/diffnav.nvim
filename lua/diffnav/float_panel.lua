local M = {}
local ui = require("diffnav.ui")
local git = require("diffnav.git")
local render = require("diffnav.render")
local stage = require("diffnav.stage")

local state = {
    files = {},
    picker_buf = nil,
    picker_win = nil,
    diff_win = nil,
}

local function fetch_files(callback)
    vim.system({"git", "status", "--porcelain"}, { text = true }, function(obj)
        if obj.code ~= 0 then
            vim.schedule(function() callback({}) end)
            return
        end
        local files = {}
        for _, line in ipairs(vim.split(obj.stdout or "", "\n", { trimempty = true })) do
            local status = line:sub(1, 2)
            local filepath = line:sub(4)
            table.insert(files, { status = status, filepath = filepath })
        end
        vim.schedule(function() callback(files) end)
    end)
end

function M.open_diff_view(filepath)
    -- Carrega o buffer do arquivo real
    local bufnr = vim.fn.bufadd(filepath)
    vim.fn.bufload(bufnr)

    -- Abre uma janela flutuante maior (90% da tela) para simular o Preview do Telescope
    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.9)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    state.diff_win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor", row = row, col = col, width = width, height = height,
        style = "minimal", border = "rounded", title = " " .. filepath .. " | [s] stage hunk | [u] unstage hunk | [q] voltar ", title_pos = "center"
    })

    -- Garante que o buffer tem os atributos corretos para edição/visualização
    vim.api.nvim_set_option_value("number", true, { win = state.diff_win })
    vim.api.nvim_set_option_value("cursorline", true, { win = state.diff_win })

    -- Renderiza as linhas vermelhas/verdes inline
    git.get_diff(filepath, false, function(hunks)
        if hunks and #hunks > 0 then
            render.draw(bufnr, hunks)
        end
    end)

    -- Função para atualizar a view após stage/unstage
    local function refresh_diff()
        vim.defer_fn(function()
            git.get_diff(filepath, false, function(hunks)
                render.clear(bufnr)
                if hunks and #hunks > 0 then
                    render.draw(bufnr, hunks)
                end
            end)
        end, 150)
    end

    -- Mapeamentos locais para esta janela flutuante
    local opts = { buffer = bufnr, silent = true }
    
    vim.keymap.set('n', 'q', function()
        render.clear(bufnr)
        vim.api.nvim_win_close(state.diff_win, true)
        M.open_picker() -- Volta para o picker
    end, opts)
    
    vim.keymap.set('n', '<Esc>', function()
        render.clear(bufnr)
        vim.api.nvim_win_close(state.diff_win, true)
        M.open_picker() -- Volta para o picker
    end, opts)

    vim.keymap.set('n', 's', function()
        stage.stage_hunk_at_cursor()
        refresh_diff()
    end, opts)

    vim.keymap.set('n', 'u', function()
        stage.unstage_hunk_at_cursor()
        refresh_diff()
    end, opts)
end

function M.open_picker()
    fetch_files(function(files)
        if #files == 0 then
            print("Diffnav: Não há arquivos alterados.")
            return
        end
        state.files = files
        local lines = { " 🔍 SELECIONE O ARQUIVO PARA VER AS DIFERENÇAS (Telescope-like) ", "================================================================", "" }
        for _, f in ipairs(files) do
            table.insert(lines, " [" .. f.status .. "] " .. f.filepath)
        end

        state.picker_buf, state.picker_win = ui.create_float_win(" Arquivos Alterados ", 0.7, 0.6)
        vim.api.nvim_set_option_value("modifiable", true, { buf = state.picker_buf })
        vim.api.nvim_buf_set_lines(state.picker_buf, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = state.picker_buf })
        
        vim.api.nvim_set_option_value("filetype", "diffnav_picker", { buf = state.picker_buf })
        
        vim.keymap.set('n', '<CR>', function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local idx = cursor[1] - 3 -- descontando as linhas de cabeçalho
            if idx >= 1 and idx <= #state.files then
                local filepath = state.files[idx].filepath
                vim.api.nvim_win_close(state.picker_win, true)
                M.open_diff_view(filepath)
            end
        end, { buffer = state.picker_buf, silent = true })
    end)
end

return M