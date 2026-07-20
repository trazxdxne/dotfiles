# Antigravity Project Rules

## Privilege Escalation

`pkexec` gates every command that needs root: package installs (`pkexec pacman -S …`), system-file edits under `/etc/` or `/usr/`, service management (`pkexec systemctl …`), and root-owned artifacts in `~` (Docker volumes, etc.). Everything else runs unprivileged.

## Dotfiles

The repository follows a strict domain structure:
- `~/.config/` and `~/.local/` configs go to `~/dotfiles/.config/` and `~/dotfiles/.local/`.
- `/etc/` and `/usr/` system files go to `~/dotfiles/system/` (requires root).
- Home root files (`~/.bashrc`, etc.) go to `~/dotfiles/<app>/` at the repo root.

### Onboarding a new config

1. Move the original file into the corresponding domain directory in `~/dotfiles/` (e.g., `~/dotfiles/.config/<app>/`).
2. Add the path mapping to `~/dotfiles/modules.toml` under the appropriate module.
3. Commit all changes in a single commit.

**Completion criterion**: the diff shows the new file in the correct domain directory AND `modules.toml` contains the new mapping. Both present — or the step is not done.

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

## Code Style & Comments

- **Zero-comment policy by default:** Do not add explanatory comments to code unless explicitly asked. The code should be self-documenting.
- **Unified language:** If comments must be added (or when modifying existing files with inconsistent comments), ensure all comments are in concise English. Avoid mixing languages (e.g. Russian and English) or varying comment lengths to maintain visual cleanliness.
