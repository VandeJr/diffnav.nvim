if vim.g.loaded_diffnav then
    return
end
vim.g.loaded_diffnav = true

-- Comando do editor para acionar a interface visual do Diffnav
vim.api.nvim_create_user_command("Diffnav", function()
    require("diffnav").show_diff()
end, {})