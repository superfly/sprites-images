# Default zsh configuration for sprite
# This prevents the zsh-newuser-install prompt

# Enable command completion
autoload -Uz compinit && compinit

# Set terminal title to show current directory
precmd() {
    print -Pn "\e]0;%~\a"
}

# Set a simple but nice prompt with colors
PROMPT='%F{green}%n@%m%f:%F{blue}%~%f%# '

# Enable color output
export CLICOLOR=1

# Basic key bindings (emacs style)
bindkey -e

# History settings
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# History search with up/down arrows
autoload -Uz history-search-end
zle -N history-beginning-search-backward-end history-search-end
zle -N history-beginning-search-forward-end history-search-end
bindkey '^[[A' history-beginning-search-backward-end  # Up arrow
bindkey '^[[B' history-beginning-search-forward-end   # Down arrow

# Basic aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias l='ls -l'

# Source language environment variables
[ -r /etc/profile.d/languages_env ] && . /etc/profile.d/languages_env
