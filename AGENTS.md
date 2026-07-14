# Antigravity Project Rules

- **Privilege Escalation**: Use `pkexec` **only** for true system-level operations that require root and would prompt for a password in the terminal — e.g., installing packages (`pkexec pacman -S ...`), editing system files (`/etc/`, `/usr/`), managing system services (`pkexec systemctl ...`), etc. This triggers a graphical polkit dialog instead of a terminal password prompt. Do **not** use `pkexec` for regular development tasks (e.g., `git`, `npm`, creating repos/files in the user's home directory) — those do not need elevated privileges at all.

- **Git Workflow for Configs**: The user's configurations (Niri, AGS, WezTerm, Fuzzel, GTK, WirePlumber, niri-autostart, system guides, and this rules file) are managed in a centralized Git repository at `~/dotfiles`. Whenever you modify any of these configuration files, you MUST commit the changes inside the `~/dotfiles` directory. Automatically create a concise, English-only git commit without asking for details. Make the commit minimal and purely functional. After committing, either push it automatically or provide the exact command for the user to execute.

- **Dotfiles Symlink Maintenance**: Whenever a new config file is added to `~/dotfiles`, you MUST:
  1. Move the original file into `~/dotfiles/<app>/` (creating the subdirectory if needed).
  2. Create a symlink from the original location pointing to the new dotfiles path.
  3. Add the new symlink to the list in `~/dotfiles/knowledge/Restore_Prompt.md` (under step 4, "Создай симлинки") so the restore prompt stays up-to-date.
  4. Commit all changes (the new file + updated Restore_Prompt.md) to the dotfiles repository in a single commit.

- **Documentation & Search Efficiency**: When researching configuration options or troubleshooting:
  1. Prioritize reading local configuration files, local schemas, and local agent skills (like the `niri` skill) first.
  2. If a web search is necessary, immediately check if fetched pages contain loading errors or empty skeletons.
  3. If a page fails to load properly (e.g., GitHub Wiki skeleton pages), DO NOT retry or crawl similar pages. Pivot immediately to other documentation mirrors, source code files, or ask the user directly to minimize step count and token usage.

