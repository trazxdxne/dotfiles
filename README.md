# dotfiles

Personal configurations, system overlays, and network bypass infrastructure for Arch Linux / CachyOS (Niri, Hyprland, Fish) and Windows.

---

## Architecture

This repository follows a strict **unprivileged user overlay** architecture:

- **`modules/<name>/user/`** — User configurations symlinked to `~` via GNU Stow.
- **`system/`** — Opt-in system services (`/etc`, systemd units, polkit rules, network bypass).
- **`system/network/`** — Network bypass, DPI circumvention, SmartDNS catalog, and Windows DoH scripts.

---

## Quick Start

### Arch Linux / CachyOS

```bash
# Clone
git clone https://github.com/trazxdxne/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Deploy user modules (unprivileged)
./install.sh -a -p

# Deploy system services & polkit rules (one-time, root)
./system/setup-system.sh
```

### Windows (DNS & AI Setup)

To fix slow Steam / `.ru` sites and unblock Google AI Studio, Gemini, and Antigravity:

```powershell
# Run from PowerShell (self-elevates via UAC prompt)
.\system\network\setup-windows-doh.ps1 -Preset comss

# Check status
.\system\network\setup-windows-doh.ps1 -Preset status
```

---

## Documentation

- [Network Bypass Architecture (Linux & Windows)](system/network/README.md)
- [Modules Manifest](modules.toml)
- [Agent Rules & Guidelines](AGENTS.md)
