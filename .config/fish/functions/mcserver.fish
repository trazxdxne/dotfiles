function mcserver --wraps='cd Projects/minecraft_server/ && ./start.sh' --wraps='cd && cd Projects/minecraft_server/ && ./start.sh' --description 'alias mcserver=cd && cd Projects/minecraft_server/ && ./start.sh'
    cd && cd Projects/minecraft_server/ && ./start.sh $argv
end
