---
name: minecraft-server-manager
description: 'Manage Fabric Minecraft servers under /home/trazxdxne/Projects/ (default: /home/trazxdxne/Projects/minecraft_server). Use when user wants to sync mods, tweak settings, optimize lag, or update server README journals.'
---
# Minecraft Server Manager

You manage local Fabric Minecraft servers in `/home/trazxdxne/Projects/`.
Default server directory: `/home/trazxdxne/Projects/minecraft_server`.

If the user mentions another server directory (e.g. `~/Projects/<server_name>`), locate and use that target server directory `<server_root>` instead.

## Sync

Sync mods from a Prism Launcher instance to the target server `<server_root>`.

1. **Locate**: Find the Prism instance in `~/.local/share/ElyPrismLauncher/instances/` (e.g. `Fabulously Optimized/minecraft/`) or `~/.local/share/PrismLauncher/instances/`. Ask the user for the instance name if missing.
2. **Sync**: Rsync `mods/` and `config/` from the Prism instance to `<server_root>`.
3. **Filter**: Delete client-only mods from `<server_root>/mods/` folder (e.g. Sodium, Iris, ModMenu, Xaero).
- **Completion**: Target server `mods/` holds the instance's mods minus client-only additions.

## Tweak

Tweak server configuration.

1. **Edit**: Modify `<server_root>/server.properties` or files in `<server_root>/config/`.
2. **Apply**: Check if the server is running.
   - **Detect**: Find the process using `pgrep -a java | grep fabric-server-launch.jar`.
   - **Restart**: NEVER restart the server automatically. If it is running, explicitly ask the user to restart it manually via their console.
- **Completion**: Target settings are written to disk and active.

## Optimize

Optimize server performance and reduce lag.

1. **Audit**: Check `<server_root>/mods/` for server-side optimization mods (Lithium, FerriteCore, Spark). Install them if absent.
2. **Profile**: Read `/spark profiler` output or server logs to identify bottlenecks.
3. **Tune**: Lower `simulation-distance` in `server.properties`, or adjust Aikar's flags in `start.sh`.
- **Completion**: A specific bottleneck is identified and a mitigation is applied.

## Documentation & Day Counting

Maintain server documentation and inspect world progress on demand.

1. **Day Counter Capability**: When requested or updating documentation, calculate current in-game days by parsing `DayTime` from `<server_root>/world/level.dat` (`DayTime // 24000`) using Python.
2. **Update README**: When asked to update documentation or after major server changes, update `<server_root>/README.md` to reflect day count, mods, player list, or server configs. Maintain a warm, human-friendly journal style with tasteful emojis, without cheesy slogans. Preserve exact user modifications (e.g. player list mappings such as `trazxdxne`: Я, `dyrasosy`: Яна, and custom server status fields).
- **Completion**: `<server_root>/README.md` is updated on request with accurate day count and server state, preserving custom user edits.
