---
name: minecraft-server-manager
description: Manage Fabric Minecraft servers, sync mods, tweak commented configs, optimize performance, verify rustic backups, or update server README journals under /home/trazxdxne/Projects/.
---

# Minecraft Server Manager

Manage local Fabric Minecraft servers in `/home/trazxdxne/Projects/` (default: `/home/trazxdxne/Projects/minecraft_server`).
If the user specifies a custom server path (e.g. `~/Projects/<server_name>`), set `<server_root>` to that path.
Default rustic repository: `/home/trazxdxne/Games/minecraft_server/rustic-repo`.

## Commented Edits Policy

Always add concise English comments (`# Comment`) above or inline with any configuration settings, properties, or shell script lines created or modified in `<server_root>` detailing the rationale for the change.

- **Completion**: Every modified or added setting in `<server_root>` files includes an explicit comment detailing the rationale.

## Rustic Backup & Verification

Verify rustic backup repository integrity and manage backups or restores.

1. **Verify**: Check rustic repository snapshots before major operations (restores, mod syncs, config overhauls):
   ```bash
   export RUSTIC_PASSWORD=""; rustic -r ~/Games/minecraft_server/rustic-repo snapshots
   ```
2. **Manual Backup**: Execute `~/Projects/minecraft_server/backup.sh` to pause world saves (`save-off`, `save-all flush`), run rustic backup, prune retention policies, resume saves (`save-on`), and rclone sync to Google Drive.
3. **Check Service**: Inspect `systemctl --user status minecraft-backup.timer` or `journalctl --user -u minecraft-backup.service` for backup schedule status.
4. **Restore**: Stop server process, verify available rustic snapshots, and restore target snapshot:
   ```bash
   export RUSTIC_PASSWORD=""; rustic -r ~/Games/minecraft_server/rustic-repo restore <snapshot-id> --target ~/Projects/minecraft_server
   ```
- **Completion**: Rustic snapshots are verified present and accessible, or backup/restore process completes without error.

## Sync

Sync mods from a Prism Launcher instance to `<server_root>`.

1. **Locate**: Find Prism instance in `~/.local/share/ElyPrismLauncher/instances/` or `~/.local/share/PrismLauncher/instances/`. Ask user for instance name if missing.
2. **Verify Backup**: Confirm rustic snapshots are intact before performing full mod sync.
3. **Sync**: Rsync `mods/` and `config/` from Prism instance to `<server_root>`.
4. **Filter**: Delete client-only mods from `<server_root>/mods/` (e.g. Sodium, Iris, ModMenu, Xaero).
- **Completion**: Target `<server_root>/mods/` contains instance mods minus client-only additions after rustic backup check.

## Tweak

Tweak server settings and configuration files.

1. **Verify Backup**: Check rustic backup snapshots prior to editing key configs.
2. **Edit**: Modify `<server_root>/server.properties` or files in `<server_root>/config/`. Follow the **Commented Edits Policy** by placing `# Comment` lines above modified values explaining the change.
3. **Apply**: Detect running server via `pgrep -a java | grep fabric-server-launch.jar`. Ask the user to restart manually if running (never auto-restart).
- **Completion**: Modified settings are written to disk with explanatory comments, and rustic backup state is verified.

## Optimize

Optimize server performance and reduce tick lag.

1. **Audit**: Check `<server_root>/mods/` for optimization mods (Lithium, FerriteCore, Spark). Install missing mods.
2. **Profile**: Analyze `/spark profiler` output or server logs for tick bottlenecks.
3. **Tune**: Lower `simulation-distance` in `server.properties` or adjust JVM flags in `start.sh`. Annotate tuned options with explanatory `# Comment` lines.
- **Completion**: Bottleneck is identified, tuned parameters have explanatory comments, and changes are written to disk.

## Documentation & Day Counting

Maintain server documentation and journal updates.

1. **Day Counter**: Parse `DayTime` from `<server_root>/world/level.dat` (`DayTime // 24000`) using Python.
2. **Update README**: Update `<server_root>/README.md` with current day count, mod list, player mappings (e.g. `trazxdxne`: Я, `dyrasosy`: Яна), and server status. Maintain a warm journal style with emojis, preserving existing user edits and custom mappings.
- **Completion**: `<server_root>/README.md` reflects accurate day count and server state while preserving custom user mappings.
