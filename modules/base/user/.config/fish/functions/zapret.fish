function zapret --description 'Zapret DPI circumvention TUI and CLI'
    set -lx ZAPRET_CACHE_DIR /var/lib/zapret-rust
    if command -v zapret-rust >/dev/null 2>&1
        zapret-rust $argv
    else if test -x /usr/local/bin/zapret-rust
        /usr/local/bin/zapret-rust $argv
    else if test -x ~/.local/bin/zapret-rust
        ~/.local/bin/zapret-rust $argv
    else
        echo "zapret-rust is not installed. Run ./system/setup-system.sh to install it." >&2
        return 1
    end
end
