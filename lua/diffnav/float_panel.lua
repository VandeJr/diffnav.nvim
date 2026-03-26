local M = {}
local ui = require("diffnav.ui")
local git = require("diffnav.git")
local render = require("diffnav.render")
local stage = require("diffnav.stage")

local state = {
    files = {},
    filtered_files = {},
    picker_buf = nil,
    picker_win = nil,
    diff_win = nil,
    current_hunks = {},
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

local function draw_picker()
    if not state.picker_buf or not vim.api.nvim_buf_is_valid(state.picker_buf) then return end
    
    local lines = {
        " 🔍 SELECIONE O ARQUIVO PARA VER AS DIFERENÇAS ",
        " [Enter] Abrir | [s] Stage Arquivo | [u] Unstage Arquivo | [/] Buscar",
        "================================================================",
        ""
    }
    
    for _, f in ipairs(state.filtered_files) do
        table.insert(lines, " [" .. f.status .. "] " .. f.filepath)
    end

    vim.api.nvim_set_option_value("modifiable", true, { buf = state.picker_buf })
    vim.api.nvim_buf_set_lines(state.picker_buf, 0, -1, false, lines)
    vim.api.nvim_set_option_value("modifiable", false, { buf = state.picker_buf })
end

local function apply_file_action(action, filepath)
    local cmd = action == "stage" and { "git", "add", filepath } or { "git", "restore", "--staged", filepath }
    vim.system(cmd, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                fetch_files(function(files)
                    state.files = files
                    state.filtered_files = files -- Reseta o filtro ao agir para manter a consistência
                    draw_picker()
                end)
            end
        end)
    end)
end

function M.open_diff_view(filepath)
    local bufnr = vim.fn.bufadd(filepath)
    vim.fn.bufload(bufnr)

    local width = math.floor(vim.o.columns * 0.9)
    local height = math.floor(vim.o.lines * 0.9)
    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    state.diff_win = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor", row = row, col = col, width = width, height = height,
        style = "minimal", border = "rounded", title_pos = "center",
        title = " " .. filepath .. " | [s] stage hunk | [u] unstage hunk | [S] stage todo | [U] unstage todo | [v] ver final | [c/c] nav | [q] voltar "
    })

    vim.api.nvim_set_option_value("number", true, { win = state.diff_win })
    vim.api.nvim_set_option_value("cursorline", true, { win = state.diff_win })

    local function refresh_diff()
        git.get_diff(filepath, false, function(hunks)
            render.clear(bufnr)
            state.current_hunks = hunks or {}
            if #state.current_hunks > 0 then
                render.draw(bufnr, state.current_hunks)
            end
        end)
    end

    refresh_diff()

    local opts = { buffer = bufnr, silent = true }
    
    local function close_view()
        render.clear(bufnr)
        vim.api.nvim_win_close(state.diff_win, true)
        M.open_picker()
    end

    vim.keymap.set('n', 'q', close_view, opts)
    vim.keymap.set('n', '<Esc>', close_view, opts)

    -- Hunk actions
    vim.keymap.set('n', 's', function()
        stage.stage_hunk_at_cursor()
        vim.defer_fn(refresh_diff, 150)
    end, opts)
    vim.keymap.set('n', 'u', function()
        stage.unstage_hunk_at_cursor()
        vim.defer_fn(refresh_diff, 150)
    end, opts)

    -- File actions
    vim.keymap.set('n', 'S', function()
        vim.system({ "git", "add", filepath }, { text = true }, function()
            vim.schedule(refresh_diff)
        end)
    end, opts)
    vim.keymap.set('n', 'U', function()
        vim.system({ "git", "restore", "--staged", filepath }, { text = true }, function()
            vim.schedule(refresh_diff)
        end)
    end, opts)

    -- Navigate chunks
    vim.keymap.set('n', ']c', function()
        if not state.current_hunks then return end
        local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
        for _, hunk in ipairs(state.current_hunks) do
            local start_line = math.max(1, hunk.new_start)
            if start_line > cursor_line then
                vim.api.nvim_win_set_cursor(0, {start_line, 0})
                return
            end
        end
    end, opts)

    vim.keymap.set('n', '[c', function()
        if not state.current_hunks then return end
        local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
        for i = #state.current_hunks, 1, -1 do
            local hunk = state.current_hunks[i]
            local start_line = math.max(1, hunk.new_start)
            if start_line < cursor_line then
                vim.api.nvim_win_set_cursor(0, {start_line, 0})
                return
            end
        end
    end, opts)

    -- View staged version
    vim.keymap.set('n', 'v', function()
        vim.system({ "git", "show", ":" .. filepath }, { text = true }, function(obj)
            vim.schedule(function()
                if obj.code ~= 0 then
                    print("Diffnav: Nenhuma versão no stage encontrada para este arquivo.")
                    return
                end
                
                local lines = vim.split(obj.stdout, "\n")
                local view_buf, view_win = ui.create_float_win(" Versão Staged de " .. filepath .. " ", 0.8, 0.8)
                
                -- Copia filetype do buffer original
                local ft = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
                vim.api.nvim_set_option_value("filetype", ft, { buf = view_buf })
                
                vim.api.nvim_set_option_value("modifiable", true, { buf = view_buf })
                vim.api.nvim_buf_set_lines(view_buf, 0, -1, false, lines)
                vim.api.nvim_set_option_value("modifiable", false, { buf = view_buf })
            end)
        end)
    end, opts)
end

function M.open_picker()
    fetch_files(function(files)
        if #files == 0 then
            print("Diffnav: Não há arquivos alterados.")
            return
        end
        state.files = files
        state.filtered_files = files

        if not state.picker_buf or not vim.api.nvim_buf_is_valid(state.picker_buf) then
            state.picker_buf, state.picker_win = ui.create_float_win(" Arquivos Alterados ", 0.7, 0.6)
            vim.api.nvim_set_option_value("filetype", "diffnav_picker", { buf = state.picker_buf })
        end

        draw_picker()
        
        local opts = { buffer = state.picker_buf, silent = true }

        -- Ação: Selecionar arquivo
        vim.keymap.set('n', '<CR>', function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local idx = cursor[1] - 4 -- 4 linhas de cabeçalho
            if idx >= 1 and idx <= #state.filtered_files then
                local filepath = state.filtered_files[idx].filepath
                vim.api.nvim_win_close(state.picker_win, true)
                M.open_diff_view(filepath)
            end
        end, opts)

        -- Ação: Buscar / Filtrar fuzzy simples
        vim.keymap.set('n', '/', function()
            vim.ui.input({ prompt = 'Buscar arquivo (digite parte do nome): ' }, function(input)
                if not input then return end
                state.filtered_files = {}
                for _, f in ipairs(state.files) do
                    -- Busca case-insensitive simples
                    if f.filepath:lower():find(input:lower(), 1, true) then
                        table.insert(state.filtered_files, f)
                    end
                end
                draw_picker()
            end)
        end, opts)

        -- Ação: Stage Arquivo Inteiro
        vim.keymap.set('n', 's', function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local idx = cursor[1] - 4
            if idx >= 1 and idx <= #state.filtered_files then
                apply_file_action("stage", state.filtered_files[idx].filepath)
            end
        end, opts)

        -- Ação: Unstage Arquivo Inteiro
        vim.keymap.set('n', 'u', function()
            local cursor = vim.api.nvim_win_get_cursor(0)
            local idx = cursor[1] - 4
            if idx >= 1 and idx <= #state.filtered_files then
                apply_file_action("unstage", state.filtered_files[idx].filepath)
            end
        end, opts)

    end)
end

return M