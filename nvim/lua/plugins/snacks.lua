-- snacks.nvim — single plugin that absorbs many legacy ones:
--   picker (fzf.vim), explorer (NERDTree), dashboard (startify),
--   indent (indent-guides), zen (goyo), registers (peekaboo), bufdelete.
return {
  "folke/snacks.nvim",
  priority = 1000,
  lazy = false,
  ---@type snacks.Config
  opts = {
    picker = {
      enabled = true,
      win = {
        input = {
          keys = {
            -- <C-u>: clear the input line (vim's insert <C-u>) instead of
            -- snacks' default list_scroll_up. A function rhs is registered as a
            -- plain keymap (not a picker action); it feeds a non-remapped <C-u>.
            ["<C-u>"] = {
              function()
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-u>", true, false, true), "n", false)
              end,
              mode = "i",
            },
          },
        },
      },
    },
    explorer = { enabled = true },
    dashboard = { enabled = true },
    indent = { enabled = true }, -- replaces vim-indent-guides
    notifier = { enabled = true },
    bufdelete = { enabled = true },
    zen = { enabled = true }, -- replaces goyo
    scope = { enabled = true },
    input = { enabled = true },
    quickfile = { enabled = true },
    gitbrowse = { enabled = true },
    words = { enabled = true },
  },
  config = function(_, opts)
    require("snacks").setup(opts)
    vim.notify = Snacks.notifier.notify -- route vim.notify through snacks toasts (top-right)
  end,
  keys = {
    -- Files: <C-P> → smart picker (replaces the elaborate s:fzf_smart, vimrc:122-161)
    { "<C-p>", function() Snacks.picker.smart() end, desc = "Find Files (smart)" },
    -- Grep: ,rg / ,ag — normal = live grep, visual = grep selection (vimrc:488-491)
    { "<leader>rg", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>rg", function() Snacks.picker.grep_word() end, mode = "x", desc = "Grep selection" },
    { "<leader>ag", function() Snacks.picker.grep() end, desc = "Grep" },
    { "<leader>ag", function() Snacks.picker.grep_word() end, mode = "x", desc = "Grep selection" },
    -- Explorer: ,N (replaces NERDTreeTabsToggle, vimrc:726)
    { "<leader>N", function() Snacks.explorer() end, desc = "Explorer" },
    -- Buffers / registers (registers replaces vim-peekaboo)
    { "<leader>fb", function() Snacks.picker.buffers() end, desc = "Buffers" },
    { '<leader>"', function() Snacks.picker.registers() end, desc = "Registers" },
    { "<leader>:", function() Snacks.picker.command_history() end, desc = "Command History" },
    -- Safe buffer delete (replaces <s-w> bp|sp|bn|bd, vimrc:453)
    { "<S-w>", function() Snacks.bufdelete() end, desc = "Delete Buffer" },
    -- Zen mode (replaces goyo)
    { "<leader>z", function() Snacks.zen() end, desc = "Zen Mode" },
  },
}
