function mcserver --wraps='cd Projects/minecraft_server/ && ./start.sh' --description 'alias mcserver=cd Projects/minecraft_server/ && ./start.sh'
    cd Projects/minecraft_server/ && ./start.sh $argv
end
