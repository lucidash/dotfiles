# Neovim config

`~/.vim/vimrc`(Vim 9.1)의 습관을 그대로 살린 from-scratch Neovim 설정. lazy.nvim 기반,
모던 플러그인으로 대체. Vim 9.1은 별개로 독립 유지된다.

- **위치**: `~/.dotfiles/nvim/` → `~/.config/nvim` 심볼릭 링크 (`install.py`가 매핑)
- **leader**: `,` (vimrc와 동일)
- **picker**: snacks.nvim (picker/explorer/dashboard/indent/zen)
- **IDE**: nvim-lspconfig + mason, blink.cmp, nvim-treesitter, conform, LuaSnip

## 부트스트랩 (새 머신)

```sh
# 1. 심볼릭 링크 (dotfiles install.py 가 ~/.config/nvim → ~/.dotfiles/nvim 매핑)
ln -sfn ~/.dotfiles/nvim ~/.config/nvim      # 또는: python3 ~/.dotfiles/install.py --force
# 2. 플러그인 설치
nvim --headless "+Lazy! sync" +qa
# 3. LSP 서버 설치 (nvim 안에서)
:Mason
# 권장 도구: brew install fd   (snacks.picker 파일 검색; 없으면 rg 폴백)
```

## 주요 키맵 (vimrc에서 이어짐)

| 키 | 동작 |
|----|------|
| `<C-p>` | 파일 찾기 (snacks smart picker) |
| `,rg` / `,ag` | 내용 grep (visual = 선택영역 grep) |
| `,N` | 파일 탐색기 (snacks explorer) |
| `,t` | 심볼 아웃라인 (aerial) |
| `,G` | undo 트리 (undotree) |
| `,w` `,S` | 저장 / 트레일링 공백 제거 |
| `,y` `,x` `,p` | 시스템 클립보드 yank/cut/paste |
| `,1`..`,9` `,0` | 탭 이동 / `[t` `]t` 탭, `[b` `]b` 버퍼 |
| `,g*` | git (fugitive): `,gs` status, `,gd` diff, `,gb` blame, `,gci` commit, `,gp` push |
| `,ha` `,hr` | git hunk stage / reset (gitsigns) |
| `,s"` `,s(` … | surround (nvim-surround) |
| `<F4>` `<F5>` | 컴파일/실행 (cpp/c/py/ruby/js) — 경쟁 프로그래밍 |
| `,!` `,@` | 실행 / stdin(`< in`) 실행 |
| visual `<C-k>` | `@<abspath>:l1-l2` 클립보드 복사 |

### LSP (신규)
`gd` 정의 · `gr` 참조 · `K` hover · `,rn` rename · `,ca` code action · `[d` `]d` 진단

### 자동완성 / 스니펫 (blink.cmp + LuaSnip)
`<C-Space>` 메뉴 · `<CR>` accept · `<C-j>`/`<C-k>` 스니펫 점프(UltiSnips 머슬메모리)

## 구조

```
init.lua                 leader → config.* require
lua/config/              options, keymaps, autocmds, lazy
lua/plugins/             snacks, ui, editor, treesitter, lsp,
                         completion, snippets, formatting, git, coding
snippets/                cpp/python/javascript (SnipMate 형식, vim에서 복사)
```
