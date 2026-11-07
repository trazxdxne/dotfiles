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
    sudo systemctl disable --now awg-quick@awg0.service 2>/dev/null || true
    sudo systemctl disable --now game-bypass-routing.service 2>/dev/null || true
    sudo rm -f /etc/systemd/system/game-bypass-routing.service /usr/local/bin/game-bypass-routing.sh
    if command -v nft &>/dev/null; then
        sudo nft delete table inet zapret 2>/dev/null || true
        sudo nft delete table inet game_bypass 2>/dev/null || true
    fi
    while ip rule show | grep -q "fwmark 0x51 lookup main"; do
        sudo ip rule del fwmark 0x51 lookup main priority 100 2>/dev/null || break
    done
    while ip -6 rule show 2>/dev/null | grep -q "fwmark 0x51 lookup main"; do
        sudo ip -6 rule del fwmark 0x51 lookup main priority 100 2>/dev/null || break
    done
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

MISSING_BASE=()
for cmd_name in stow jq gum curl git; do
    if ! command -v "$cmd_name" &>/dev/null; then
        MISSING_BASE+=("$cmd_name")
    fi
done

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
elif [[ "$DISTRO" == "arch" ]]; then
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        echo ":: enabling multilib in pacman.conf"
        sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    fi

    if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
        echo ":: enabling chaotic-aur repository"
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || true
        sudo pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
        sudo pacman -U --noconfirm --needed \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true
        if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
            echo -e "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist" | sudo tee -a /etc/pacman.conf >/dev/null
        fi
        sudo pacman -Sy --noconfirm
    fi
fi

if [[ ${#MISSING_BASE[@]} -gt 0 ]]; then
    echo ":: installing missing base dependencies: ${MISSING_BASE[*]}"
    if [[ "$DISTRO" == "fedora" ]]; then
        sudo dnf install -y "${MISSING_BASE[@]}"
    elif [[ "$DISTRO" == "arch" ]]; then
        sudo pacman -S --needed --noconfirm "${MISSING_BASE[@]}"
    fi
fi

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
else
    echo ":: select GPU:"
    DETECTED_GPU=$(gum choose "amd" "nvidia" "intel" "none" < /dev/tty || echo "none")
    DETECTED_GPU="${DETECTED_GPU:-none}"
    echo ":: selected gpu: $DETECTED_GPU"
fi

SKIP_NETWORK=false
if systemctl is-active --quiet systemd-resolved 2>/dev/null && [[ -f /etc/systemd/resolved.conf.d/malw-dns.conf ]]; then
    if [[ "$DISTRO" == "arch" && -L /etc/resolv.conf && -f /etc/NetworkManager/conf.d/systemd-resolved.conf ]]; then
        SKIP_NETWORK=true
    elif [[ "$DISTRO" == "fedora" ]]; then
        SKIP_NETWORK=true
    fi
fi

if [[ "$SKIP_NETWORK" == "true" ]]; then
    echo ":: network and dns are already active and configured, skipping"
else
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
    if systemctl is-active --quiet NetworkManager 2>/dev/null; then
        sudo systemctl restart NetworkManager
    fi

    echo ":: verifying network connectivity"
    sleep 2
    if ! curl -Is --connect-timeout 5 https://github.com >/dev/null 2>&1 && ! curl -Is --connect-timeout 5 https://1.1.1.1 >/dev/null 2>&1; then
        echo "error: network connectivity verification failed, rolling back network" >&2
        rollback_network
        exit 1
    fi
    echo ":: network is online and bypass is active"
fi

if systemctl is-active --quiet zapret_discord_youtube.service 2>/dev/null && [[ -x /opt/zapret/nfqws ]]; then
    echo ":: zapret service is already running, skipping setup"
else
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
    sudo chown -R "$USER:$USER" /opt/zapret
    sudo chmod +x /opt/zapret/service.sh /opt/zapret/nfqws /opt/zapret/auto_tune*.sh 2>/dev/null || true
    sudo chmod 644 /opt/zapret/zapret-latest/bin/*.bin /opt/zapret/zapret-latest/lists/*.txt 2>/dev/null || true

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

STATE_DIR="$HOME/.local/state/dotfiles"
STATE_FILE="$STATE_DIR/installed_modules"
PREV_SELECTED=()
if [[ -f "$STATE_FILE" ]]; then
    mapfile -t PREV_SELECTED < "$STATE_FILE"
fi

SELECTED_MODULES=("${ALWAYS_MODULES[@]}")

if [[ ${#OPTIONAL_MODULES[@]} -gt 0 ]]; then
    GUM_PRESELECTED=()
    for opt in "${OPTIONAL_MODULES[@]}"; do
        mod_name=$(echo "$opt" | awk '{print $1}')
        for prev in "${PREV_SELECTED[@]}"; do
            if [[ "$mod_name" == "$prev" ]]; then
                GUM_PRESELECTED+=("$opt")
                break
            fi
        done
    done

    echo ":: select optional modules to install (space to toggle, enter to confirm):"
    if [[ ${#GUM_PRESELECTED[@]} -gt 0 ]]; then
        PRESEL_STR=$(IFS=,; echo "${GUM_PRESELECTED[*]}")
        SELECTED_OPTIONAL=$(gum choose --no-limit --selected="$PRESEL_STR" "${OPTIONAL_MODULES[@]}" < /dev/tty || true)
    else
        SELECTED_OPTIONAL=$(gum choose --no-limit "${OPTIONAL_MODULES[@]}" < /dev/tty || true)
    fi

    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            mod_name=$(echo "$line" | awk '{print $1}')
            SELECTED_MODULES+=("$mod_name")
        fi
    done <<< "$SELECTED_OPTIONAL"
fi

echo ":: selected modules: ${SELECTED_MODULES[*]}"

mkdir -p "$STATE_DIR"
printf "%s\n" "${SELECTED_MODULES[@]}" > "$STATE_FILE"

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

TO_INSTALL=()
for pkg in "${UNIQUE_PACKAGES[@]}"; do
    if [[ "$DISTRO" == "arch" ]]; then
        base_pkg="${pkg%-bin}"
        if ! pacman -Q "$pkg" &>/dev/null && ! pacman -Q "$base_pkg" &>/dev/null; then
            TO_INSTALL+=("$pkg")
        fi
    elif [[ "$DISTRO" == "fedora" ]]; then
        if ! rpm -q "$pkg" &>/dev/null; then
            TO_INSTALL+=("$pkg")
        fi
    fi
done

if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
    echo ":: all selected packages are already installed, skipping"
else
    echo ":: installing uninstalled packages: ${TO_INSTALL[*]}"
    if [[ "$DISTRO" == "fedora" ]]; then
        sudo dnf install -y --skip-unavailable "${TO_INSTALL[@]}"
    elif [[ "$DISTRO" == "arch" ]]; then
        ARCH_OFFICIAL=()
        ARCH_AUR=()
        for pkg in "${TO_INSTALL[@]}"; do
            if pacman -Si "$pkg" &>/dev/null; then
                ARCH_OFFICIAL+=("$pkg")
            elif command -v yay &>/dev/null; then
                ARCH_AUR+=("$pkg")
            else
                echo "warning: package $pkg not found in official repos and yay is missing" >&2
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
            (
                cd "$root_dir"
                find . -type f | while read -r file; do
                    target_file="/${file#./}"
                    target_dir="$(dirname "$target_file")"

                    tmp_rendered=""
                    if grep -q "__USER__" "$file" 2>/dev/null; then
                        tmp_rendered=$(mktemp)
                        sed "s/__USER__/$USER/g" "$file" > "$tmp_rendered"
                        source_compare="$tmp_rendered"
                    else
                        source_compare="$file"
                    fi

                    if [[ -f "$target_file" && ! -L "$target_file" ]] && cmp -s "$source_compare" "$target_file"; then
                        [[ -n "$tmp_rendered" ]] && rm -f "$tmp_rendered"
                        continue
                    fi

                    echo ":: deploying root file: $target_file"
                    sudo mkdir -p "$target_dir"
                    if [[ -f "$target_file" && ! -L "$target_file" ]]; then
                        sudo cp -f "$target_file" "${target_file}.bak"
                    elif [[ -L "$target_file" ]]; then
                        sudo rm -f "$target_file"
                    fi

                    file_mode="644"
                    if [[ -x "$file" ]]; then
                        file_mode="755"
                    fi

                    if [[ -n "$tmp_rendered" ]]; then
                        sudo install -Dm"$file_mode" "$tmp_rendered" "$target_file"
                        rm -f "$tmp_rendered"
                    else
                        sudo install -Dm"$file_mode" "$file" "$target_file"
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

if [[ " ${SELECTED_MODULES[*]} " =~ " network " ]]; then
    if [[ "$DISTRO" == "arch" ]]; then
        if [[ -f /etc/amnezia/amneziawg/awg0.conf ]]; then
            echo ":: enabling awg-quick@awg0.service"
            sudo systemctl enable --now awg-quick@awg0.service 2>/dev/null || true
        else
            echo ":: notice: /etc/amnezia/amneziawg/awg0.conf not found. Template available at modules/network/awg0.conf.template"
        fi
    elif command -v warp-cli &>/dev/null; then
        if ! warp-cli status 2>/dev/null | grep -iq "Connected"; then
            echo ":: connecting cloudflare warp"
            warp-cli registration new 2>/dev/null || true
            warp-cli connect 2>/dev/null || true
            sleep 2
        fi
    fi
fi

echo ":: stowing user configurations"
mkdir -p "$HOME/.config/fish/functions" "$HOME/.local/bin"
if [[ -L "$HOME/.config/fish/functions" ]]; then
    rm -f "$HOME/.config/fish/functions"
    mkdir -p "$HOME/.config/fish/functions"
fi
if [[ -L "$HOME/.agents" ]] && [[ ! -e "$HOME/.agents" ]]; then
    rm -f "$HOME/.agents"
fi
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

if [[ " ${SELECTED_MODULES[*]} " =~ " niri " ]]; then
    NIRI_AUTOSTART_DIR="$HOME/Projects/niri-autostart"
    if [[ ! -d "$NIRI_AUTOSTART_DIR/.git" ]]; then
        echo ":: cloning niri-autostart repository"
        mkdir -p "$HOME/Projects"
        git clone https://github.com/trazxdxne/niri-autostart.git "$NIRI_AUTOSTART_DIR"
    else
        echo ":: updating niri-autostart repository"
        git -C "$NIRI_AUTOSTART_DIR" pull --ff-only 2>/dev/null || true
    fi

    if command -v cargo &>/dev/null && [[ -f "$NIRI_AUTOSTART_DIR/Cargo.toml" ]]; then
        echo ":: building and installing niri-autostart"
        cargo install --path "$NIRI_AUTOSTART_DIR" --root "$HOME/.local" --locked --force 2>/dev/null || true
    fi
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " base " ]]; then
    EQUICORD_PLUGIN_DIR="$HOME/Projects/equicord-os-display-name"
    if [[ ! -d "$EQUICORD_PLUGIN_DIR/.git" ]]; then
        echo ":: cloning equicord-os-display-name repository"
        mkdir -p "$HOME/Projects"
        git clone https://github.com/trazxdxne/equicord-os-display-name.git "$EQUICORD_PLUGIN_DIR"
    else
        echo ":: updating equicord-os-display-name repository"
        git -C "$EQUICORD_PLUGIN_DIR" pull --ff-only 2>/dev/null || true
    fi

    EQUICORD_DIR="$HOME/Programs/Equicord"
    if [[ ! -d "$EQUICORD_DIR/.git" ]]; then
        echo ":: cloning Equicord repository"
        mkdir -p "$HOME/Programs"
        git clone https://github.com/Equicord/Equicord.git "$EQUICORD_DIR"
    else
        echo ":: updating Equicord repository"
        git -C "$EQUICORD_DIR" pull --rebase 2>/dev/null || true
    fi

    if [[ -f "$EQUICORD_PLUGIN_DIR/osDisplayName.ts" && -d "$EQUICORD_DIR/src/userplugins" ]]; then
        echo ":: copying custom equicord plugin"
        cp -f "$EQUICORD_PLUGIN_DIR/osDisplayName.ts" "$EQUICORD_DIR/src/userplugins/osDisplayName.ts"
    fi

    if command -v pnpm &>/dev/null && [[ -d "$EQUICORD_DIR" ]]; then
        echo ":: building and injecting Equicord"
        (cd "$EQUICORD_DIR" && COREPACK_ENABLE_STRICT=0 pnpm install && COREPACK_ENABLE_STRICT=0 pnpm build && echo | COREPACK_ENABLE_STRICT=0 pnpm inject) 2>/dev/null || true
    fi
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " antigravity " ]]; then
    TITUS_DIR="$HOME/Projects/titus-ai"
    if [[ ! -d "$TITUS_DIR/.git" ]]; then
        echo ":: cloning titus-ai repository"
        mkdir -p "$HOME/Projects"
        git clone https://github.com/trazxdxne/titus-ai.git "$TITUS_DIR"
    else
        echo ":: updating titus-ai repository"
        git -C "$TITUS_DIR" pull --ff-only 2>/dev/null || true
    fi

    if [[ -f "$TITUS_DIR/scripts/install-antigravity.sh" ]]; then
        echo ":: installing titus-ai antigravity configuration"
        bash "$TITUS_DIR/scripts/install-antigravity.sh"
    fi

    if [[ -f "$HOME/.local/bin/agypatch" ]]; then
        chmod +x "$HOME/.local/bin/agypatch"
    fi
    if [[ -f "$HOME/.local/bin/agyp" ]]; then
        chmod +x "$HOME/.local/bin/agyp"
    fi
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
