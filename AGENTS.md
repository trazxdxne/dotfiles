# Antigravity Project Rules

## Privilege Escalation

- **Interactive agent commands:** `pkexec` gates every standalone command the agent runs that needs root: package installs, system-file edits under `/etc/` or `/usr/`, service management (`pkexec systemctl …`), and root-owned artifacts in `~`. Everything else runs unprivileged.
- **Inside `install.sh`:** Authenticate once via `sudo -v < /dev/tty` (explicitly binding to `/dev/tty` so TUI tools like `gum` never starve `stdin`) and keep the timestamp alive, or batch root operations into a single `pkexec` invocation.

## Dotfiles Architecture (Arch & Fedora)

The repository (`~/.dotfiles`) is cross-distro (Arch Linux and Fedora) and follows a module-based structure under `~/.dotfiles/modules/<module_name>/`:

- **`user/`** — User configs (stowed relative to `~` via GNU Stow).
- **`root/`** — Common system files (copied to `/`, never symlinked).
- **`root-arch/` & `root-fedora/`** — Distro-specific system files (e.g., `mkinitcpio`, `pacman`, PAM, boot/initramfs). Never place distro-specific `/etc/pam.d/`, `/etc/security/`, or bootloader configs into common `root/`.

### Deploying configs (`user/` vs `root/`)

1. **User configs (`user/`):** Mirror target path relative to `~` (e.g., `modules/base/user/.config/<app>/...`) and symlink via `stow -R`.
2. **System configs (`root/`, `root-arch/`, `root-fedora/`):** Mirror target path relative to `/` (e.g., `modules/greeter/root/etc/greetd/config.toml`). Deploy by **copying** (`install` or `cp -r` with `chown root:root` and `.bak` backup of existing files). Never symlink `/etc` or `/usr` to `~` (breaks Fedora SELinux `user_home_t`).
3. **SELinux context restoration:** On Fedora (or whenever `restorecon` exists), run `restorecon -Rv` on every modified path under `/etc/`, `/usr/`, `/opt/`, or `/var/` after copying files or placing custom binaries (`nfqws`, `zapret` scripts, systemd units).

**Completion criterion**: `user/` files symlink cleanly with GNU Stow; `root*` files copy cleanly with `root:root` ownership and valid `restorecon` contexts (`etc_t`, `bin_t`, `systemd_unit_file_t`).

### Committing changes

Commit when a **coherent unit of work** is complete — the full task the user asked for, not individual fixes along the way. One atomic commit per logical change. After committing, `git push`.

- Commit message: one line, English, imperative mood.
- Good: `Separate Arch and Fedora root configs` — Bad: `Fixed black screen and SELinux issues on Fedora`
- Scope: `~/.dotfiles` directory only.

## Package Management

Detect the active distribution via `/etc/os-release` before running package commands:

| Distro / Source | Command | Notes |
|-----------------|---------|-------|
| Arch (Official) | `pkexec pacman -S --noconfirm …` | Default on Arch |
| Arch (AUR) | `yay -S …` | No `pkexec`. Only when absent from official repos |
| Fedora | `pkexec dnf install -y …` | Default on Fedora |

## Web Research

**Bail-fast**: if a fetched page returns empty, a JS skeleton, or a load error — pivot to another source or ask the user. Never retry broken pages.

## Code Style & Comments

- **Zero-comment policy by default:** Do not add explanatory comments to code unless explicitly asked. The code should be self-documenting.
- **Unified language:** If comments must be added (or when modifying existing files with inconsistent comments), ensure all comments are in concise English. Avoid mixing languages (e.g. Russian and English) or varying comment lengths to maintain visual cleanliness.
