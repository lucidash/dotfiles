-- Neovim configuration
-- Faithful reproduction of ~/.dotfiles/vim/vimrc, modernized with lazy.nvim.
-- Vim 9.1 (~/.vim/vimrc) stays independent; this config lives only here.
--
-- leader MUST be set before lazy loads any plugin, so that <leader> mappings
-- register against "," rather than the default "\".
vim.g.mapleader = ","
vim.g.maplocalleader = ","

require("config.options")
require("config.keymaps")
require("config.autocmds")
require("config.lazy")
