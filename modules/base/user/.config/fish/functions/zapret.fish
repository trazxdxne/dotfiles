function zapret --description 'Zapret service control'
    if test -x /opt/zapret/service.sh
        /opt/zapret/service.sh $argv
    else
        cd ~/.dotfiles/modules/network/zapret/ && ./service.sh $argv
    end
end
