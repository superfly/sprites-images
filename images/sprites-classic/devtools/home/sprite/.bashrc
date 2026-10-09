# Default bash configuration for sprite

# Set terminal title to show current directory when idle
case "$TERM" in
xterm*|rxvt*|screen*|tmux*)
    PROMPT_COMMAND='echo -ne "\033]0;${PWD/#$HOME/\~}\007"'
    ;;
esac

# Set a simple but nice prompt with colors
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Enable color output
export CLICOLOR=1

# History settings
HISTSIZE=1000
HISTFILESIZE=2000
HISTCONTROL=ignoredups

# History search with up/down arrows
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'

# Basic aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias l='ls -l'

# Source language environment variables
[ -r /etc/profile.d/languages_env ] && . /etc/profile.d/languages_env
