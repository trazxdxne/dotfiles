# Antigravity Project Rules

## Architecture & Philosophy (Lean User Overlay)

The repository (`~/.dotfiles`) targets **Arch-based distributions (CachyOS, Arch, Omarchy)** with a pure, unprivileged user-space overlay philosophy:

- **`modules/<name>/user/`** — Personal user configurations stowed relative to `~` via GNU Stow (`install.sh`).
- **`system/`** — Opt-in system-level configurations (`/etc`, systemd units, polkit rules, hardware quirks, and network bypass) deployed via `system/setup-system.sh` only when performing full machine setup.

### Principles

1. **Unprivileged by default:** Dotfiles installation (`./install.sh`) must run completely unprivileged without `sudo` or background root keepalive processes.
2. **Zero inline compilation:** Avoid heavy cargo or pnpm builds during routine dotfile deployment.
3. **Omarchy & CachyOS compatibility:** Keep user configs compatible with both Niri and Hyprland (Omarchy).
4. **Native window management:** Use compositor-native window rules and autostart (`spawn-at-startup` in Niri, `exec-once` and `windowrulev2` in Hyprland) instead of external wrapper daemons.

## Privilege Escalation

- **Interactive agent commands:** `pkexec` gates standalone commands that require root (e.g. system package installation, service management under `/etc/systemd/system/`). Everything else runs unprivileged.
- **System setup:** Root operations are isolated in `system/setup-system.sh` and never intermingled with user dotfile symlinking.

## Committing Changes

Commit when a **coherent unit of work** is complete — one atomic commit per logical change. After committing, `git push`.

- Commit message: one line, English, imperative mood.
- Scope: `~/.dotfiles` directory only.

## Code Style & Comments

- **Zero-comment policy by default:** Do not add explanatory comments to code unless explicitly asked. The code should be self-documenting.
- **Unified language:** All comments must be in concise English. Avoid mixing languages or varying comment lengths to maintain visual cleanliness.
