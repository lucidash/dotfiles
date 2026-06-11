-- nvim-treesitter — replaces vim-polyglot and all per-language syntax plugins.
return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master", -- master is the stable branch (main is still in flux on 0.11)
  build = ":TSUpdate",
  event = { "BufReadPost", "BufNewFile" },
  cmd = { "TSUpdate", "TSInstall" },
  dependencies = { "nvim-treesitter/nvim-treesitter-textobjects" },
  main = "nvim-treesitter.configs",
  opts = {
    -- Inferred from the vimrc's filetypes (indents, run mappings, vimtex, vim-tmux)
    ensure_installed = {
      "c", "cpp", "python", "javascript", "typescript", "tsx", "html", "css",
      "vue", "php", "java", "ruby", "lua", "luadoc", "vim", "vimdoc", "bash",
      "json", "jsonc", "yaml", "toml", "markdown", "markdown_inline",
      "groovy", "kotlin", "swift", "tmux", "diff", "git_config", "gitcommit", "query", "regex",
    },
    highlight = { enable = true },
    indent = { enable = true },
    incremental_selection = { enable = true },
  },
}
