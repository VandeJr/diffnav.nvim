local M = {}
local ui = require("diffnav.ui")

local function get_git_status(callback)
    vim.system({"git", "status", "--porcelain"}, { text = true }, function(obj)
        if obj.code ~= 0 then
            vim.schedule(function() callback({}, {}) end)
            return
        end

        local staged = {}
        local unstaged = {}

        local lines = vim.split(obj.stdout or "", "\n", { trimempty = true })
        for _, line in ipairs(lines) do
            local x = line:sub(1, 1)
            local y = line:sub(2, 2)
            local file = line:sub(4)

            -- Verifica o índice do stage (X)
            if x ~= " " and x ~= "?" then
                table.insert(staged, { status = x, file = file })
            end
            
            -- Verifica o índice da working tree (Y) e Untracked (??)
            if y ~= " " or x == "?" then
                table.insert(unstaged, { status = (x == "?" and "?" or y), file = file })
            end
        end

        vim.schedule(function()
            callback(staged, unstaged)
        end)
    end)
end

function M.toggle_stage(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_idx = cursor[1] - 1
    local line_text = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]

    if not line_text or line_text == "" or line_text:match("^%-%-%-") then
        return
    end

    local file = line_text:sub(4)
    local is_unstaged_section = false

    -- Descobre em qual seção estamos baseado nas linhas acima
    for i = line_idx, 0, -1 do
        local l = vim.api.nvim_buf_get_lines(bufnr, i, i + 1, false)[1]
        if l == "--- UNSTAGED ---" then
            is_unstaged_section = true
            break
        elseif l == "--- STAGED ---" then
            is_unstaged_section = false
            break
        end
    end

    local cmd
    if is_unstaged_section then
        cmd = { "git", "add", file }
    else
        cmd = { "git", "restore", "--staged", file }
    end

    vim.system(cmd, { text = true }, function(obj)
        vim.schedule(function()
            if obj.code == 0 then
                M.show_status(bufnr) -- Atualiza a janela
            else
                print("Diffnav: Erro ao alterar status do arquivo.")
            end
        end)
    end)
end

function M.show_status(existing_bufnr)
    get_git_status(function(staged, unstaged)
        local lines = {}
        
        table.insert(lines, "--- STAGED ---")
        if #staged == 0 then
            table.insert(lines, "  (nenhum arquivo)")
        else
            for _, item in ipairs(staged) do
                table.insert(lines, " " .. item.status .. " " .. item.file)
            end
        end

        table.insert(lines, "")
        table.insert(lines, "--- UNSTAGED ---")
        if #unstaged == 0 then
            table.insert(lines, "  (nenhum arquivo)")
        else
            for _, item in ipairs(unstaged) do
                table.insert(lines, " " .. item.status .. " " .. item.file)
            end
        end
        table.insert(lines, "")
        table.insert(lines, "[Pressione <Enter> para alternar Stage/Unstage no arquivo]")

        local bufnr = existing_bufnr
        if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
            bufnr, _ = ui.create_float_win(" Git Status (Diffview) ")
            vim.keymap.set('n', '<CR>', function() M.toggle_stage(bufnr) end, { buffer = bufnr, silent = true })
        end

        vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })
    end)
end

return M