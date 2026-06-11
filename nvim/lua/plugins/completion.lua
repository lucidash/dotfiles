-- blink.cmp — autocompletion. Replaces supertab + deoplete/completor + YCM.
return {
  "saghen/blink.cmp",
  version = "*", -- release tag → prebuilt fuzzy binary (no cargo build needed)
  event = "InsertEnter",
  dependencies = { "L3MON4D3/LuaSnip" },
  ---@module 'blink.cmp'
  ---@type blink.cmp.Config
  opts = {
    snippets = { preset = "luasnip" },
    keymap = {
      preset = "default",
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
      ["<CR>"] = { "accept", "fallback" },
      -- preserve UltiSnips muscle memory (vimrc:604-606)
      ["<C-j>"] = { "snippet_forward", "select_next", "fallback" },
      ["<C-k>"] = { "snippet_backward", "select_prev", "fallback" },
    },
    sources = { default = { "lsp", "path", "snippets", "buffer" } },
    fuzzy = { implementation = "prefer_rust_with_warning" }, -- falls back to lua if prebuilt missing
    completion = { documentation = { auto_show = true } },
  },
}
