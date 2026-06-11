-- LuaSnip — snippet engine. Replaces UltiSnips.
-- Loads friendly-snippets (vscode format) + the ported cpp/python/javascript
-- snippets (SnipMate/UltiSnips `snippet <trig>` format) copied into ./snippets/.
return {
  "L3MON4D3/LuaSnip",
  lazy = true,
  dependencies = { "rafamadriz/friendly-snippets" },
  config = function()
    require("luasnip.loaders.from_vscode").lazy_load()
    require("luasnip.loaders.from_snipmate").lazy_load({
      paths = { vim.fn.stdpath("config") .. "/snippets" },
    })
  end,
}
