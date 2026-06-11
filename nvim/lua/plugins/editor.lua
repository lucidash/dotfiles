-- Editing / motion / navigation plugins.
return {
  -- vim-repeat: makes surround/etc. dot-repeatable
  { "tpope/vim-repeat", event = "VeryLazy" },

  -- nvim-surround (replaces vim-surround); ,s<char> wrappers (vimrc:858-873)
  {
    "kylechui/nvim-surround",
    event = "VeryLazy",
    config = function()
      require("nvim-surround").setup()
      local wrap = {
        ['"'] = '"', ["'"] = "'", ["`"] = "`",
        ["("] = "(", [")"] = ")", ["["] = "[", ["]"] = "]",
        ["{"] = "{", ["}"] = "}",
      }
      for k, v in pairs(wrap) do
        vim.keymap.set("n", "<leader>s" .. k, "ysiw" .. v, { remap = true, desc = "Surround word" })
      end
      -- starred variants (vimrc:864-867): ,s* ,s_ ,s~ add trailing l; ,s$ does not
      vim.keymap.set("n", "<leader>s*", "ysiw*l", { remap = true })
      vim.keymap.set("n", "<leader>s_", "ysiw_l", { remap = true })
      vim.keymap.set("n", "<leader>s~", "ysiw~l", { remap = true })
      vim.keymap.set("n", "<leader>s$", "ysiw$", { remap = true })
    end,
  },

  -- vim-asterisk: *,#,g*,g# with cursor-stay (vimrc:656-665)
  {
    "haya14busa/vim-asterisk",
    keys = { "*", "#", "g*", "g#" },
    init = function() vim.g["asterisk#keeppos"] = 1 end,
    config = function()
      vim.keymap.set("", "*", "<Plug>(asterisk-z*)")
      vim.keymap.set("", "#", "<Plug>(asterisk-z#)")
      vim.keymap.set("", "g*", "<Plug>(asterisk-gz*)")
      vim.keymap.set("", "g#", "<Plug>(asterisk-gz#)")
    end,
  },

  -- flash: motions (replaces easymotion); native incsearch handles / and ?
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
    },
  },

  -- undotree (replaces gundo); ,G (vimrc:644-645)
  {
    "mbbill/undotree",
    cmd = "UndotreeToggle",
    keys = { { "<leader>G", "<cmd>UndotreeToggle<CR>", desc = "Undotree" } },
    init = function() vim.g.undotree_WindowLayout = 3 end, -- tree on the right (gundo_right)
  },

  -- aerial (replaces tagbar); ,t (vimrc:651)
  {
    "stevearc/aerial.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
    cmd = "AerialToggle",
    keys = { { "<leader>t", "<cmd>AerialToggle<CR>", desc = "Outline (Aerial)" } },
    opts = {},
  },

  -- marks.nvim (replaces vim-signature): mark signs in the gutter
  { "chentoast/marks.nvim", event = "VeryLazy", opts = {} },

  -- vim-easy-align (kept; works in nvim). ga in normal/visual.
  {
    "junegunn/vim-easy-align",
    keys = { { "ga", "<Plug>(EasyAlign)", mode = { "n", "x" }, desc = "EasyAlign" } },
  },

  -- vim-eunuch (kept): :Move/:Rename/:SudoWrite/etc.
  {
    "tpope/vim-eunuch",
    cmd = { "Move", "Rename", "Delete", "Remove", "Copy", "Chmod", "Mkdir", "SudoWrite", "SudoEdit" },
  },

  -- maximize.nvim (replaces vim-maximizer); <C-w>z (vimrc:447)
  {
    "declancm/maximize.nvim",
    keys = { { "<C-w>z", function() require("maximize").toggle() end, desc = "Maximize window" } },
    opts = {},
  },
}
