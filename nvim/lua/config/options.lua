-- vimrc `set` options → vim.opt
-- Options guarded by `if !has('nvim')` in the vimrc are intentionally skipped
-- (scriptencoding, ttymouse, t_Co/t_Sf, enc/tenc, mosh termguicolors logic, swap-dir hack).
local o = vim.opt

-- General / behavior --------------------------------------------------------
o.history = 1000 -- vimrc:13
o.undolevels = 1000 -- vimrc:14
o.undofile = true -- persistent undo (nvim improvement; stored under stdpath('state'))
o.lazyredraw = true -- vimrc:15
o.switchbuf = "usetab,split" -- vimrc:20
o.visualbell = true -- vimrc:12
o.mouse = "a" -- vimrc:90/188/201
o.updatetime = 250 -- vimrc ut=10 → 250 (10 is too aggressive for nvim CursorHold/LSP/gitsigns)

-- Use zsh for :! (vimrc:62-63); compile/run mappings rely on zsh syntax
if vim.fn.executable("/bin/zsh") == 1 then
  o.shell = "/bin/zsh"
end

-- Backup / swap -------------------------------------------------------------
o.backup = false -- vimrc:29
o.writebackup = false -- vimrc:30
o.backupext = ".bak" -- vimrc:322 (bex=.bak)

-- Appearance ----------------------------------------------------------------
o.number = true -- nu (vimrc:195)
o.ruler = true -- ru
o.showcmd = true -- sc
o.wrap = true -- wrap
o.laststatus = 3 -- ls=2 → 3 (single global statusline for lualine)
o.list = true -- vimrc:203
o.listchars = { tab = "» ", trail = "·", extends = ">", precedes = "<" } -- vimrc:204
o.signcolumn = "yes" -- replaces the dummy-sign hack (vimrc:696-700)
o.termguicolors = true -- 24-bit color (nvim: on in any truecolor terminal)
o.background = "dark" -- vimrc:227

-- Tabs / indent -------------------------------------------------------------
o.expandtab = true -- et (vimrc:196)
o.tabstop = 2 -- ts=2
o.shiftwidth = 2 -- sw=2
o.softtabstop = 2 -- sts=2
o.backspace = { "indent", "eol", "start" } -- bs=2
o.autoindent = false -- noai (vimrc:197)
o.smartindent = false -- nosi

-- Search --------------------------------------------------------------------
o.hlsearch = true -- hls (vimrc:197)
o.incsearch = true -- is
o.ignorecase = true -- ic
o.smartcase = true -- scs
o.wrapscan = true -- ws
o.magic = true -- magic

-- Moving around -------------------------------------------------------------
o.startofline = true -- sol (vimrc:198)
o.selection = "inclusive" -- sel=inclusive
o.matchpairs:append("<:>") -- mps+=<:>

-- Misc ----------------------------------------------------------------------
o.report = 0 -- vimrc:200
o.wildmenu = true -- wmnu
o.wildignore:append({ "*/tmp/*", "*.so", "*.swp", "*.zip" }) -- vimrc:294

-- Encoding / file formats (nvim is utf-8 native) ----------------------------
o.fileformats = "unix,dos,mac" -- ffs (vimrc:207)
o.fileencodings = "utf-8,cp949,cp932,euc-jp,shift-jis,big5,latin2,ucs-2le" -- vimrc:208

-- Folding (git ft sets foldlevel=1 via autocmd; otherwise no auto-folding) ---
o.foldenable = false
