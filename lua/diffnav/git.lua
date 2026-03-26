local M = {}

-- Função para parsear a saída do comando `git diff -U0`
local function parse_diff(diff_output)
    local hunks = {}
    local lines = vim.split(diff_output, "\n", { trimempty = true })

    local current_hunk = nil
    local header_minus = "--- a/file"
    local header_plus = "+++ b/file"

    for _, line in ipairs(lines) do
        if line:match("^%-%-%- ") then
            header_minus = line
        elseif line:match("^%+%+%+ ") then
            header_plus = line
        elseif line:match("^@@") then
            local old_line, old_count, new_line, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
            
            if old_line and new_line then
                current_hunk = {
                    old_start = tonumber(old_line),
                    old_count = old_count == "" and 1 or tonumber(old_count),
                    new_start = tonumber(new_line),
                    new_count = new_count == "" and 1 or tonumber(new_count),
                    added_lines = {},
                    deleted_lines = {},
                    header_minus = header_minus,
                    header_plus = header_plus,
                }
                table.insert(hunks, current_hunk)
            end
        elseif current_hunk then
            if line:sub(1, 1) == "-" then
                table.insert(current_hunk.deleted_lines, line:sub(2))
            elseif line:sub(1, 1) == "+" then
                table.insert(current_hunk.added_lines, line:sub(2))
            end
        end
    end

    return hunks
end

-- Chama o git de forma assíncrona
function M.get_diff(filepath, cached, callback)
    if not filepath or filepath == "" then
        return
    end

    local cmd = { "git", "diff", "--no-ext-diff", "-U0" }
    if cached then
        table.insert(cmd, "--cached")
    end
    table.insert(cmd, "--")
    table.insert(cmd, filepath)

    vim.system(cmd, { text = true }, function(obj)
        if obj.code ~= 0 then
            vim.schedule(function()
                callback({})
            end)
            return
        end

        local hunks = parse_diff(obj.stdout)

        vim.schedule(function()
            callback(hunks)
        end)
    end)
end

return M