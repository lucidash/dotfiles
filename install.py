#!/usr/bin/env python3
import os
import shutil
from optparse import OptionParser
from sys import stderr


################# BEGIN OF FIXME #################

# Task Definition
# (path of target symlink) : (location of source file in the repository)

tasks = {
    # SHELLS
    #	'~/.bashrc' : 'bashrc',
    '~/.screenrc' : 'screenrc',

    # VIM
    '~/.vimrc' : 'vim/vimrc',
    '~/.vim' : 'vim',
    '~/.vim/autoload/plug.vim' : 'vim/bundle/vim-plug/plug.vim',

    # NeoVIM
    '~/.config/nvim' : 'nvim',

    # GIT
    '~/.gitconfig' : 'git/gitconfig',
    '~/.gitignore' : 'git/gitignore',

    # ZSH
    '~/.zprezto'  : 'zsh/zprezto',
    '~/.zsh'      : 'zsh',
    '~/.zlogin'   : 'zsh/zlogin',
    '~/.zlogout'  : 'zsh/zlogout',
    '~/.zpreztorc': 'zsh/zpreztorc',
    '~/.zprofile' : 'zsh/zprofile',
    '~/.zshenv'   : 'zsh/zshenv',
    '~/.zshrc'    : 'zsh/zshrc',
    '~/.LS_COLORS' : 'zsh/LS_COLORS',

    # Bins
    '~/.local/bin/fasd' : 'zsh/fasd/fasd',

    # X
    #	'~/.Xmodmap' : 'Xmodmap',

    # GTK
    #	'~/.gtkrc-2.0' : 'gtkrc-2.0',

    # tmux
    '~/.tmux.conf' : 'tmux.conf',

    # Claude
    '~/.claude/settings.json' : 'claude/settings.json',
    '~/.claude/CLAUDE.md' : 'claude/CLAUDE.md',

    # .config
    #	'~/.config/terminator' : 'config/terminator',
}

################# END OF FIXME #################




# command line arguments
def option():
    parser = OptionParser()
    parser.add_option("-f", "--force", action="store_true", default=False)
    (options, args) = parser.parse_args()
    return options

# get current directory (absolute path) and options
current_dir = os.path.abspath(os.path.dirname(__file__))
options = option()

for target, source in tasks.items():
            # normalize paths
    source = os.path.join(current_dir, source)
    target = os.path.expanduser(target)

# if source does not exists...
    if not os.path.lexists(source):
        print(f"source {source} : does not exists", file=stderr)
        continue

# if --force option is given, delete the previously existing symlink
    if os.path.lexists(target) and os.path.islink(target) and options.force == True:
        os.unlink(target)
    if os.path.lexists(target) and os.path.isdir(target) and options.force == True:
        shutil.rmtree(target)
    if os.path.lexists(target) and options.force == True:
        os.remove(target)

# make a symbolic link!
    if os.path.lexists(target):
        print(f"{target} : already exists", file=stderr)
    else:
        try:
            mkdir_target = os.path.split(target)[0]
            os.makedirs(mkdir_target)
            print(f"Created directory : {mkdir_target}", file=stderr)
        except:
            pass
    try :
        os.symlink(source, target)
    except:
        pass
    print(f"{target} : symlink created from '{source}'", file=stderr)

# install vim-plug
os.system("curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim")
zsh = os.system("which zsh")


# ---- Neovim bootstrap (macOS only) ----
# install.py only symlinks files; the nvim config needs a few external tools and
# a one-time plugin/LSP install. On macOS we do that here so `python3 install.py`
# alone gives a working setup.
import platform

if platform.system() == "Darwin":
    print("\n=== Neovim bootstrap (macOS) ===", file=stderr)

    # 1. external CLI tools (Homebrew)
    if os.system("command -v brew >/dev/null 2>&1") == 0:
        os.system("brew install lazygit fd ruff")
    else:
        print("Homebrew not found; skipping lazygit/fd/ruff", file=stderr)

    # 2. tree-sitter CLI 0.25.x — nvim-treesitter needs it to build the swift
    #    parser; 0.26+ is incompatible (the --no-bindings flag was removed).
    if os.system("command -v npm >/dev/null 2>&1") == 0:
        os.system("npm install -g tree-sitter-cli@0.25.8")
    else:
        print("npm not found; skipping tree-sitter-cli (swift parser)", file=stderr)

    # 3. nvim: plugins (lazy) + LSP servers/formatters (mason). ruff is from brew
    #    (mason's pip-based ruff fails on Python 3.14), so it is not listed here.
    if os.system("command -v nvim >/dev/null 2>&1") == 0:
        print("Syncing nvim plugins (this clones repos and builds parsers)...", file=stderr)
        os.system("nvim --headless '+Lazy! sync' +qa")
        mason_pkgs = (
            "pyright clangd typescript-language-server lua-language-server "
            "html-lsp css-lsp json-lsp bash-language-server vim-language-server "
            "intelephense kotlin-language-server stylua prettier"
        )
        print("Installing LSP servers + formatters via mason (may take a few minutes)...", file=stderr)
        os.system(
            "nvim --headless "
            "'+lua require(\"mason\").setup()' "
            "'+MasonInstall " + mason_pkgs + "' "
            "'+lua vim.wait(420000, function() "
            "return #require(\"mason-registry\").get_installed_package_names() >= 13 end)' "
            "+qa"
        )
    else:
        print("nvim not found; skipping plugin/LSP bootstrap", file=stderr)
