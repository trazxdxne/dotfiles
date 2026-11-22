function zapret --description 'Zapret DPI circumvention control'
    if command -v bypass >/dev/null 2>&1
        bypass zapret $argv
    else if test -x ~/.local/bin/bypass
        ~/.local/bin/bypass zapret $argv
    else if test -x /usr/local/bin/zapret-runner.sh
        /usr/local/bin/zapret-runner.sh $argv
    end
end
