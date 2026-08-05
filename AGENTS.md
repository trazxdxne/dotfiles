# Antigravity Project Rules

## Privilege Escalation

`pkexec` gates every command that needs root: package installs (`pkexec pacman -S …`), system-file edits under `/etc/` or `/usr/`, service management (`pkexec systemctl …`), and root-owned artifacts in `~` (Docker volumes, etc.). Everything else runs unprivileged.

## Dotfiles

The repository follows a module-based GNU Stow structure located at `~/.dotfiles`:
- User configs go to `~/.dotfiles/modules/<module_name>/user/` (stowed relative to `~`).
- System files go to `~/.dotfiles/modules/<module_name>/root/` (stowed relative to `/`, requires root).

### Onboarding a new config

1. Place the new file in the corresponding module directory:
   - For user configs: `~/.dotfiles/modules/<module_name>/user/` mirroring its target path (e.g., `modules/base/user/.config/<app>/...` or `modules/base/user/.bashrc`).
   - For system configs: `~/.dotfiles/modules/<module_name>/root/` mirroring its root target path (e.g., `modules/greeter/root/etc/greetd/config.toml`).
2. Run `install.sh` or `stow -R` to apply symlinks.
3. Commit all changes in a single commit.

**Completion criterion**: the file exists in the module's `user` or `root` stow directory and symlinks cleanly with GNU Stow.

### Committing changes

Commit when a **coherent unit of work** is complete — the full task the user asked for, not individual fixes along the way. One atomic commit per logical change. After committing, `git push`.

- Commit message: one line, English, imperative mood.
- Good: `Add wezterm config` — Bad: `Added wezterm configuration files to the dotfiles repository`
- Scope: `~/.dotfiles` directory only.

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
