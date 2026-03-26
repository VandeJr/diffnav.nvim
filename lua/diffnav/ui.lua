local M = {}

function M.create_float_win(title)
    local width = math.floor(vim.o.columns * 0.6)
    local height = math.floor(vim.o.lines * 0.6)

    local row = math.floor((vim.o.lines - height) / 2)
    local col = math.floor((vim.o.columns - width) / 2)

    local bufnr = vim.api.nvim_create_buf(false, true)

    local win_opts = {
        relative = "editor",
        row = row,
        col = col,
        width = width,
        height = height,
        style = "minimal",
        border = "rounded",
        title = title,
        title_pos = "center",
    }

    local winnr = vim.api.nvim_open_win(bufnr, true, win_opts)

    -- Define algumas opções pro buffer
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
    vim.api.nvim_set_option_value("cursorline", true, { win = winnr })

    -- Atalho padrão para fechar a janela
    vim.keymap.set('n', 'q', '<Cmd>q<CR>', { buffer = bufnr, silent = true })
    vim.keymap.set('n', '<Esc>', '<Cmd>q<CR>', { buffer = bufnr, silent = true })

    return bufnr, winnr
end

return M