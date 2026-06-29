# Antigravity Project Rules

- **Privilege Escalation**: Never run `sudo` directly for commands that require root privileges if they might prompt for a password. Instead, always use `pkexec` (e.g. `pkexec pacman -S ...`) to trigger a graphical polkit authentication dialog, allowing the user to enter their password via a GUI prompt.

- **Git Workflow for Configs**: The user's configurations (Niri, AGS, WezTerm, Fuzzel, GTK, WirePlumber, niri-autostart, system guides, and this rules file) are managed in a centralized Git repository at `~/dotfiles`. Whenever you modify any of these configuration files, you MUST commit the changes inside the `~/dotfiles` directory. Automatically create a concise, English-only git commit without asking for details. Make the commit minimal and purely functional. After committing, either push it automatically or provide the exact command for the user to execute.

- **Dotfiles Symlink Maintenance**: Whenever a new config file is added to `~/dotfiles`, you MUST:
  1. Move the original file into `~/dotfiles/<app>/` (creating the subdirectory if needed).
  2. Create a symlink from the original location pointing to the new dotfiles path.
  3. Add the new symlink to the list in `~/dotfiles/knowledge/Restore_Prompt.md` (under step 4, "Создай симлинки") so the restore prompt stays up-to-date.
  4. Commit all changes (the new file + updated Restore_Prompt.md) to the dotfiles repository in a single commit.
