-- LSP: nvim-lspconfig + mason. Replaces YCM / jedi-vim / python-mode / ALE /
-- deoplete / phpcomplete / javacomplete2 etc.
return {
  {
    "neovim/nvim-lspconfig",
    event = { "BufReadPre", "BufNewFile" },
    dependencies = {
      -- mason must load (and setup) alongside lspconfig so ensure_installed runs;
      -- the :Mason command is still available once loaded.
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason-lspconfig.nvim",
      "saghen/blink.cmp",
    },
    config = function()
      -- Keymaps applied when any LSP attaches (new — no direct vimrc equivalent)
      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(ev)
          local buf = ev.buf
          local function m(keys, fn, desc)
            vim.keymap.set("n", keys, fn, { buffer = buf, desc = desc })
          end
          -- References/implementations return many results → open the picker
          -- immediately (live=true) so a slow server (ts_ls, kotlin) doesn't feel
          -- frozen while the finder runs. (live=true overrides auto_confirm.)
          local function lsp_list(method)
            return function() Snacks.picker[method]({ live = true }) end
          end
          -- Definition/type are usually a single result → keep the quick jump
          -- (auto_confirm, no picker), but echo first so the wait is visible on
          -- slow lookups instead of feeling hung.
          local function lsp_jump(method, what)
            return function()
              vim.api.nvim_echo({ { "Finding " .. what .. "…", "ModeMsg" } }, false, {})
              vim.cmd.redraw()
              Snacks.picker[method]({ auto_confirm = true })
            end
          end
          m("gd", lsp_jump("lsp_definitions", "definition"), "Goto Definition")
          m("gr", lsp_list("lsp_references"), "References")
          m("gi", lsp_list("lsp_implementations"), "Goto Implementation")
          m("gy", lsp_jump("lsp_type_definitions", "type"), "Goto Type Definition")
          m("K", vim.lsp.buf.hover, "Hover")
          m("<leader>rn", vim.lsp.buf.rename, "Rename")
          m("<leader>ca", vim.lsp.buf.code_action, "Code Action")
          m("[d", function() vim.diagnostic.jump({ count = -1 }) end, "Prev Diagnostic")
          m("]d", function() vim.diagnostic.jump({ count = 1 }) end, "Next Diagnostic")
        end,
      })

      vim.diagnostic.config({ virtual_text = true, severity_sort = true })

      local capabilities = require("blink.cmp").get_lsp_capabilities()

      -- Per-server config (merges with nvim-lspconfig's shipped defaults)
      vim.lsp.config("*", { capabilities = capabilities })
      vim.lsp.config("lua_ls", {
        settings = { Lua = { diagnostics = { globals = { "vim", "Snacks" } } } },
      })
      -- swift (likey-ios): sourcekit-lsp ships with Xcode, run via xcrun (not mason)
      vim.lsp.config("sourcekit", { cmd = { "xcrun", "sourcekit-lsp" } })

      -- Servers auto-installed + enabled by mason-lspconfig.
      -- Heavier/optional servers (jdtls, ruby_lsp, texlab, marksman) → add via :Mason.
      require("mason-lspconfig").setup({
        ensure_installed = {
          "pyright", "clangd", "ts_ls", "lua_ls",
          "html", "cssls", "jsonls", "bashls", "vimls", "intelephense",
          "kotlin_language_server", -- likey-android
        },
        automatic_enable = false, -- enable explicitly below (more reliable)
      })

      -- Enable servers explicitly. nvim-lspconfig ships each server's defaults;
      -- vim.lsp.enable activates them (attaches when the binary is installed).
      local servers = {
        "pyright", "clangd", "ts_ls", "lua_ls",
        "html", "cssls", "jsonls", "bashls", "vimls", "intelephense",
        "kotlin_language_server", -- likey-android
      }
      -- ruff: mason's pip install fails on python 3.14 (ensurepip); use PATH
      -- binary (brew install ruff). Powers the LSP and conform's ruff_format.
      if vim.fn.executable("ruff") == 1 then
        table.insert(servers, "ruff")
      end
      -- swift (likey-ios): sourcekit-lsp from the Xcode toolchain
      if vim.fn.executable("xcrun") == 1 then
        table.insert(servers, "sourcekit")
      end
      vim.lsp.enable(servers)
    end,
  },
}
