local M = {}
local ui = require("diffnav.ui")
local git = require("diffnav.git")
local render = require("diffnav.render")
local stage = require("diffnav.stage")

local state = {
    current_hunks = {},
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
        M.open_picker() -- Reabre o Telescope picker
    end

    vim.keymap.set('n', 'q', close_view, opts)
    vim.keymap.set('n', '<Esc>', close_view, opts)

    vim.keymap.set('n', 's', function()
        stage.stage_hunk_at_cursor()
        vim.defer_fn(refresh_diff, 150)
    end, opts)
    vim.keymap.set('n', 'u', function()
        stage.unstage_hunk_at_cursor()
        vim.defer_fn(refresh_diff, 150)
    end, opts)

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

    vim.keymap.set('n', 'v', function()
        vim.system({ "git", "show", ":" .. filepath }, { text = true }, function(obj)
            vim.schedule(function()
                if obj.code ~= 0 then
                    print("Diffnav: Nenhuma versão no stage encontrada para este arquivo.")
                    return
                end
                
                local lines = vim.split(obj.stdout, "\n")
                local view_buf, view_win = ui.create_float_win(" Versão Staged de " .. filepath .. " ", 0.8, 0.8)
                
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
    -- Tenta carregar o Telescope
    local has_telescope, telescope = pcall(require, "telescope.pickers")
    if not has_telescope then
        print("Diffnav: O Telescope não está instalado. Este picker depende dele.")
        return
    end
    local finders = require("telescope.finders")
    local conf = require("telescope.config").values
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")

    fetch_files(function(files)
        if #files == 0 then
            print("Diffnav: Não há arquivos alterados.")
            return
        end

        local display_items = {}
        for _, f in ipairs(files) do
            table.insert(display_items, string.format("[%s] %s", f.status, f.filepath))
        end

        telescope.new({}, {
            prompt_title = "Diffnav - Arquivos Alterados (Ctrl+S: Stage | Ctrl+U: Unstage)",
            finder = finders.new_table({
                results = display_items,
            }),
            sorter = conf.generic_sorter({}),
            previewer = conf.file_previewer({}),
            attach_mappings = function(prompt_bufnr, map)
                
                -- Ação padrão: Enter abre a nossa View de Edição Customizada
                actions.select_default:replace(function()
                    local selection = action_state.get_selected_entry()
                    actions.close(prompt_bufnr)
                    if selection then
                        -- Extrai o filepath removendo a tag "[xx] " da frente
                        local filepath = selection.value:match("%[%s*.-%s*%]%s+(.+)")
                        if filepath then
                            M.open_diff_view(filepath)
                        end
                    end
                end)

                -- Ação customizada: Ctrl+S para dar Stage no arquivo inteiro direto do Telescope
                map('i', '<C-s>', function()
                    local selection = action_state.get_selected_entry()
                    if selection then
                        local filepath = selection.value:match("%[%s*.-%s*%]%s+(.+)")
                        vim.system({ "git", "add", filepath }, { text = true }, function()
                            vim.schedule(function() print("Diffnav: " .. filepath .. " adicionado ao stage.") end)
                        end)
                    end
                end)

                -- Ação customizada: Ctrl+U para remover Stage (Unstage) direto do Telescope
                map('i', '<C-u>', function()
                    local selection = action_state.get_selected_entry()
                    if selection then
                        local filepath = selection.value:match("%[%s*.-%s*%]%s+(.+)")
                        vim.system({ "git", "restore", "--staged", filepath }, { text = true }, function()
                            vim.schedule(function() print("Diffnav: " .. filepath .. " removido do stage.") end)
                        end)
                    end
                end)

                return true
            end,
        }):find()
    end)
end

return M