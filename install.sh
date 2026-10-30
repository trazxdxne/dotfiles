#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
    echo "error: please run as a normal user, not root" >&2
    exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
else
    echo "error: /etc/os-release missing" >&2
    exit 1
fi

case "$DISTRO_ID $DISTRO_LIKE" in
    *arch*|*cachyos*|*endeavouros*|*manjaro*)
        DISTRO="arch"
        ;;
    *fedora*|*nobara*)
        DISTRO="fedora"
        ;;
    *)
        echo "error: unsupported distribution: $DISTRO_ID" >&2
        exit 1
        ;;
esac
echo ":: detected distro: $DISTRO ($DISTRO_ID)"

rollback_network() {
    echo ":: rolling back network and dns configurations"
    if [[ -f /etc/resolv.conf.bak ]]; then
        sudo cp -f /etc/resolv.conf.bak /etc/resolv.conf
        sudo rm -f /etc/resolv.conf.bak
        echo ":: restored /etc/resolv.conf from backup"
    elif [[ -L /etc/resolv.conf ]]; then
        sudo rm -f /etc/resolv.conf
    fi
    sudo rm -f /etc/systemd/resolved.conf.d/malw-dns.conf
    sudo rm -f /etc/NetworkManager/conf.d/systemd-resolved.conf
    if [[ "$DISTRO" == "arch" ]]; then
        sudo systemctl disable --now systemd-resolved 2>/dev/null || true
        sudo systemctl restart NetworkManager 2>/dev/null || true
    elif [[ "$DISTRO" == "fedora" ]]; then
        sudo systemctl restart systemd-resolved NetworkManager 2>/dev/null || true
    fi
    sudo systemctl disable --now zapret_discord_youtube.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/zapret_discord_youtube.service
    sudo systemctl daemon-reload
    if [[ -x /opt/zapret/service.sh ]]; then
        sudo /opt/zapret/service.sh kill 2>/dev/null || true
    fi
    if command -v nft &>/dev/null; then
        sudo nft delete table inet zapret 2>/dev/null || true
    fi
    sudo rm -rf /opt/zapret /usr/local/bin/zapret
    echo ":: network rollback completed successfully"
}

if [[ "${1:-}" == "--rollback-network" ]]; then
    echo ":: authenticating sudo for rollback"
    # shellcheck disable=SC2024
    sudo -v < /dev/tty
    rollback_network
    exit 0
fi

echo ":: authenticating sudo"
# shellcheck disable=SC2024
sudo -v < /dev/tty

while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

DETECTED_GPU=""
if command -v lspci &>/dev/null; then
    VGA_INFO=$(lspci -nn | grep -E "VGA|3D|Display" || true)
    if echo "$VGA_INFO" | grep -iq "NVIDIA"; then
        DETECTED_GPU="nvidia"
    elif echo "$VGA_INFO" | grep -iq -E "AMD|Advanced Micro Devices|ATI"; then
        DETECTED_GPU="amd"
    elif echo "$VGA_INFO" | grep -iq "Intel"; then
        DETECTED_GPU="intel"
    fi
fi

if [[ -z "$DETECTED_GPU" ]]; then
    for vendor_file in /sys/class/drm/card*/device/vendor; do
        if [[ -f "$vendor_file" ]]; then
            VENDOR=$(cat "$vendor_file" 2>/dev/null || true)
            if [[ "$VENDOR" == "0x10de" ]]; then
                DETECTED_GPU="nvidia"
                break
            elif [[ "$VENDOR" == "0x1002" ]]; then
                DETECTED_GPU="amd"
                break
            elif [[ "$VENDOR" == "0x8086" ]]; then
                DETECTED_GPU="intel"
                break
            fi
        fi
    done
fi

if [[ -n "$DETECTED_GPU" ]]; then
    echo ":: detected gpu: $DETECTED_GPU"
fi

echo ":: configuring network and dns"
if [[ "$DISTRO" == "arch" ]]; then
    echo ":: logging: setting up systemd-resolved integration for NetworkManager"
    sudo mkdir -p /etc/NetworkManager/conf.d
    echo -e "[main]\ndns=systemd-resolved" | sudo tee /etc/NetworkManager/conf.d/systemd-resolved.conf >/dev/null
    if [[ -f /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
        echo ":: logging: backing up /etc/resolv.conf to /etc/resolv.conf.bak"
        sudo cp -f /etc/resolv.conf /etc/resolv.conf.bak
    fi
    echo ":: logging: linking /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf"
    sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

echo ":: logging: installing /etc/systemd/resolved.conf.d/malw-dns.conf"
sudo mkdir -p /etc/systemd/resolved.conf.d
if [[ -f "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" ]]; then
    sudo install -Dm644 "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" /etc/systemd/resolved.conf.d/malw-dns.conf
fi

if command -v restorecon &>/dev/null; then
    sudo restorecon -Rv /etc/systemd/resolved.conf.d /etc/resolv.conf /etc/NetworkManager/conf.d 2>/dev/null || true
fi

echo ":: logging: restarting systemd-resolved and NetworkManager"
sudo systemctl enable --now systemd-resolved
sudo systemctl restart systemd-resolved
if systemctl is-active --quiet NetworkManager; then
    sudo systemctl restart NetworkManager
fi

echo ":: configuring zapret"
ZAPRET_DIR="$DOTFILES_DIR/modules/network/zapret"
if [[ ! -x "$ZAPRET_DIR/nfqws" || ! -d "$ZAPRET_DIR/zapret-latest" ]]; then
    echo ":: downloading zapret binaries and dependencies"
    (cd "$ZAPRET_DIR" && bash ./service.sh download-deps --default)
fi

sed "s/__INTERFACE__/any/g" "$ZAPRET_DIR/conf.env.template" > "$ZAPRET_DIR/conf.env"

echo ":: deploying zapret to /opt/zapret"
sudo mkdir -p /opt/zapret
sudo cp -r "$ZAPRET_DIR"/* /opt/zapret/
sudo chown -R root:root /opt/zapret
sudo chmod +x /opt/zapret/service.sh /opt/zapret/nfqws /opt/zapret/auto_tune*.sh 2>/dev/null || true

sudo mkdir -p /usr/local/bin
sudo tee /usr/local/bin/zapret > /dev/null << 'WRAPPER_EOF'
#!/usr/bin/env bash
exec /opt/zapret/service.sh "$@"
WRAPPER_EOF
sudo chmod +x /usr/local/bin/zapret

sudo tee /etc/systemd/system/zapret_discord_youtube.service > /dev/null << UNIT_EOF
[Unit]
Description=Zapret Discord Youtube Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=/opt/zapret
User=root
ExecStart=/usr/bin/env bash /opt/zapret/service.sh daemon
ExecStop=/usr/bin/env bash /opt/zapret/service.sh kill
ExecStopPost=/usr/bin/env echo "Zapret service stopped"
PIDFile=/run/zapret_discord_youtube.pid

[Install]
WantedBy=multi-user.target
UNIT_EOF

if command -v restorecon &>/dev/null; then
    sudo restorecon -Rv /opt/zapret /usr/local/bin/zapret /etc/systemd/system/zapret_discord_youtube.service 2>/dev/null || true
fi

sudo systemctl daemon-reload
sudo systemctl enable --now zapret_discord_youtube.service

echo ":: verifying network connectivity"
sleep 2
if ! curl -Is --connect-timeout 5 https://github.com >/dev/null 2>&1 && ! curl -Is --connect-timeout 5 https://1.1.1.1 >/dev/null 2>&1; then
    echo "error: network connectivity verification failed, rolling back network" >&2
    rollback_network
    exit 1
fi
echo ":: network is online and bypass is active"

echo ":: setting up package repositories and base dependencies"
if [[ "$DISTRO" == "fedora" ]]; then
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        echo ":: installing rpmfusion"
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
    fi

    if [[ ! -f /etc/yum.repos.d/cloudflare-warp.repo ]]; then
        echo ":: adding cloudflare warp repo"
        sudo rpm --import https://pkg.cloudflareclient.com/pubkey.gpg || true
        sudo curl -fsSl https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo | sudo tee /etc/yum.repos.d/cloudflare-warp.repo >/dev/null || true
    fi

    sudo dnf copr enable -y solopasha/hyprland || true
    sudo dnf install -y stow jq gum curl git
elif [[ "$DISTRO" == "arch" ]]; then
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        echo ":: enabling multilib in pacman.conf"
        sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    fi
    sudo pacman -Syu --needed --noconfirm stow jq gum curl git
fi

if [[ -z "$DETECTED_GPU" ]]; then
    echo ":: select GPU:"
    DETECTED_GPU=$(gum choose "amd" "nvidia" "intel" "none" < /dev/tty || echo "none")
    DETECTED_GPU="${DETECTED_GPU:-none}"
    echo ":: selected gpu: $DETECTED_GPU"
fi

JSON_DATA=$(python3 -c 'import sys,tomllib,json; json.dump(tomllib.load(sys.stdin.buffer), sys.stdout)' < "$DOTFILES_DIR/modules.toml")
MODULES=$(echo "$JSON_DATA" | jq -r '.modules | keys[]')

ALWAYS_MODULES=()
OPTIONAL_MODULES=()

for mod in $MODULES; do
    ALWAYS=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].always // false")
    if [[ "$ALWAYS" == "true" ]]; then
        ALWAYS_MODULES+=("$mod")
    else
        DESC=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].description // \"$mod\"")
        OPTIONAL_MODULES+=("$mod ($DESC)")
    fi
done

SELECTED_MODULES=("${ALWAYS_MODULES[@]}")

if [[ ${#OPTIONAL_MODULES[@]} -gt 0 ]]; then
    echo ":: select optional modules to install (space to toggle, enter to confirm):"
    SELECTED_OPTIONAL=$(gum choose --no-limit "${OPTIONAL_MODULES[@]}" < /dev/tty || true)
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            mod_name=$(echo "$line" | awk '{print $1}')
            SELECTED_MODULES+=("$mod_name")
        fi
    done <<< "$SELECTED_OPTIONAL"
fi

echo ":: selected modules: ${SELECTED_MODULES[*]}"

echo ":: re-authenticating sudo credentials"
# shellcheck disable=SC2024
sudo -v < /dev/tty

ALL_PACKAGES=()
if [[ "$DISTRO" == "fedora" ]]; then
    ALL_PACKAGES+=("cloudflare-warp" "pipewire" "wireplumber" "pipewire-pulseaudio" "pipewire-alsa")
elif [[ "$DISTRO" == "arch" ]]; then
    ALL_PACKAGES+=("pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa")
fi

ROOT_SERVICES=()
ROOT_COMMANDS=()
POST_MESSAGES=()
USER_SERVICES=()

for mod in "${SELECTED_MODULES[@]}"; do
    while read -r pkg; do
        [[ -n "$pkg" ]] && ALL_PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].packages[]? // empty")

    while read -r pkg; do
        [[ -n "$pkg" ]] && ALL_PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].distro_packages.${DISTRO}[]? // empty")

    if [[ -n "$DETECTED_GPU" && "$DETECTED_GPU" != "none" ]]; then
        while read -r pkg; do
            [[ -n "$pkg" ]] && ALL_PACKAGES+=("$pkg")
        done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].gpu_packages.${DETECTED_GPU}.${DISTRO}.packages[]? // empty")
    fi

    while read -r srv; do
        [[ -n "$srv" ]] && ROOT_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].root_services.enable[]? // empty")

    while read -r cmd; do
        [[ -n "$cmd" ]] && ROOT_COMMANDS+=("$cmd")
    done < <(echo "$JSON_DATA" | jq -r "(.modules[\"$mod\"].root_commands // {}) | to_entries[]? | .value")

    while read -r srv; do
        [[ -n "$srv" ]] && USER_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r "(.modules[\"$mod\"].user_services // {}) | to_entries[]? | .key")

    msg=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].post_message.text // empty")
    if [[ -n "$msg" ]]; then
        POST_MESSAGES+=("$msg")
    fi
done

UNIQUE_PACKAGES=()
if [[ ${#ALL_PACKAGES[@]} -gt 0 ]]; then
    mapfile -t UNIQUE_PACKAGES < <(printf "%s\n" "${ALL_PACKAGES[@]}" | sort -u)
fi

if [[ ${#UNIQUE_PACKAGES[@]} -gt 0 ]]; then
    echo ":: installing module packages: ${UNIQUE_PACKAGES[*]}"
    if [[ "$DISTRO" == "fedora" ]]; then
        sudo dnf install -y --skip-unavailable "${UNIQUE_PACKAGES[@]}"
    elif [[ "$DISTRO" == "arch" ]]; then
        ARCH_OFFICIAL=()
        ARCH_AUR=()
        for pkg in "${UNIQUE_PACKAGES[@]}"; do
            if pacman -Si "$pkg" &>/dev/null; then
                ARCH_OFFICIAL+=("$pkg")
            elif command -v yay &>/dev/null; then
                ARCH_AUR+=("$pkg")
            fi
        done
        if [[ ${#ARCH_OFFICIAL[@]} -gt 0 ]]; then
            sudo pacman -S --noconfirm --needed "${ARCH_OFFICIAL[@]}"
        fi
        if [[ ${#ARCH_AUR[@]} -gt 0 ]]; then
            yay -S --noconfirm --needed "${ARCH_AUR[@]}"
        fi
    fi
fi

for mod in "${SELECTED_MODULES[@]}"; do
    for root_dir in "$DOTFILES_DIR/modules/$mod/root" "$DOTFILES_DIR/modules/$mod/root-$DISTRO"; do
        if [[ -d "$root_dir" ]]; then
            echo ":: deploying root files from $root_dir"
            (
                cd "$root_dir"
                find . -type f | while read -r file; do
                    target_file="/${file#./}"
                    target_dir="$(dirname "$target_file")"
                    sudo mkdir -p "$target_dir"
                    if [[ -f "$target_file" && ! -L "$target_file" ]]; then
                        sudo cp -f "$target_file" "${target_file}.bak"
                    elif [[ -L "$target_file" ]]; then
                        sudo rm -f "$target_file"
                    fi
                    if grep -q "__USER__" "$file" 2>/dev/null; then
                        sed "s/__USER__/$USER/g" "$file" | sudo tee "$target_file" >/dev/null
                        sudo chmod 644 "$target_file"
                    else
                        sudo install -Dm644 "$file" "$target_file"
                    fi
                    sudo chown root:root "$target_file"
                    if command -v restorecon &>/dev/null; then
                        sudo restorecon -Rv "$target_file" 2>/dev/null || true
                    fi
                done
            )
        fi
    done
done

if systemctl list-unit-files | grep -q "warp-svc.service"; then
    sudo systemctl enable --now warp-svc.service 2>/dev/null || true
fi

if [[ ${#ROOT_SERVICES[@]} -gt 0 ]]; then
    echo ":: enabling system services: ${ROOT_SERVICES[*]}"
    sudo systemctl enable --now "${ROOT_SERVICES[@]}" 2>/dev/null || true
fi

if [[ ${#ROOT_COMMANDS[@]} -gt 0 ]]; then
    for cmd in "${ROOT_COMMANDS[@]}"; do
        echo ":: running root command: $cmd"
        sudo bash -c "$cmd"
    done
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " network " ]] && command -v warp-cli &>/dev/null; then
    if ! warp-cli status 2>/dev/null | grep -iq "Connected"; then
        echo ":: connecting cloudflare warp"
        warp-cli registration new 2>/dev/null || true
        warp-cli connect 2>/dev/null || true
        sleep 2
    fi
fi

echo ":: stowing user configurations"
for mod in "${SELECTED_MODULES[@]}"; do
    if [[ -d "$DOTFILES_DIR/modules/$mod/user" ]]; then
        echo ":: stowing $mod"
        stow --adopt -R -t "$HOME" -d "$DOTFILES_DIR/modules/$mod" user 2>/dev/null || true
        if [[ -d "$DOTFILES_DIR/.git" ]]; then
            git checkout -- "modules/$mod/user" 2>/dev/null || true
        fi
    fi
done

if [[ " ${SELECTED_MODULES[*]} " =~ " zen " ]] && [[ -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" ]]; then
    echo ":: applying zen browser configuration"
    for zen_dir in "$HOME/.config/zen/"*Default* "$HOME/.config/zen/"*default*; do
        if [[ -d "$zen_dir" ]]; then
            cp -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" "$zen_dir/user.js"
        fi
    done
fi

echo ":: activating user audio services"
systemctl --user daemon-reload
systemctl --user enable --now pipewire.service wireplumber.service 2>/dev/null || true
if [[ "$DISTRO" == "fedora" ]]; then
    systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
fi

if [[ ${#USER_SERVICES[@]} -gt 0 ]]; then
    echo ":: enabling user services: ${USER_SERVICES[*]}"
    systemctl --user daemon-reload
    systemctl --user enable --now "${USER_SERVICES[@]}" 2>/dev/null || true
fi

FISH_BIN=$(command -v fish 2>/dev/null || echo "/usr/bin/fish")
if [[ -x "$FISH_BIN" ]]; then
    echo ":: setting default shell to fish"
    sudo usermod -s "$FISH_BIN" "$USER"
fi

if [[ ${#POST_MESSAGES[@]} -gt 0 ]]; then
    for msg in "${POST_MESSAGES[@]}"; do
        echo ":: note: $msg"
    done
fi

echo ":: installation completed successfully"
