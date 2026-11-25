# Network Bypass & DPI Circumvention Architecture

Unified cross-platform circumvention layer designed for Russian TSPU filtering, providing reliable access to AI services, YouTube, Discord, and games without compromising local `.ru` or Steam speeds.

---

## 1. Linux (Arch / CachyOS) Setup

User-space tools are stowed via `modules/network/user/`, while system services live in `system/network/`.

### Zapret DPI (`zapret-rust`)
Powered by [`Sergeydigl3/zapret-discord-youtube-rust`](https://github.com/Sergeydigl3/zapret-discord-youtube-rust) installed by `./system/setup-system.sh` into `/usr/local/bin/zapret-rust` with shared cache `/var/lib/zapret-rust`:

```fish
# Launch full zapret-rust TUI (Downloader, Strategies, Auto-tune, TTL Finder, Fake Switcher)
zapret

# Pass CLI flags directly
zapret -s general.bat -t -u

# Service control via bypass
bypass zapret status
bypass zapret on
bypass zapret off
bypass zapret list
bypass zapret strategy <name.bat>
```

### Unified Controller (`bypass`)
Located at `~/.local/bin/bypass`:

```fish
# Overview
bypass status

# AmneziaWG & optional Cloudflare WARP (mutually exclusive)
bypass vpn list
bypass vpn add [path/to/profile.conf]   # Opens native file picker if path omitted
bypass vpn on [profile]
bypass vpn switch <profile>
bypass vpn off
bypass vpn warp <status|on|off|register|install>

# Encrypted DNS via Blocky (DoH/DoT) + systemd-resolved (Tailscale & split-DNS preserved)
bypass dns list
bypass dns status
bypass dns monitor                      # Live RFC 8484/7858 wire probes
bypass dns set <provider> [profile_id]

# Strict TLS & Geo-Block Healthchecks + Game Split-Tunnel Verification
bypass test
bypass test --full

# Terminal fzf menu (WM-agnostic)
bypass menu
```

### Polkit Permissions (`system/hardware/40-network-bypass.rules`)
Grants `wheel` users passwordless unit management for `awg-quick@*.service`, `zapret-rust.service`, `blocky.service`, `warp-svc.service`, `game-bypass-routing.service`, and `systemd-resolved.service`.

---

## 2. Windows Setup

Run from PowerShell (self-elevates via UAC):

```powershell
.\system\network\setup-windows-doh.ps1 -List
.\system\network\setup-windows-doh.ps1 -Preset status
.\system\network\setup-windows-doh.ps1 -Preset comss
.\system\network\setup-windows-doh.ps1 -DisableIPv6
.\system\network\setup-windows-doh.ps1 -Preset reset
```
