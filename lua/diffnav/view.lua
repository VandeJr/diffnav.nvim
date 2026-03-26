local M = {}

-- Cria uma aba com a estrutura visual do Diffnav (Sidebar + Split de Diff)
function M.open_diff_view()
    -- 1. Abre uma nova Tab (aba inteira para focar na tarefa)
    vim.cmd("tabnew")
    
    -- Configura buffer e janela para a árvore lateral (Sidebar)
    vim.cmd("vsplit")
    vim.cmd("vertical resize 30") -- Largura da sidebar
    
    local win_sidebar = vim.api.nvim_get_current_win()
    local buf_sidebar = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(win_sidebar, buf_sidebar)
    
    vim.api.nvim_set_option_value("filetype", "diffnav_tree", { buf = buf_sidebar })
    vim.api.nvim_set_option_value("modifiable", false, { buf = buf_sidebar })
    vim.api.nvim_set_option_value("number", false, { win = win_sidebar })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win_sidebar })
    
    -- 2. Pula para a janela principal da direita (onde ficará o Diff)
    vim.cmd("wincmd l")
    local win_main = vim.api.nvim_get_current_win()
    
    -- Vamos dividir a janela principal em duas (Vertical Split)
    -- Lado esquerdo: Versão anterior (Head/Index)
    -- Lado direito: Versão atual do working directory
    vim.cmd("vsplit")
    
    local win_old = vim.api.nvim_get_current_win()
    vim.cmd("wincmd l")
    local win_new = vim.api.nvim_get_current_win()

    -- 3. Retorna os IDs para que outro módulo preencha com o `git diff`
    return {
        tabpage = vim.api.nvim_get_current_tabpage(),
        buf_sidebar = buf_sidebar,
        win_sidebar = win_sidebar,
        win_old = win_old,
        win_new = win_new,
    }
end

return M