function reposync --description 'Cross-OS Git sync status and helper'
    if test -x ~/.local/bin/reposync
        ~/.local/bin/reposync $argv
    else
        python3 ~/.local/bin/reposync $argv
    end
end
