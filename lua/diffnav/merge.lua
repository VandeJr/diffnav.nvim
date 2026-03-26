local M = {}

local ns_id = vim.api.nvim_create_namespace("diffnav_merge")

function M.clear(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
end

function M.detect_and_draw(bufnr)
    M.clear(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

    for i, line in ipairs(lines) do
        if line:match("^<<<<<<< ") then
            -- Injeta texto virtual flutuante acima do marcador de conflito
            vim.api.nvim_buf_set_extmark(bufnr, ns_id, i - 1, 0, {
                virt_lines = {
                    {
                        { " ⚡ CONFLITO DE MERGE ", "WarningMsg" },
                        { " | ", "Comment" },
                        { "Ações Rápidas: ", "Comment" },
                        { ":DiffnavMergeCurrent", "String" },
                        { " | ", "Comment" },
                        { ":DiffnavMergeIncoming", "String" },
                        { " | ", "Comment" },
                        { ":DiffnavMergeBoth", "String" },
                    }
                },
                virt_lines_above = true,
            })
        end
    end
end

-- Obtém os limites (linhas) do conflito onde o cursor se encontra
local function get_conflict_bounds(bufnr, current_line)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local start_idx = nil
    local mid_idx = nil
    local end_idx = nil

    -- Procura para cima o marcador de início
    for i = current_line, 1, -1 do
        if lines[i]:match("^<<<<<<< ") then
            start_idx = i
            break
        end
        if lines[i]:match("^=======") or lines[i]:match("^>>>>>>> ") then
            -- Pode ser que já tenha passado, a lógica aceita se continuarmos dentro do mesmo bloco
        end
    end

    if not start_idx then return nil end

    -- Procura para baixo os divisores e o fim
    for i = start_idx, #lines do
        if lines[i]:match("^=======") then
            mid_idx = i
        elseif lines[i]:match("^>>>>>>> ") then
            end_idx = i
            break
        end
    end

    if start_idx and mid_idx and end_idx and current_line <= end_idx then
        return { start_idx = start_idx, mid_idx = mid_idx, end_idx = end_idx }
    end

    return nil
end

function M.resolve_current()
    local bufnr = vim.api.nvim_get_current_buf()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local bounds = get_conflict_bounds(bufnr, current_line)
    
    if not bounds then
        print("Diffnav: Cursor não está dentro de um bloco de conflito.")
        return
    end

    -- Aceita Atual: Apaga a parte inferior primeiro (do divisor até o fim)
    vim.api.nvim_buf_set_lines(bufnr, bounds.mid_idx - 1, bounds.end_idx, false, {})
    -- Apaga a marcação superior (<<<<<<<)
    vim.api.nvim_buf_set_lines(bufnr, bounds.start_idx - 1, bounds.start_idx, false, {})
    
    M.detect_and_draw(bufnr)
    print("Diffnav: Conflito resolvido! (Atual aceito)")
end

function M.resolve_incoming()
    local bufnr = vim.api.nvim_get_current_buf()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local bounds = get_conflict_bounds(bufnr, current_line)
    
    if not bounds then
        print("Diffnav: Cursor não está dentro de um bloco de conflito.")
        return
    end

    -- Aceita Recebido: Apaga do final (>>>>>>>)
    vim.api.nvim_buf_set_lines(bufnr, bounds.end_idx - 1, bounds.end_idx, false, {})
    -- Apaga do topo até o divisor médio (<<<<<<< até =======)
    vim.api.nvim_buf_set_lines(bufnr, bounds.start_idx - 1, bounds.mid_idx, false, {})
    
    M.detect_and_draw(bufnr)
    print("Diffnav: Conflito resolvido! (Recebido aceito)")
end

function M.resolve_both()
    local bufnr = vim.api.nvim_get_current_buf()
    local current_line = vim.api.nvim_win_get_cursor(0)[1]
    local bounds = get_conflict_bounds(bufnr, current_line)
    
    if not bounds then
        print("Diffnav: Cursor não está dentro de um bloco de conflito.")
        return
    end

    -- Aceita Ambos: Apaga os 3 marcadores (Fim, Meio, Início) na ordem inversa
    vim.api.nvim_buf_set_lines(bufnr, bounds.end_idx - 1, bounds.end_idx, false, {})
    vim.api.nvim_buf_set_lines(bufnr, bounds.mid_idx - 1, bounds.mid_idx, false, {})
    vim.api.nvim_buf_set_lines(bufnr, bounds.start_idx - 1, bounds.start_idx, false, {})
    
    M.detect_and_draw(bufnr)
    print("Diffnav: Conflito resolvido! (Ambos aceitos)")
end

return M