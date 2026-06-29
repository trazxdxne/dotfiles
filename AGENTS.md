# Antigravity Project Rules

- **Privilege Escalation**: Never run `sudo` directly for commands that require root privileges if they might prompt for a password. Instead, always use `pkexec` (e.g. `pkexec pacman -S ...`) to trigger a graphical polkit authentication dialog, allowing the user to enter their password via a GUI prompt.

- **Git Workflow for Configs**: Whenever you modify the user's personal configuration files (like AGS, niri, etc.), ALWAYS remind the user to save and push the changes to GitHub. Automatically create a concise, English-only git commit without asking for details. Make the commit minimal and purely functional. After committing, either push it automatically or provide the exact command for the user to execute.
