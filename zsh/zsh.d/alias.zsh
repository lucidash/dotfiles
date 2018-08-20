# own aliasing 
#
# ssh ========================================= {{{
alias bit='ssh lucidash@bit.sparcs.org'
alias toy2='ssh user2@172.16.100.158'
alias toy3='ssh user3@172.16.101.87'
#alias sw='ssh user2@61.43.139.132'
alias sw='ssh user2@61.43.139.142'
alias sparcs='ssh lucidash@sparcs.org'

alias tmdrb4='ssh lucidash@14.63.218.169'
alias tmdrb2='ssh lucidash@14.63.218.219'
alias tmdrb3='ssh lucidash@14.63.218.54'

alias vm='ssh 10.211.55.4'
#alias tmdrb3='ssh lucidash@14.63.218.219 -p 24'



# git-number ======= {{{{{{{
#alias git='git number'
# ======= }}}}}}}



# VirtualEnv ========================================= {{{
#
alias venv='virtualenv'
#
# # }}}


# Tmux ========================================= {{{
#
# # create a new session with name
alias tmuxnew='tmux new -s'
# # list sessions
alias tmuxl='tmux list-sessions'
# # tmuxa <session> : attach to <session> (force 256color and detach others)
alias tmuxa='tmux -2 attach-session -d -t'
#
# # }}}



# screen ========================================= {{{
# 
# # list sessions
alias sls='screen -ls'
# # create a new session with name 
alias snew='screen -S'
# # sdr <session> : attach to <session> and detach others
alias sdr='screen -d -r'
#
# # }}}

#tail -f to tailf
alias tailf='tail -f'

#others
alias jj='python manage.py'
alias l='ls -G'
alias boj='python submit.py'
