---
name: minecraft-server-manager
description: Manage the Fabric server at /home/trazxdxne/Projects/minecraft_server. Use when user wants to sync mods from Prism Launcher, tweak settings, or optimize lag.
---
# Minecraft Server Manager

You manage the local Fabric Minecraft server at `/home/trazxdxne/Projects/minecraft_server`.

## Sync

Sync mods from a Prism Launcher instance to the server.

1. **Locate**: Find the Prism instance in `~/.local/share/ElyPrismLauncher/instances/` (e.g. `Fabulously Optimized(2)/minecraft/`) or `~/.local/share/PrismLauncher/instances/`. Ask the user for the instance name if missing.
2. **Sync**: Rsync `mods/` and `config/` from the Prism instance to the server root.
3. **Filter**: Delete client-only mods from the server `mods/` folder (e.g. Sodium, Iris, ModMenu, Xaero).
- **Completion**: Server `mods/` holds the instance's mods minus client-only additions.

## Tweak

Tweak server configuration.

1. **Edit**: Modify `server.properties` or files in `config/`.
2. **Apply**: Restart the server process via `start.sh` if it is currently running.
- **Completion**: Target settings are written to disk and active.

## Optimize

Optimize server performance and reduce lag.

1. **Audit**: Check `mods/` for server-side optimization mods (Lithium, FerriteCore, Spark). Install them if absent.
2. **Profile**: Read `/spark profiler` output or server logs to identify bottlenecks.
3. **Tune**: Lower `simulation-distance` in `server.properties`, or adjust Aikar's flags in `start.sh`.
- **Completion**: A specific bottleneck is identified and a mitigation is applied.
