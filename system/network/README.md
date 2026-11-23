# Network Bypass & DPI Circumvention Architecture

Unified cross-platform circumvention layer designed for modern Russian network filtering (TSPU / ТСПУ), providing reliable access to AI services (Google Gemini, Google AI Studio, ChatGPT, Claude, Antigravity CLI), streaming media (YouTube, Discord voice/media), and gaming platforms while keeping domestic `.ru` sites and Steam at full local speed.

---

## 1. Linux (Arch / CachyOS) Setup

The Linux architecture operates unprivileged via GNU Stow (`modules/network/user/`) with system services managed under `system/network/`.

### Core Tool: `bypass` CLI
Located in `~/.local/bin/bypass` (added to `$PATH`):

```fish
# Full status
bypass status

# AmneziaWG VPN management
bypass vpn status
bypass vpn on [profile]
bypass vpn off
bypass vpn switch <profile>
bypass vpn list

# Zapret DPI circumvention daemon
bypass zapret status
bypass zapret on
bypass zapret off
bypass zapret strategy <name>
bypass zapret list

# DNS management & live monitor
bypass dns status
bypass dns list
bypass dns monitor
bypass dns set <provider> [profile_id]

# Automated health checks
bypass test
bypass test --full

# Auto-benchmark Zapret strategies against YouTube & Discord
bypass tune

# Interactive TUI / GUI menu (or press Mod+Shift+V in Niri)
bypass menu
```

### Zapret Strategies (`system/network/zapret-strategies/`)
Clean, modular `.conf` presets deployed to `/etc/bypass/strategies/`:
- `discord_youtube.conf` — MultiSplit + SeqOvl (proven for Discord voice/gateway and YouTube video playback).
- `general_fake.conf` — Lightweight fake packet injection with TCP timestamp fooling.
- `general_alt.conf` — MultiSplit with split-seqovl 681 and fake repeats.
- `general_multisplit.conf` — Pure multisplit without fake packets.
- `minecraft_hypixel.conf` — Low-latency game packet bypass.

### DNS Presets (`system/network/dns/`)
21 selectable presets with opportunistic DoT via `systemd-resolved`:
- **AI & SmartDNS Providers:** `comss`, `comss-alt`, `magicdns`, `bezmezhau`, `geohide-ru`, `geohide-eu`, `geohide-us`, `malw`, `dagami`, `dns-ai`, `zapret-dns`, `nextdns`.
- **Privacy & Security:** `controld`, `mullvad`, `cloudflare`, `quad9`, `adguard`.
- **Gaming & Domestic:** `nulls-proxy`, `xbox-dns`, `isp`.

### Polkit Permissions (`system/hardware/40-network-bypass.rules`)
Grants passwordless control over `awg-quick@*.service`, `zapret.service`, `game-bypass-routing.service`, and `systemd-resolved.service`.

---

## 2. Windows Setup

On Windows, Russian ISPs intercept or drop unencrypted UDP port 53 packets to public resolvers, which causes **7+ second timeouts** on Steam, games, and `.ru` domains when using manual DNS.

To solve this, Windows uses **DNS-over-HTTPS (DoH)**, which encrypts queries over HTTPS (port 443), preventing ISP drops while unblocking AI Studio, Gemini, and ChatGPT.

### Windows DoH Configuration Script (`setup-windows-doh.ps1`)

Run from PowerShell (automatically prompts for elevation if not already Admin):

```powershell
# List all 16 available SmartDNS presets from dns-conf-ui
.\system\network\setup-windows-doh.ps1 -List

# Check current DNS, DoH, and IPv6 leak status
.\system\network\setup-windows-doh.ps1 -Preset status

# Apply DNS-AI DoH (Recommended for Google Gemini & AI Studio)
.\system\network\setup-windows-doh.ps1 -Preset dns-ai

# Apply Comss DoH
.\system\network\setup-windows-doh.ps1 -Preset comss

# Apply GeoHide EU (European egress proxy)
.\system\network\setup-windows-doh.ps1 -Preset geohide-eu

# Apply Malw DNS (DE egress proxy)
.\system\network\setup-windows-doh.ps1 -Preset malw

# Disable IPv6 to prevent Russian ISP IPv6 geo-leak to Google services
.\system\network\setup-windows-doh.ps1 -DisableIPv6

# Reset DNS to automatic (DHCP / Router)
.\system\network\setup-windows-doh.ps1 -Preset reset
```

### Manual Configuration via Windows Settings
1. Open **Settings** → **Network & Internet** → **Ethernet** (or Wi-Fi).
2. Click **Edit** next to *DNS server assignment*.
3. Choose **Manual** → Enable **IPv4**:
   - **Preferred DNS:** `93.115.24.204`
   - **DNS Encryption:** Select **Encrypted only (DNS over HTTPS)**
   - **DoH Template:** `https://dns.comss.one/dns-query`
   - **Alternate DNS:** `93.115.24.205`
   - **DNS Encryption:** Select **Encrypted only (DNS over HTTPS)**
   - **DoH Template:** `https://dns.comss.one/dns-query`
4. Click **Save**.

### Antigravity CLI Compatibility on Windows
- Antigravity CLI binary `agy.exe` and `language_server.exe` are patched via `eligibility-antigravity-patcher`.
- With Comss DoH configured, both Google AI Studio web interfaces (`aistudio.google.com`) and Antigravity CLI connect at full speed without regional errors.
