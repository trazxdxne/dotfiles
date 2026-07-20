source /usr/share/cachyos-fish-config/cachyos-config.fish

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end


# Set default terminal editor
set -gx EDITOR micro
set -gx VISUAL micro

# Aliases
alias nano micro

# Added by Antigravity CLI installer
set -gx PATH "/home/trazxdxne/.local/bin" $PATH

# pnpm
set -gx PNPM_HOME "/home/trazxdxne/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
  set -gx PATH "$PNPM_HOME" $PATH
end
if not string match -q -- "$PNPM_HOME/bin" $PATH
  set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end

