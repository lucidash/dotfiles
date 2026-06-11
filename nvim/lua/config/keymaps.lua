-- Non-plugin keymaps ported from the vimrc.
-- Plugin-dependent maps (snacks picker, fugitive, gitsigns, surround, LSP,
-- completion/snippet jumps) live in their respective lua/plugins/*.lua files.
local map = vim.keymap.set

-- Disable arrow keys (vimrc:73-76) -----------------------------------------
for _, k in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
  map({ "n", "v" }, k, "<Nop>")
  map("i", k, "<Nop>")
end

-- Move by display line (vimrc:80-81) ---------------------------------------
map("n", "j", "gj")
map("n", "k", "gk")

-- Keep selection when indenting (vimrc:85-86) ------------------------------
map("v", "<", "<gv")
map("v", ">", ">gv")

-- <CR> clears search highlight, but stays functional in quickfix (vimrc:69)
map("n", "<CR>", function()
  return vim.bo.buftype == "quickfix" and "<CR>" or "<cmd>noh<CR>"
end, { expr = true, silent = true })

-- Window navigation (vimrc:443-444) ----------------------------------------
map("n", "<C-J>", "<C-w>j")
map("n", "<C-K>", "<C-w>k")

-- Buffer navigation (vimrc:454-455) ----------------------------------------
map("n", "[b", "<cmd>bprevious<CR>")
map("n", "]b", "<cmd>bnext<CR>")

-- Tab navigation (vimrc:458-472) -------------------------------------------
map("n", "<C-n>", "<cmd>tabnew<CR>")
map("n", "<C-S-Tab>", "<cmd>tabprevious<CR>")
map("n", "<C-Tab>", "<cmd>tabnext<CR>")
map("n", "[t", "<cmd>tabprevious<CR>")
map("n", "]t", "<cmd>tabnext<CR>")
for i = 1, 9 do
  map("n", "<leader>" .. i, i .. "gt")
end
map("n", "<leader>0", "<cmd>tablast<CR>")

-- Location list (vimrc:475-476) --------------------------------------------
map("n", "[l", "<cmd>lprevious<CR>")
map("n", "]l", "<cmd>lnext<CR>")

-- Comment: <C-/> (Ctrl+/) reproduces NERDCommenter's "invert" (vimrc:483 mapped
-- <C-_> → ,ci). It toggles EACH selected line individually (commented→uncomment,
-- plain→comment), unlike nvim's gc which keys off the first line. The built-in
-- gcc / gc remain available as block-toggle.
-- Ctrl+/ arrives as <C-_> on most terminals, <C-/> on some (kitty/wezterm/CSI-u).
local function comment_invert(l1, l2)
  local cs = vim.bo.commentstring
  if cs == "" or not cs:find("%%s") then
    vim.notify("No commentstring for filetype: " .. vim.bo.filetype, vim.log.levels.WARN)
    return
  end
  local left, right = cs:match("^(.-)%%s(.-)$")
  left, right = vim.trim(left or ""), vim.trim(right or "")
  local lp, rp = vim.pesc(left), vim.pesc(right)
  for lnum = l1, l2 do
    local line = vim.fn.getline(lnum)
    local indent, content = line:match("^(%s*)(.*)$")
    if content ~= "" then -- skip blank lines, like NERDCommenter
      local commented = content:match("^" .. lp) and (right == "" or content:match(rp .. "$"))
      if commented then
        content = content:gsub("^" .. lp .. "%s?", "")
        if right ~= "" then content = content:gsub("%s?" .. rp .. "$", "") end
      else
        content = left .. " " .. content .. (right ~= "" and (" " .. right) or "")
      end
      vim.fn.setline(lnum, indent .. content)
    end
  end
end
for _, key in ipairs({ "<C-_>", "<C-/>" }) do
  map("n", key, function()
    local l = vim.fn.line(".")
    comment_invert(l, l + vim.v.count1 - 1)
  end, { desc = "Comment invert (line)" })
  map("x", key, function()
    local a, b = vim.fn.line("v"), vim.fn.line(".")
    if a > b then
      a, b = b, a
    end
    comment_invert(a, b)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
  end, { desc = "Comment invert (selection)" })
end

-- Save (vimrc:829) ----------------------------------------------------------
map("n", "<leader>w", "<cmd>w!<CR>")

-- System-clipboard yank / cut / paste (vimrc:832-834) ----------------------
map({ "n", "v" }, "<leader>y", '"*y')
map({ "n", "v" }, "<leader>x", '"*x')
map({ "n", "v" }, "<leader>p", '"*p')

-- cd to current file's directory (vimrc:812) -------------------------------
map("n", "<leader>cd", "<cmd>cd %:p:h<CR>")

-- JSON pretty-print (vimrc:885; python → python3) --------------------------
map("n", "<leader>js", "<cmd>%!python3 -m json.tool<CR>")

-- Reload config (vimrc:810) -------------------------------------------------
map("n", "<leader>src", "<cmd>source $MYVIMRC<CR>")

-- Redraw (vimrc:788; nvim needs no termguicolors re-detection) --------------
map("n", "<leader>R", "<cmd>mode<CR>")

-- Strip trailing whitespace (vimrc:826; :Strip defined in autocmds.lua) -----
map("n", "<leader>S", "<cmd>Strip<CR>")

-- Quick write from insert mode (vimrc:780) ---------------------------------
map("i", "<F2>", "<Esc><cmd>w<CR>")

-- Copy current file to system clipboard via pbcopy (vimrc:781, macOS) -------
map("n", "<F3>", "<cmd>!cat % | pbcopy<CR>")

-- Visual <C-k>: copy "@<abspath>:l1-l2" to + and " registers ---------------
-- Ported from CopyAbsPathWithRange (vimrc:888-904).
map("x", "<C-k>", function()
  local l1 = vim.fn.getpos("v")[2]
  local l2 = vim.fn.getpos(".")[2]
  if l1 > l2 then
    l1, l2 = l2, l1
  end
  local text = string.format("@%s:%d-%d", vim.fn.expand("%:p"), l1, l2)
  vim.fn.setreg("+", text)
  vim.fn.setreg('"', text)
  vim.api.nvim_echo({ { text } }, false, {})
  -- leave visual mode (mirror the vimrc :<C-u> behavior)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", false)
end, { silent = true })
