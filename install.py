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
