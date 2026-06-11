-- Git: gitsigns for in-buffer git (hunks, blame, diff) — the things you reach
-- for while editing. Interactive git (status / commit / stage / log / push) is
-- done in gitui, a standalone TUI, so fugitive and gv.vim were dropped.
return {
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = {
      -- IDE-style inline blame on the current line (dimmed virtual text at eol).
      -- On by default; toggle with <leader>ub.
      current_line_blame = true,
      current_line_blame_opts = {
        virt_text = true,
        virt_text_pos = "eol",
        delay = 300,
        ignore_whitespace = false,
      },
      current_line_blame_formatter = "  <author>, <author_time:%Y-%m-%d> · <summary>",
      on_attach = function(buf)
        local gs = require("gitsigns")
        local function map(lhs, rhs, desc)
          vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = desc })
        end
        map("<leader>ha", gs.stage_hunk, "Stage hunk") -- vimrc:880
        map("<leader>hr", gs.reset_hunk, "Reset hunk") -- vimrc:881
        map("]c", function() gs.nav_hunk("next") end, "Next hunk")
        map("[c", function() gs.nav_hunk("prev") end, "Prev hunk")
        map("<leader>ub", gs.toggle_current_line_blame, "Toggle inline blame")
        map("<leader>gb", gs.blame, "Git blame (file)") -- replaces fugitive :Gblame
        map("<leader>gd", gs.diffthis, "Git diff this file") -- replaces fugitive :Gvdiffsplit
      end,
    },
  },
}
