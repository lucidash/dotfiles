-- Autocommands ported from the vimrc.
local aug = vim.api.nvim_create_augroup("vimrc", { clear = true })
local au = vim.api.nvim_create_autocmd

-- Filetype-specific indentation (vimrc:353-367) ----------------------------
local function ftindent(pat, ts, sw, sts, et)
  au("FileType", {
    group = aug,
    pattern = pat,
    callback = function()
      vim.bo.tabstop = ts
      vim.bo.shiftwidth = sw
      vim.bo.softtabstop = sts
      vim.bo.expandtab = et
    end,
  })
end
ftindent({ "python", "html", "php" }, 4, 4, 4, true) -- vimrc:353-355,364
ftindent({ "c", "cpp" }, 4, 4, 4, false) -- vimrc:356-357 — TABS (competitive-programming convention)
ftindent({ "ruby" }, 2, 2, 0, true) -- vimrc:360
ftindent({ "javascript", "coffee" }, 2, 2, 2, true) -- vimrc:359,365-366
au("FileType", { group = aug, pattern = "text", callback = function() vim.bo.textwidth = 80 end }) -- vimrc:358

-- Register .phps/.php3s as php (vimrc:361) ----------------------------------
vim.filetype.add({ extension = { phps = "php", php3s = "php" } })

-- git commit: foldlevel=1 (vimrc:814) --------------------------------------
au("FileType", { group = aug, pattern = "git", callback = function() vim.wo.foldlevel = 1 end })

-- Restore cursor position on read (vimrc:370-373) --------------------------
au("BufReadPost", {
  group = aug,
  callback = function(ev)
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    local lcount = vim.api.nvim_buf_line_count(ev.buf)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Highlight on yank (replaces vim-highlightedyank) -------------------------
au("TextYankPost", { group = aug, callback = function() vim.highlight.on_yank() end })

-- Strip trailing whitespace (vimrc:763-764, 817-822) -----------------------
local function strip_ws()
  local view = vim.fn.winsaveview()
  vim.cmd([[keeppatterns %s/\s\+$//e]])
  vim.fn.winrestview(view)
end
vim.api.nvim_create_user_command("Strip", strip_ws, {})
au("BufWritePre", {
  group = aug,
  pattern = { "*.c", "*.cpp", "*.java", "*.js", "*.html", "*.rb", "*.py", "*.md", "*.vim", "*.php" },
  callback = strip_ws,
})

-- Compile / run keymaps — competitive-programming core (vimrc:769-779) ------
-- Buffer-local FileType maps; each writes then runs a shell line via `:!`.
local function map_run(ft, lhs, shell_cmd)
  au("FileType", {
    group = aug,
    pattern = ft,
    callback = function(ev)
      vim.keymap.set("n", lhs, "<Esc><cmd>w<CR><cmd>!" .. shell_cmd .. "<CR>", { buffer = ev.buf, silent = false })
    end,
  })
end
-- ruby
map_run("ruby", "<F5>", "ruby %") -- vimrc:769
map_run("ruby", "<leader>!", "ruby %") -- vimrc:775
-- javascript
map_run("javascript", "<F5>", "node %") -- vimrc:770
-- python (venv-activated)
map_run("python", "<F5>", "source %:h/.venv/bin/activate; python %") -- vimrc:771
map_run("python", "<leader>!", "source %:h/.venv/bin/activate; python %") -- vimrc:776
map_run("python", "<leader>@", "source %:h/.venv/bin/activate; python % < in") -- vimrc:777
-- cpp (g++ -O2 -std=gnu++11)
map_run("cpp", "<F4>", "g++ -O2 -std=gnu++11 % && ./a.out") -- vimrc:772
map_run("cpp", "<F5>", "g++ -O2 -std=gnu++11 % && ./a.out < in") -- vimrc:773
map_run("cpp", "<leader>!", "g++ -O2 -std=gnu++11 % && ./a.out") -- vimrc:778
map_run("cpp", "<leader>@", "g++ -O2 -std=gnu++11 % && ./a.out < in") -- vimrc:779
-- c
map_run("c", "<F5>", "gcc % && ./a.out < input.txt") -- vimrc:774
