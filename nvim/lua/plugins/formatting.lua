-- conform.nvim — formatting.
-- prettier only runs when the project has an explicit prettier config; projects
-- that use other tooling (e.g. likey-backend → oxlint + .editorconfig, no
-- prettier) are left untouched on save. c/cpp excluded to keep CP tab style.
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    { "<leader>F", function() require("conform").format({ async = true }) end, mode = { "n", "v" }, desc = "Format" },
  },
  opts = function()
    -- Detect a prettier config, but intentionally NOT package.json: nearly every
    -- JS/TS project has package.json, yet many don't use prettier. Only an
    -- explicit prettier config counts.
    local prettier_cwd = require("conform.util").root_file({
      ".prettierrc",
      ".prettierrc.json",
      ".prettierrc.yml",
      ".prettierrc.yaml",
      ".prettierrc.json5",
      ".prettierrc.js",
      ".prettierrc.cjs",
      ".prettierrc.mjs",
      ".prettierrc.ts",
      ".prettierrc.toml",
      "prettier.config.js",
      "prettier.config.cjs",
      "prettier.config.mjs",
      "prettier.config.ts",
    })
    return {
      formatters_by_ft = {
        python = { "ruff_format", "ruff_organize_imports" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        json = { "prettier" },
        jsonc = { "prettier" },
        html = { "prettier" },
        css = { "prettier" },
        vue = { "prettier" },
        lua = { "stylua" },
      },
      formatters = {
        prettier = {
          require_cwd = true, -- skip prettier unless a prettier config exists
          cwd = prettier_cwd,
        },
      },
      -- No lsp_format fallback: if no conform formatter applies (e.g. ts/js
      -- without a prettier config), leave the file alone rather than reformatting
      -- with the LSP, which would also diverge from the project's style.
      format_on_save = function(buf)
        local ft = vim.bo[buf].filetype
        if ft == "c" or ft == "cpp" then
          return -- keep CP tab indentation untouched
        end
        return { timeout_ms = 1000 }
      end,
    }
  end,
}
