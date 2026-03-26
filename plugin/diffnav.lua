if vim.g.loaded_diffnav then
    return
end
vim.g.loaded_diffnav = true

-- Comando do editor para acionar a interface visual do Diffnav (liga/desliga)
vim.api.nvim_create_user_command("Diffnav", function()
    require("diffnav").toggle_diff()
end, {})

-- Comandos para Stage e Unstage
vim.api.nvim_create_user_command("DiffnavStage", function()
    require("diffnav.stage").stage_hunk_at_cursor()
end, {})

vim.api.nvim_create_user_command("DiffnavUnstage", function()
    require("diffnav.stage").unstage_hunk_at_cursor()
end, {})

-- Comandos para Resolução de Merges
vim.api.nvim_create_user_command("DiffnavMergeCurrent", function()
    require("diffnav.merge").resolve_current()
end, {})

vim.api.nvim_create_user_command("DiffnavMergeIncoming", function()
    require("diffnav.merge").resolve_incoming()
end, {})

vim.api.nvim_create_user_command("DiffnavMergeBoth", function()
    require("diffnav.merge").resolve_both()
end, {})

-- Comandos de Status e Diffview global
vim.api.nvim_create_user_command("DiffnavStatus", function()
    require("diffnav.status").show_status()
end, {})

vim.api.nvim_create_user_command("DiffnavConflicts", function()
    require("diffnav.conflicts").show_conflicts()
end, {})

-- Comando para abrir a interface completa (Sidebar + Diff Lado a Lado)
vim.api.nvim_create_user_command("DiffnavPanel", function()
    require("diffnav.panel").open_panel()
end, {})

-- Comando para abrir a interface flutuante (Estilo Telescope) com diff inline
vim.api.nvim_create_user_command("DiffnavFloat", function()
    require("diffnav.float_panel").open_picker()
end, {})