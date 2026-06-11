-- Filetype-specific plugins kept from the vim setup (lazy-loaded by ft/cmd).
return {
  -- LaTeX (first-class nvim support)
  {
    "lervag/vimtex",
    ft = { "tex", "plaintex" },
    init = function()
      vim.g.vimtex_view_method = "skim" -- macOS Skim; harmless if absent
    end,
  },

  -- Pandoc / Markdown
  { "vim-pandoc/vim-pandoc-syntax", lazy = true },
  {
    "vim-pandoc/vim-pandoc",
    ft = { "markdown", "pandoc" },
    dependencies = { "vim-pandoc/vim-pandoc-syntax" },
  },

  -- tmux config syntax
  { "tmux-plugins/vim-tmux", ft = "tmux" },

  -- AppleScript (macOS)
  { "Tyilo/applescript.vim", ft = "applescript" },

  -- Dash.app docs (macOS); :Dash
  { "rizzatti/dash.vim", cmd = "Dash" },

  -- Typora open; :Typora
  { "wookayin/vim-typora", cmd = "Typora" },
}
