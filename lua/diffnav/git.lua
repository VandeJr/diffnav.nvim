local M = {}

-- Função para parsear a saída do comando `git diff -U0`
-- Ela identifica os hunks de deleção e adição para o buffer específico.
local function parse_diff(diff_output)
    local hunks = {}
    local lines = vim.split(diff_output, "\n", { trimempty = true })

    local current_hunk = nil

    for _, line in ipairs(lines) do
        -- Ignora as linhas de cabeçalho do diff até chegar no @@
        if line:match("^@@") then
            -- Exemplo de formato de hunk: @@ -old_line,old_count +new_line,new_count @@
            local old_line, old_count, new_line, new_count = line:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
            
            if old_line and new_line then
                current_hunk = {
                    old_start = tonumber(old_line),
                    old_count = old_count == "" and 1 or tonumber(old_count),
                    new_start = tonumber(new_line),
                    new_count = new_count == "" and 1 or tonumber(new_count),
                    added_lines = {},
                    deleted_lines = {}
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

-- Chama o git de forma assíncrona usando a nova API do Neovim (vim.system)
function M.get_diff(filepath, callback)
    if not filepath or filepath == "" then
        return
    end

    -- Usamos -U0 (zero linhas de contexto) pois só nos interessa o que mudou,
    -- e não o contexto ao redor, facilitando a identificação exata para injetar virt_lines.
    local cmd = { "git", "diff", "--no-ext-diff", "-U0", "--", filepath }

    vim.system(cmd, { text = true }, function(obj)
        if obj.code ~= 0 then
            -- Falha na chamada do git (pode não ser um repositório git, arquivo não rastreado, etc.)
            -- Passamos nil ou vazio para o callback lidar com a limpeza se necessário.
            vim.schedule(function()
                callback({})
            end)
            return
        end

        local hunks = parse_diff(obj.stdout)

        -- Como vim.system roda fora da thread principal do Neovim,
        -- precisamos agendar (schedule) a execução do callback para que a renderização (UI)
        -- aconteça em segurança dentro da main loop do Neovim.
        vim.schedule(function()
            callback(hunks)
        end)
    end)
end

return M