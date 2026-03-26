local M = {}
local git = require("diffnav.git")

local function find_hunk_by_line(hunks, current_line)
    for _, hunk in ipairs(hunks) do
        local start_line = hunk.new_start
        local end_line = hunk.new_start + math.max(hunk.new_count - 1, 0)
        
        if hunk.new_count == 0 then
            if current_line == start_line or current_line == start_line + 1 then
                return hunk
            end
        else
            if current_line >= start_line and current_line <= end_line then
                return hunk
            end
        end
    end
    return nil
end

local function apply_hunk(hunk, reverse)
    local patch = {}
    table.insert(patch, hunk.header_minus)
    table.insert(patch, hunk.header_plus)
    
    local header = string.format("@@ -%d", hunk.old_start)
    if hunk.old_count ~= 1 then header = header .. "," .. hunk.old_count end
    header = header .. string.format(" +%d", hunk.new_start)
    if hunk.new_count ~= 1 then header = header .. "," .. hunk.new_count end
    header = header .. " @@"
    
    table.insert(patch, header)

    for _, line in ipairs(hunk.deleted_lines) do table.insert(patch, "-" .. line) end
    for _, line in ipairs(hunk.added_lines) do table.insert(patch, "+" .. line) end
    table.insert(patch, "")

    local patch_content = table.concat(patch, "\n")

    vim.system({"git", "rev-parse", "--show-toplevel"}, { text = true }, function(out)
        local git_root = (out.stdout or ""):gsub("\n", "")
        if git_root == "" then git_root = vim.fn.getcwd() end

        local cmd = {"git", "apply", "--cached", "--unidiff-zero", "-"}
        if reverse then table.insert(cmd, 4, "--reverse") end

        vim.system(cmd, {
            cwd = git_root,
            stdin = patch_content,
            text = true
        }, function(obj)
            vim.schedule(function()
                if obj.code ~= 0 then
                    print("Diffnav: Falha ao " .. (reverse and "remover do" or "adicionar ao") .. " stage: " .. (obj.stderr or ""))
                else
                    print("Diffnav: Hunk " .. (reverse and "removido do" or "adicionado ao") .. " stage!")
                    require("diffnav").show_diff()
                end
            end)
        end)
    end)
end

function M.stage_hunk_at_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then return end

    local current_line = vim.api.nvim_win_get_cursor(0)[1]

    git.get_diff(filepath, false, function(hunks)
        if not hunks or #hunks == 0 then return end
        local hunk = find_hunk_by_line(hunks, current_line)
        if not hunk then
            print("Diffnav: Nenhum hunk encontrado na linha " .. current_line)
            return
        end
        apply_hunk(hunk, false)
    end)
end

function M.unstage_hunk_at_cursor()
    local bufnr = vim.api.nvim_get_current_buf()
    local filepath = vim.api.nvim_buf_get_name(bufnr)
    if filepath == "" then return end

    local current_line = vim.api.nvim_win_get_cursor(0)[1]

    git.get_diff(filepath, true, function(hunks)
        if not hunks or #hunks == 0 then return end
        local hunk = find_hunk_by_line(hunks, current_line)
        if not hunk then
            print("Diffnav: Nenhum hunk em stage encontrado na linha " .. current_line)
            return
        end
        apply_hunk(hunk, true)
    end)
end

return M