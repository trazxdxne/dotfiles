function bypass --description 'Unified Network Bypass & DPI Control'
    if test -x ~/.local/bin/bypass
        ~/.local/bin/bypass $argv
    else
        command bypass $argv
    end
end
