function mcserverstop --description "Safely stop the Minecraft server"
    set CMD_SCRIPT "$HOME/Projects/minecraft_server/mc-cmd.sh"
    if test -p "$HOME/Projects/minecraft_server/server.fifo"
        $CMD_SCRIPT say "Saving world..."
        $CMD_SCRIPT save-all
        sleep 5
        $CMD_SCRIPT say "Stopping server..."
        $CMD_SCRIPT stop
    else
        echo "Minecraft server does not appear to be running."
    end
end
