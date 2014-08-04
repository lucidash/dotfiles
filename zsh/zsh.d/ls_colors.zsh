# LSCOLORS/LS_COLORS
autoload colors; colors;

LS_COLORS="di=01;34:ln=01;36:pi=40;33:so=01;35:do=01;35:bd=40;33;01:cd=40;33;01:or=01;05;37;41:mi=01;05;37;41:su=37;41:sg=30;43:tw=30;42:ow=34;42:st=37;44:ex=01;32";
LSCOLORS="ExGxFxDxCxDxDxhbhdacEc";

# Do we need Linux or BSD Style?
if ls --color -d . &>/dev/null 2>&1
then
	# Linux Style
	export LS_COLORS=$LS_COLORS
	alias ls='ls --color=tty'
else
	# BSD Style
	export LSCOLORS=$LSCOLORS
	alias ls='ls -G'
fi

# Use same colors for autocompletion
zmodload -a colors
zmodload -a autocomplete
zmodload -a complist
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
