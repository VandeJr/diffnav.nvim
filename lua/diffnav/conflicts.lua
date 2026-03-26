local M = {}
local ui = require("diffnav.ui")

local function get_conflict_files(callback)
    vim.system({"git", "diff", "--name-only", "--diff-filter=U"}, { text = true }, function(obj)
        if obj.code ~= 0 then
            vim.schedule(function() callback({}) end)
            return
        end

        local files = vim.split(obj.stdout or "", "\n", { trimempty = true })
        vim.schedule(function() callback(files) end)
    end)
end

function M.open_file(bufnr, winnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_idx = cursor[1] - 1
    local line_text = vim.api.nvim_buf_get_lines(bufnr, line_idx, line_idx + 1, false)[1]

    if not line_text or line_text == "" or line_text:match("^%-%-%-") or line_text:match("^%[") then
        return
    end

    local file = line_text:gsub("^%s+", "")

    -- Fecha a janela flutuante
    vim.api.nvim_win_close(winnr, true)
    
    -- Abre o arquivo no buffer original
    vim.cmd("edit " .. file)
    print("Diffnav: Resolva os conflitos de " .. file)
end

function M.show_conflicts()
    get_conflict_files(function(files)
        local lines = {}
        
        table.insert(lines, "--- CONFLITOS DE MERGE PENDENTES ---")
        if #files == 0 then
            table.insert(lines, "  (Nenhum conflito encontrado)")
        else
            for _, file in ipairs(files) do
                table.insert(lines, "  " .. file)
            end
        end
        table.insert(lines, "")
        table.insert(lines, "[Pressione <Enter> sobre um arquivo para abri-lo e resolver]")

        local bufnr, winnr = ui.create_float_win(" Conflitos (Diffview) ")
        
        vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

        vim.keymap.set('n', '<CR>', function() M.open_file(bufnr, winnr) end, { buffer = bufnr, silent = true })
    end)
end

return M