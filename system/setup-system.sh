#!/usr/bin/env bash
# Standalone System Configuration Deployer (Root / Opt-in)
# Use this script ONLY when configuring base system services on Arch / CachyOS.
set -euo pipefail

if [[ "$EUID" -ne 0 ]]; then
    printf ":: requesting root privileges\n"
    exec pkexec "$0" "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

printf ":: deploying system network configurations\n"
if [[ -f "$SCRIPT_DIR/network/malw-dns.conf" ]]; then
    mkdir -p /etc/systemd/resolved.conf.d
    install -Dm644 "$SCRIPT_DIR/network/malw-dns.conf" /etc/systemd/resolved.conf.d/malw-dns.conf
fi

if [[ -f "$SCRIPT_DIR/network/game-bypass-routing.sh" ]]; then
    install -Dm755 "$SCRIPT_DIR/network/game-bypass-routing.sh" /usr/local/bin/game-bypass-routing.sh
fi

if [[ -f "$SCRIPT_DIR/network/game-bypass-routing.service" ]]; then
    install -Dm644 "$SCRIPT_DIR/network/game-bypass-routing.service" /etc/systemd/system/game-bypass-routing.service
    systemctl daemon-reload
    systemctl enable game-bypass-routing.service || true
fi

if [[ -f "$SCRIPT_DIR/network/awg0.conf" ]]; then
    if ! command -v awg-quick &>/dev/null; then
        printf ":: installing amneziawg-tools and amneziawg-dkms\n"
        pacman -S --needed --noconfirm amneziawg-tools amneziawg-dkms || true
    fi
    mkdir -p /etc/amnezia/amneziawg
    install -Dm600 "$SCRIPT_DIR/network/awg0.conf" /etc/amnezia/amneziawg/awg0.conf
fi

if [[ -f /etc/gai.conf ]]; then
    sed -i 's/^#precedence ::ffff:0:0\/96  100/precedence ::ffff:0:0\/96  100/' /etc/gai.conf
fi

printf ":: deploying hardware, polkit, and oomd rules\n"
mkdir -p /etc/polkit-1/rules.d /etc/sysctl.d /etc/modprobe.d /etc/systemd/system/user@.service.d

[[ -f "$SCRIPT_DIR/hardware/10-power.rules" ]] && install -Dm644 "$SCRIPT_DIR/hardware/10-power.rules" /etc/polkit-1/rules.d/10-power.rules
[[ -f "$SCRIPT_DIR/hardware/20-noctalia-greeter.rules" ]] && install -Dm644 "$SCRIPT_DIR/hardware/20-noctalia-greeter.rules" /etc/polkit-1/rules.d/20-noctalia-greeter.rules
[[ -f "$SCRIPT_DIR/hardware/30-wakealarm.rules" ]] && install -Dm644 "$SCRIPT_DIR/hardware/30-wakealarm.rules" /etc/polkit-1/rules.d/30-wakealarm.rules
[[ -f "$SCRIPT_DIR/hardware/99-tailscale.conf" ]] && install -Dm644 "$SCRIPT_DIR/hardware/99-tailscale.conf" /etc/sysctl.d/99-tailscale.conf
[[ -f "$SCRIPT_DIR/hardware/v4l2loopback.conf" ]] && install -Dm644 "$SCRIPT_DIR/hardware/v4l2loopback.conf" /etc/modprobe.d/v4l2loopback.conf
[[ -f "$SCRIPT_DIR/hardware/10-oomd-user-service.conf" ]] && install -Dm644 "$SCRIPT_DIR/hardware/10-oomd-user-service.conf" /etc/systemd/system/user@.service.d/10-oomd-user-service.conf

if [[ -f "$SCRIPT_DIR/greeter/greetd-config.toml" ]]; then
    mkdir -p /etc/greetd
    install -Dm644 "$SCRIPT_DIR/greeter/greetd-config.toml" /etc/greetd/config.toml
fi

systemctl daemon-reload
printf ":: system deployment complete\n"
