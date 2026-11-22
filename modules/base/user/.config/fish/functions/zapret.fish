function zapret --description 'Zapret service control'
    if test -x /opt/zapret/service.sh
        /opt/zapret/service.sh $argv
    else if test -x ~/.dotfiles/system/zapret/service.sh
        ~/.dotfiles/system/zapret/service.sh $argv
    end
end
