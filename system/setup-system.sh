#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    printf ":: requesting root privileges\n"
    exec pkexec "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZAPRET_CACHE_DIR="/var/lib/zapret-rust"
ZAPRET_RUST_URL="https://github.com/Sergeydigl3/zapret-discord-youtube-rust/releases/latest/download/zapret-rust-linux-x86_64"

printf ":: deploying system network configurations\n"
mkdir -p /etc/systemd/resolved.conf.d /etc/blocky /etc/systemd/system/blocky.service.d /etc/amnezia/amneziawg "$ZAPRET_CACHE_DIR"

if systemctl is-active --quiet zapret.service 2>/dev/null; then
    systemctl stop zapret.service || true
fi
systemctl disable zapret.service 2>/dev/null || true
rm -f /etc/systemd/system/zapret.service /usr/local/bin/zapret-runner.sh

if [[ ! -x /usr/local/bin/zapret-rust ]] || [[ "${1:-}" == "--update-zapret" ]]; then
    printf ":: downloading zapret-rust binary\n"
    tmp_bin="$(mktemp)"
    if curl -fsSL "$ZAPRET_RUST_URL" -o "$tmp_bin"; then
        install -Dm755 "$tmp_bin" /usr/local/bin/zapret-rust
    else
        printf "warning: failed to download zapret-rust from %s\n" "$ZAPRET_RUST_URL" >&2
    fi
    rm -f "$tmp_bin"
fi

if [[ -f "$SCRIPT_DIR/network/zapret-rust.service" ]]; then
    install -Dm644 "$SCRIPT_DIR/network/zapret-rust.service" /etc/systemd/system/zapret-rust.service
fi

if ! command -v blocky &>/dev/null; then
    printf ":: installing blocky DNS proxy\n"
    if pacman -Si blocky &>/dev/null; then
        pacman -S --needed --noconfirm blocky || true
    elif [[ -n "${SUDO_USER:-}" ]] && command -v yay &>/dev/null; then
        su - "$SUDO_USER" -c "yay -S --needed --noconfirm blocky" || true
    elif [[ -n "${PKEXEC_UID:-}" ]] && command -v yay &>/dev/null; then
        pk_user="$(id -nu "$PKEXEC_UID" 2>/dev/null || true)"
        [[ -n "$pk_user" ]] && su - "$pk_user" -c "yay -S --needed --noconfirm blocky" || true
    fi
fi

if [[ -f "$SCRIPT_DIR/network/blocky-default.yml" ]] && [[ ! -f /etc/blocky/blocky.yml ]]; then
    install -Dm644 "$SCRIPT_DIR/network/blocky-default.yml" /etc/blocky/blocky.yml
fi
if [[ -f /etc/blocky/blocky.yml ]] && [[ ! -e /etc/blocky/config.yml ]]; then
    ln -sf /etc/blocky/blocky.yml /etc/blocky/config.yml
fi

cat << 'EOF' > /etc/systemd/system/blocky.service.d/override.conf
[Service]
ExecStart=
ExecStart=/usr/bin/blocky --config /etc/blocky/blocky.yml
EOF

if [[ ! -f /etc/systemd/resolved.conf.d/bypass-dns.conf ]]; then
    cat << 'EOF' > /etc/systemd/resolved.conf.d/bypass-dns.conf
[Resolve]
DNS=127.0.0.1
Domains=~.
DNSOverTLS=no
EOF
fi

if [[ -f "$SCRIPT_DIR/network/game-bypass-routing.sh" ]]; then
    install -Dm755 "$SCRIPT_DIR/network/game-bypass-routing.sh" /usr/local/bin/game-bypass-routing.sh
fi

if [[ -f "$SCRIPT_DIR/network/game-bypass-routing.service" ]]; then
    install -Dm644 "$SCRIPT_DIR/network/game-bypass-routing.service" /etc/systemd/system/game-bypass-routing.service
    systemctl daemon-reload
    systemctl enable game-bypass-routing.service || true
fi

if ! command -v awg-quick &>/dev/null; then
    printf ":: installing amneziawg-tools and amneziawg-dkms\n"
    pacman -S --needed --noconfirm amneziawg-tools amneziawg-dkms || true
fi
if ! command -v resolvconf &>/dev/null; then
    printf ":: installing systemd-resolvconf\n"
    pacman -S --needed --noconfirm systemd-resolvconf || true
fi

if [[ -f /etc/gai.conf ]]; then
    sed -i 's/^#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' /etc/gai.conf
fi

printf ":: deploying hardware, polkit, and oomd rules\n"
mkdir -p /etc/polkit-1/rules.d /etc/sysctl.d /etc/modprobe.d /etc/systemd/system/user@.service.d

[[ -f "$SCRIPT_DIR/hardware/10-power.rules" ]] && install -Dm644 "$SCRIPT_DIR/hardware/10-power.rules" /etc/polkit-1/rules.d/10-power.rules
[[ -f "$SCRIPT_DIR/hardware/20-noctalia-greeter.rules" ]] && install -Dm644 "$SCRIPT_DIR/hardware/20-noctalia-greeter.rules" /etc/polkit-1/rules.d/20-noctalia-greeter.rules
[[ -f "$SCRIPT_DIR/hardware/30-wakealarm.rules" ]] && install -Dm644 "$SCRIPT_DIR/hardware/30-wakealarm.rules" /etc/polkit-1/rules.d/30-wakealarm.rules
[[ -f "$SCRIPT_DIR/hardware/40-network-bypass.rules" ]] && install -Dm644 "$SCRIPT_DIR/hardware/40-network-bypass.rules" /etc/polkit-1/rules.d/40-network-bypass.rules
[[ -f "$SCRIPT_DIR/hardware/99-tailscale.conf" ]] && install -Dm644 "$SCRIPT_DIR/hardware/99-tailscale.conf" /etc/sysctl.d/99-tailscale.conf
[[ -f "$SCRIPT_DIR/hardware/v4l2loopback.conf" ]] && install -Dm644 "$SCRIPT_DIR/hardware/v4l2loopback.conf" /etc/modprobe.d/v4l2loopback.conf
[[ -f "$SCRIPT_DIR/hardware/10-oomd-user-service.conf" ]] && install -Dm644 "$SCRIPT_DIR/hardware/10-oomd-user-service.conf" /etc/systemd/system/user@.service.d/10-oomd-user-service.conf

if [[ -f "$SCRIPT_DIR/greeter/greetd-config.toml" ]]; then
    mkdir -p /etc/greetd
    install -Dm644 "$SCRIPT_DIR/greeter/greetd-config.toml" /etc/greetd/config.toml
fi

systemctl daemon-reload
systemctl enable --now systemd-resolved.service 2>/dev/null || true
if command -v blocky &>/dev/null; then
    systemctl enable --now blocky.service 2>/dev/null || true
fi
printf ":: system deployment complete\n"
