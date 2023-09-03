export LS_OPTIONS='--color=auto'
eval "$(dircolors)"
alias ls='ls $LS_OPTIONS'

alias ll='ls -la'
alias lf='ls -la | grep ^-'
alias ld='ls -la | grep ^d'
alias cls='clear -x'

cd /home
