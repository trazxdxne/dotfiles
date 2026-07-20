# Antigravity Project Rules

## Privilege Escalation

`pkexec` gates every command that needs root: package installs (`pkexec pacman -S …`), system-file edits under `/etc/` or `/usr/`, service management (`pkexec systemctl …`), and root-owned artifacts in `~` (Docker volumes, etc.). Everything else runs unprivileged.

## Dotfiles

User configurations live in the Git repository `~/dotfiles`. Configs reach the system via symlinks.

### Onboarding a new config

1. Move the original file into `~/dotfiles/<app>/` (create the subdirectory if needed).
2. Create a symlink: original location → `~/dotfiles/<app>/<file>`.
3. Add the new symlink line to `~/dotfiles/knowledge/Restore_Prompt.md`, under step 4 ("Создай симлинки").
4. Commit all changes in a single commit.

**Completion criterion**: the diff shows the new file in `~/dotfiles/` AND Restore_Prompt.md contains the new symlink line. Both present — or the step is not done.

### Committing changes

Commit when a **coherent unit of work** is complete — the full task the user asked for, not individual fixes along the way. One atomic commit per logical change. After committing, `git push`.

- Commit message: one line, English, imperative mood.
- Good: `Add wezterm config` — Bad: `Added wezterm configuration files to the dotfiles repository`
- Scope: `~/dotfiles` directory only.

## Package Management

| Source | Command | Notes |
|--------|---------|-------|
| Official repos | `pkexec pacman -S --noconfirm …` | Default choice |
| AUR (rare) | `yay -S …` | No pkexec. Only when the package is absent from official repos |

## Web Research

**Bail-fast**: if a fetched page returns empty, a JS skeleton, or a load error — pivot to another source or ask the user. Never retry broken pages.
