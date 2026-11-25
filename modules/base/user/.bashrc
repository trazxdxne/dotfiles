#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# Set default terminal editor
if command -v fresh &> /dev/null; then
    export EDITOR=fresh
    export VISUAL=fresh
    alias nano=fresh
elif command -v micro &> /dev/null; then
    export EDITOR=micro
    export VISUAL=micro
    alias nano=micro
fi

# Aliases
if command -v zapret-rust &> /dev/null; then
    alias zapret="ZAPRET_CACHE_DIR=/var/lib/zapret-rust zapret-rust"
fi

# Local bin
export PATH="$HOME/.local/bin:$PATH"

# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
case ":$PATH:" in
  *":$PNPM_HOME/bin:"*) ;;
  *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac
# pnpm end
