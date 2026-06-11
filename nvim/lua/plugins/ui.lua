-- Colorscheme + statusline. Replaces xoria256 + vim-airline.
return {
  {
    "folke/tokyonight.nvim",
    lazy = false,
    priority = 1000,
    opts = { style = "night" }, -- dark, close to the old xoria256 feel
    config = function(_, opts)
      require("tokyonight").setup(opts)
      vim.cmd.colorscheme("tokyonight-night")
    end,
  },
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    event = "VeryLazy",
    opts = {
      options = {
        theme = "tokyonight",
        globalstatus = true, -- single statusline (laststatus=3)
        component_separators = "|",
        section_separators = "",
      },
      sections = {
        lualine_a = { "mode" },
        lualine_b = { "branch", "diff", "diagnostics" },
        -- path = 1 → file path relative to the cwd (the dir nvim was opened in),
        -- e.g. src/api/index.ts instead of just index.ts
        lualine_c = { { "filename", path = 1 } },
        lualine_x = { "encoding", "fileformat", "filetype" },
        lualine_y = { "progress" },
        lualine_z = { "location" },
      },
      -- airline showed tabs/buffers in the tabline (vimrc:753-757)
      tabline = {
        lualine_a = { { "tabs", mode = 2 } }, -- mode 2 = tab number + name
      },
    },
  },

  -- LSP progress UI: spinner + message (bottom-right) while servers work —
  -- references search (gr), hover, and especially kotlin/sourcekit indexing,
  -- which nvim otherwise reports nowhere.
  {
    "j-hui/fidget.nvim",
    event = "LspAttach",
    opts = {
      notification = {
        window = { winblend = 0 }, -- transparent bg, blends with theme
      },
    },
  },
}
