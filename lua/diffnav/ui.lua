local M = {}

function M.create_float_win(title, width_ratio, height_ratio)
    width_ratio = width_ratio or 0.6
    height_ratio = height_ratio or 0.6

    local width = math.floor(vim.o.columns * width_ratio)
    local height = math.floor(vim.o.lines * height_ratio)

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