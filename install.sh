#!/usr/bin/env bash
set -euo pipefail

if [[ "$EUID" -eq 0 ]]; then
    printf "error: please run as a normal user, not root\n" >&2
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
    printf "error: /etc/os-release missing\n" >&2
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
        printf "error: unsupported distribution: %s\n" "$DISTRO_ID" >&2
        exit 1
        ;;
esac
printf ":: detected distro: %s (%s)\n" "$DISTRO" "$DISTRO_ID"

rollback_network() {
    printf ":: rolling back network and dns configurations\n"
    if [[ "$DISTRO" == "arch" ]]; then
        if [[ -f /etc/resolv.conf.bak && -s /etc/resolv.conf.bak ]] && grep -q "nameserver" /etc/resolv.conf.bak 2>/dev/null; then
            sudo rm -f /etc/resolv.conf
            sudo cp -p /etc/resolv.conf.bak /etc/resolv.conf
            sudo rm -f /etc/resolv.conf.bak
            printf ":: restored /etc/resolv.conf from backup\n"
        elif [[ -L /etc/resolv.conf ]]; then
            sudo rm -f /etc/resolv.conf
        fi
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
    while ip rule show 2>/dev/null | grep -q "fwmark 0x51 lookup main"; do
        sudo ip rule del fwmark 0x51 lookup main 2>/dev/null || break
    done
    while ip -6 rule show 2>/dev/null | grep -q "fwmark 0x51 lookup main"; do
        sudo ip -6 rule del fwmark 0x51 lookup main 2>/dev/null || break
    done
    sudo rm -rf /opt/zapret /usr/local/bin/zapret
    printf ":: network rollback completed successfully\n"
}

if [[ "${1:-}" == "--rollback-network" ]]; then
    printf ":: authenticating sudo for rollback\n"
    # shellcheck disable=SC2024
    sudo -v < /dev/tty
    rollback_network
    exit 0
fi

printf ":: authenticating sudo\n"
# shellcheck disable=SC2024
sudo -v < /dev/tty

while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT

MISSING_BASE=()
for cmd_name in stow jq gum curl git python3; do
    if ! command -v "$cmd_name" &>/dev/null; then
        if [[ "$cmd_name" == "python3" && "$DISTRO" == "arch" ]]; then
            MISSING_BASE+=("python")
        else
            MISSING_BASE+=("$cmd_name")
        fi
    fi
done

if [[ "$DISTRO" == "fedora" ]]; then
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        printf ":: installing rpmfusion\n"
        sudo dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
            "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
    fi

    if [[ ! -f /etc/yum.repos.d/cloudflare-warp.repo ]]; then
        printf ":: adding cloudflare warp repo\n"
        sudo rpm --import https://pkg.cloudflareclient.com/pubkey.gpg || true
        tmp_warp_repo=$(mktemp)
        if curl -fsSL https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo -o "$tmp_warp_repo"; then
            sudo install -Dm644 "$tmp_warp_repo" /etc/yum.repos.d/cloudflare-warp.repo
            rm -f "$tmp_warp_repo"
        else
            rm -f "$tmp_warp_repo"
            printf "warning: failed to download cloudflare warp repo\n" >&2
        fi
    fi
elif [[ "$DISTRO" == "arch" ]]; then
    arch_repo_updated=false
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        printf ":: enabling multilib in pacman.conf\n"
        sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
        arch_repo_updated=true
    fi

    if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
        printf ":: enabling chaotic-aur repository\n"
        sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com 2>/dev/null || true
        sudo pacman-key --lsign-key 3056513887B78AEB 2>/dev/null || true
        sudo pacman -U --noconfirm --needed \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' \
            'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' || true
        if ! grep -q "^\[chaotic-aur\]" /etc/pacman.conf; then
            printf "\n[chaotic-aur]\nInclude = /etc/pacman.d/chaotic-mirrorlist\n" | sudo tee -a /etc/pacman.conf >/dev/null
        fi
        arch_repo_updated=true
    fi

    if [[ "$arch_repo_updated" == true ]]; then
        printf ":: updating pacman package databases and system\n"
        sudo pacman -Syu --noconfirm
    fi
fi

if [[ ${#MISSING_BASE[@]} -gt 0 ]]; then
    printf ":: installing missing base dependencies: %s\n" "${MISSING_BASE[*]}"
    if [[ "$DISTRO" == "fedora" ]]; then
        sudo dnf install -y "${MISSING_BASE[@]}"
    elif [[ "$DISTRO" == "arch" ]]; then
        sudo pacman -S --needed --noconfirm "${MISSING_BASE[@]}"
    fi
fi

JSON_DATA=$(python3 -c 'import sys,tomllib,json; json.dump(tomllib.load(sys.stdin.buffer), sys.stdout)' < "$DOTFILES_DIR/modules.toml")
MODULES=$(echo "$JSON_DATA" | jq -r '.modules | keys[]')

ALWAYS_MODULES=()
OPTIONAL_MODULES=()

for mod in $MODULES; do
    ALWAYS=$(echo "$JSON_DATA" | jq -r --arg m "$mod" '.modules[$m].always // false')
    if [[ "$ALWAYS" == "true" ]]; then
        ALWAYS_MODULES+=("$mod")
    else
        DESC=$(echo "$JSON_DATA" | jq -r --arg m "$mod" '.modules[$m].description // $m')
        CLEAN_DESC="${DESC//,/ -}"
        OPTIONAL_MODULES+=("$mod ($CLEAN_DESC)")
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

    printf ":: select optional modules to install (space to toggle, enter to confirm):\n"
    gum_exit=0
    if [[ ${#GUM_PRESELECTED[@]} -gt 0 ]]; then
        PRESEL_STR=$(IFS=,; echo "${GUM_PRESELECTED[*]}")
        SELECTED_OPTIONAL=$(gum choose --no-limit --selected="$PRESEL_STR" "${OPTIONAL_MODULES[@]}" < /dev/tty) || gum_exit=$?
    else
        SELECTED_OPTIONAL=$(gum choose --no-limit "${OPTIONAL_MODULES[@]}" < /dev/tty) || gum_exit=$?
    fi

    if [[ "$gum_exit" -ne 0 ]]; then
        printf ":: module selection cancelled, exiting without modifying state\n"
        exit 0
    fi

    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            mod_name=$(echo "$line" | awk '{print $1}')
            SELECTED_MODULES+=("$mod_name")
        fi
    done <<< "$SELECTED_OPTIONAL"
fi

printf ":: selected modules: %s\n" "${SELECTED_MODULES[*]}"

has_nvidia=false
has_amd=false
has_intel=false

if command -v lspci &>/dev/null; then
    VGA_INFO=$(lspci -nn | grep -E "VGA|3D|Display" || true)
    if echo "$VGA_INFO" | grep -qi '\[10de:'; then
        has_nvidia=true
    fi
    if echo "$VGA_INFO" | grep -qi '\[1002:'; then
        has_amd=true
    fi
    if echo "$VGA_INFO" | grep -qi '\[8086:'; then
        has_intel=true
    fi
fi

for vendor_file in /sys/class/drm/card*/device/vendor; do
    if [[ -f "$vendor_file" ]]; then
        vendor=$(cat "$vendor_file" 2>/dev/null || true)
        case "$vendor" in
            0x10de) has_nvidia=true ;;
            0x1002) has_amd=true ;;
            0x8086) has_intel=true ;;
        esac
    fi
done

DETECTED_GPU=""
if [[ "$has_nvidia" == true ]]; then
    DETECTED_GPU="nvidia"
elif [[ "$has_amd" == true ]]; then
    DETECTED_GPU="amd"
elif [[ "$has_intel" == true ]]; then
    DETECTED_GPU="intel"
fi

if [[ -n "$DETECTED_GPU" ]]; then
    printf ":: detected gpu: %s\n" "$DETECTED_GPU"
else
    printf ":: select GPU:\n"
    DETECTED_GPU=$(gum choose "amd" "nvidia" "intel" "none" < /dev/tty || printf "none")
    DETECTED_GPU="${DETECTED_GPU:-none}"
    printf ":: selected gpu: %s\n" "$DETECTED_GPU"
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " network " ]]; then
    SKIP_NETWORK=false
    if systemctl is-active --quiet systemd-resolved 2>/dev/null && [[ -f /etc/systemd/resolved.conf.d/malw-dns.conf ]]; then
        if [[ "$DISTRO" == "arch" && -L /etc/resolv.conf && -f /etc/NetworkManager/conf.d/systemd-resolved.conf ]]; then
            SKIP_NETWORK=true
        elif [[ "$DISTRO" == "fedora" ]]; then
            SKIP_NETWORK=true
        fi
    fi

    if [[ "$SKIP_NETWORK" == "true" ]]; then
        printf ":: network and dns are already active and configured, skipping\n"
    else
        printf ":: configuring network and dns\n"
        if [[ "$DISTRO" == "arch" ]]; then
            printf ":: logging: setting up systemd-resolved integration for NetworkManager\n"
            sudo mkdir -p /etc/NetworkManager/conf.d
            printf "[main]\ndns=systemd-resolved\n" | sudo tee /etc/NetworkManager/conf.d/systemd-resolved.conf >/dev/null
            if [[ -f /etc/resolv.conf && ! -L /etc/resolv.conf ]]; then
                if [[ ! -e /etc/resolv.conf.bak ]]; then
                    printf ":: logging: backing up /etc/resolv.conf to /etc/resolv.conf.bak\n"
                    sudo cp -p /etc/resolv.conf /etc/resolv.conf.bak
                fi
            fi
            printf ":: logging: linking /etc/resolv.conf -> /run/systemd/resolve/stub-resolv.conf\n"
            sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
        fi

        printf ":: logging: installing /etc/systemd/resolved.conf.d/malw-dns.conf\n"
        sudo mkdir -p /etc/systemd/resolved.conf.d
        if [[ -f "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" ]]; then
            sudo install -Dm644 "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" /etc/systemd/resolved.conf.d/malw-dns.conf
        fi

        if command -v restorecon &>/dev/null; then
            sudo restorecon -Rv /etc/systemd/resolved.conf.d /etc/resolv.conf /etc/NetworkManager/conf.d 2>/dev/null || true
        fi

        printf ":: logging: restarting systemd-resolved and NetworkManager\n"
        sudo systemctl enable --now systemd-resolved
        sudo systemctl restart systemd-resolved
        if systemctl is-active --quiet NetworkManager 2>/dev/null; then
            sudo systemctl restart NetworkManager
        fi

        printf ":: verifying network connectivity\n"
        net_ok=false
        for ((i = 0; i < 15; i++)); do
            if curl -Is --connect-timeout 3 https://github.com >/dev/null 2>&1 || curl -Is --connect-timeout 3 https://1.1.1.1 >/dev/null 2>&1; then
                net_ok=true
                break
            fi
            sleep 2
        done
        if [[ "$net_ok" != true ]]; then
            printf "error: network connectivity verification failed, rolling back network\n" >&2
            rollback_network
            exit 1
        fi
        printf ":: network is online and bypass is active\n"
    fi

    if systemctl is-active --quiet zapret_discord_youtube.service 2>/dev/null && [[ -x /opt/zapret/nfqws ]]; then
        printf ":: zapret service is already running, skipping setup\n"
    else
        printf ":: configuring zapret\n"
        ZAPRET_DIR="$DOTFILES_DIR/modules/network/zapret"
        export ZAPRET_VERSION="v72.9"
        export ZAPRET_SHA256="1e14dc6320dd7b5a1f28ab8145ac76d7a7010ca3cbe71824aa4aa407f7279ddf"

        if [[ ! -x "$ZAPRET_DIR/nfqws" || ! -d "$ZAPRET_DIR/zapret-latest" ]]; then
            printf ":: downloading zapret binaries and dependencies (version %s)\n" "$ZAPRET_VERSION"
            (
                cd "$ZAPRET_DIR"
                bash ./service.sh download-deps -z "$ZAPRET_VERSION" -s "1.10.4"
            )
        fi

        printf ":: deploying zapret to /opt/zapret\n"
        sudo mkdir -p /opt/zapret
        sudo cp -r "$ZAPRET_DIR"/* /opt/zapret/

        sed "s/__INTERFACE__/any/g" "$ZAPRET_DIR/conf.env.template" | sudo tee /opt/zapret/conf.env >/dev/null
        rm -f "$ZAPRET_DIR/conf.env"

        sudo chown -R root:root /opt/zapret
        sudo chmod 755 /opt/zapret
        sudo chmod +x /opt/zapret/service.sh /opt/zapret/nfqws /opt/zapret/auto_tune*.sh 2>/dev/null || true
        sudo chmod 644 /opt/zapret/conf.env 2>/dev/null || true
        if [[ -d /opt/zapret/zapret-latest ]]; then
            sudo chmod -R 755 /opt/zapret/zapret-latest
            sudo chmod 644 /opt/zapret/zapret-latest/bin/*.bin /opt/zapret/zapret-latest/lists/*.txt 2>/dev/null || true
        fi

        sudo mkdir -p /usr/local/bin
        sudo tee /usr/local/bin/zapret > /dev/null << 'WRAPPER_EOF'
#!/usr/bin/env bash
exec /opt/zapret/service.sh "$@"
WRAPPER_EOF
        sudo chmod +x /usr/local/bin/zapret

        sudo tee /etc/systemd/system/zapret_discord_youtube.service > /dev/null <<'UNIT_EOF'
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
PIDFile=/run/zapret_discord_youtube.pid

[Install]
WantedBy=multi-user.target
UNIT_EOF

        if command -v restorecon &>/dev/null; then
            sudo restorecon -Rv /opt/zapret /usr/local/bin/zapret /etc/systemd/system/zapret_discord_youtube.service 2>/dev/null || true
        fi

        sudo systemctl daemon-reload
        if ! sudo systemctl enable --now zapret_discord_youtube.service; then
            printf "warning: failed to enable zapret_discord_youtube.service\n" >&2
        fi
    fi
fi

REPO_CHANGED=false
sync_repo() {
    local url="$1"
    local dest_dir="$2"
    local ref="${3:-}"
    REPO_CHANGED=false

    mkdir -p "$(dirname "$dest_dir")"

    if [[ ! -d "$dest_dir/.git" ]]; then
        printf ":: cloning %s -> %s\n" "$url" "$dest_dir"
        if ! git clone "$url" "$dest_dir"; then
            printf "warning: failed to clone %s\n" "$url" >&2
            return 1
        fi
        if [[ -n "$ref" ]]; then
            if ! git -C "$dest_dir" checkout "$ref"; then
                printf "warning: failed to checkout %s in %s\n" "$ref" "$dest_dir" >&2
                return 1
            fi
        fi
        REPO_CHANGED=true
    else
        local old_head
        old_head=$(git -C "$dest_dir" rev-parse HEAD 2>/dev/null || printf "")

        printf ":: updating %s\n" "$dest_dir"
        if [[ -n "$ref" ]]; then
            if ! git -C "$dest_dir" fetch --tags origin; then
                printf "warning: failed to fetch tags for %s\n" "$url" >&2
            fi
            if ! git -C "$dest_dir" checkout "$ref"; then
                printf "warning: failed to checkout %s in %s\n" "$ref" "$dest_dir" >&2
                return 1
            fi
        else
            if ! git -C "$dest_dir" pull --ff-only; then
                printf "warning: failed to pull %s (--ff-only)\n" "$dest_dir" >&2
                return 1
            fi
        fi

        local new_head
        new_head=$(git -C "$dest_dir" rev-parse HEAD 2>/dev/null || printf "")
        if [[ "$old_head" != "$new_head" ]]; then
            REPO_CHANGED=true
        fi
    fi
    return 0
}

printf ":: re-authenticating sudo credentials\n"
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
    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && ALL_PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r --arg m "$mod" '.modules[$m].packages[]? // empty')

    while IFS= read -r pkg; do
        [[ -n "$pkg" ]] && ALL_PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r --arg m "$mod" --arg d "$DISTRO" '.modules[$m].distro_packages[$d][]? // empty')

    if [[ -n "$DETECTED_GPU" && "$DETECTED_GPU" != "none" ]]; then
        while IFS= read -r pkg; do
            [[ -n "$pkg" ]] && ALL_PACKAGES+=("$pkg")
        done < <(echo "$JSON_DATA" | jq -r --arg m "$mod" --arg g "$DETECTED_GPU" --arg d "$DISTRO" '.modules[$m].gpu_packages[$g][$d].packages[]? // empty')
    fi

    while IFS= read -r srv; do
        [[ -n "$srv" ]] && ROOT_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r --arg m "$mod" '.modules[$m].root_services.enable[]? // empty')

    while IFS= read -r cmd; do
        [[ -n "$cmd" ]] && ROOT_COMMANDS+=("$cmd")
    done < <(echo "$JSON_DATA" | jq -r --arg m "$mod" '(.modules[$m].root_commands // {}) | to_entries[]? | .value')

    while IFS= read -r srv; do
        [[ -n "$srv" ]] && USER_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r --arg m "$mod" '(.modules[$m].user_services // {}) | to_entries[]? | .key')

    msg=$(echo "$JSON_DATA" | jq -r --arg m "$mod" '.modules[$m].post_message.text // empty')
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
    printf ":: all selected packages are already installed, skipping\n"
else
    printf ":: installing uninstalled packages: %s\n" "${TO_INSTALL[*]}"
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
                printf "warning: package %s not found in official repos and yay is missing\n" "$pkg" >&2
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
                find . -type f -print0 | while IFS= read -r -d '' file; do
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

                    file_mode="644"
                    if [[ -x "$file" ]]; then
                        file_mode="755"
                    fi

                    case "$target_file" in
                        /etc/sudoers.d/*)
                            file_mode="0440"
                            ;;
                        /etc/amnezia/*|/etc/wireguard/*|*.conf.template|*awg*.conf)
                            file_mode="0600"
                            ;;
                        /etc/shadow*|/etc/gshadow*)
                            file_mode="0000"
                            ;;
                    esac

                    if [[ -f "$target_file" && ! -L "$target_file" ]] && cmp -s "$source_compare" "$target_file"; then
                        [[ -n "$tmp_rendered" ]] && rm -f "$tmp_rendered"
                        sudo chown root:root "$target_file"
                        sudo chmod "$file_mode" "$target_file"
                        continue
                    fi

                    printf ":: deploying root file: %s (mode %s)\n" "$target_file" "$file_mode"
                    sudo mkdir -p "$target_dir"
                    if [[ -f "$target_file" && ! -L "$target_file" ]]; then
                        if [[ ! -e "${target_file}.bak" ]]; then
                            sudo cp -p "$target_file" "${target_file}.bak"
                        fi
                    elif [[ -L "$target_file" ]]; then
                        sudo rm -f "$target_file"
                    fi

                    if [[ -n "$tmp_rendered" ]]; then
                        sudo install -Dm"$file_mode" "$tmp_rendered" "$target_file"
                        rm -f "$tmp_rendered"
                    else
                        sudo install -Dm"$file_mode" "$file" "$target_file"
                    fi
                    sudo chown root:root "$target_file"
                    sudo chmod "$file_mode" "$target_file"
                    if command -v restorecon &>/dev/null; then
                        sudo restorecon -Rv "$target_file" 2>/dev/null || true
                    fi
                done
            )
        fi
    done
done

if systemctl cat warp-svc.service &>/dev/null; then
    if ! sudo systemctl enable --now warp-svc.service; then
        printf "warning: failed to enable warp-svc.service\n" >&2
    fi
fi

if [[ ${#ROOT_SERVICES[@]} -gt 0 ]]; then
    printf ":: enabling system services: %s\n" "${ROOT_SERVICES[*]}"
    for srv in "${ROOT_SERVICES[@]}"; do
        if ! sudo systemctl enable --now "$srv"; then
            printf "warning: failed to enable root service: %s\n" "$srv" >&2
        fi
    done
fi

if [[ ${#ROOT_COMMANDS[@]} -gt 0 ]]; then
    for cmd in "${ROOT_COMMANDS[@]}"; do
        printf ":: running root command: %s\n" "$cmd"
        sudo bash -c "$cmd"
    done
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " network " ]]; then
    if [[ "$DISTRO" == "arch" ]]; then
        found_conf=""
        while IFS= read -r conf_candidate; do
            if [[ -f "$conf_candidate" ]] && grep -q "\[Interface\]" "$conf_candidate" 2>/dev/null && grep -q "\[Peer\]" "$conf_candidate" 2>/dev/null; then
                found_conf="$conf_candidate"
                break
            fi
        done < <(find "$HOME" -maxdepth 2 -type f \( -name "*WARP*.conf" -o -name "ghd*.conf" -o -name "mlw*.conf" \) 2>/dev/null | sort -V -r)

        if [[ -n "$found_conf" ]]; then
            printf ":: deploying AmneziaWG configuration from %s\n" "$found_conf"
            sudo mkdir -p /etc/amnezia/amneziawg
            sudo install -Dm600 "$found_conf" /etc/amnezia/amneziawg/awg0.conf
            mkdir -p "$DOTFILES_DIR/modules/network/root-arch/etc/amnezia/amneziawg"
            cp -f "$found_conf" "$DOTFILES_DIR/modules/network/root-arch/etc/amnezia/amneziawg/awg0.conf"
        fi

        if [[ -f /etc/amnezia/amneziawg/awg0.conf ]]; then
            printf ":: configuring awg-quick@awg0.service\n"
            sudo systemctl enable awg-quick@awg0.service
            if systemctl is-active --quiet awg-quick@awg0.service 2>/dev/null; then
                if ! sudo systemctl restart awg-quick@awg0.service; then
                    printf "warning: failed to restart awg-quick@awg0.service\n" >&2
                fi
            else
                if ! sudo systemctl start awg-quick@awg0.service; then
                    printf "warning: failed to start awg-quick@awg0.service\n" >&2
                fi
            fi
        else
            printf ":: notice: /etc/amnezia/amneziawg/awg0.conf not found. Template available at modules/network/awg0.conf.template\n"
        fi
    elif command -v warp-cli &>/dev/null; then
        if ! warp-cli status 2>/dev/null | grep -q "Status update: Connected"; then
            printf ":: connecting cloudflare warp\n"
            warp-cli --accept-tos registration new 2>/dev/null || true
            if ! warp-cli connect 2>/dev/null; then
                printf "warning: failed to connect cloudflare warp\n" >&2
            fi
            sleep 2
        fi
    fi
fi

printf ":: stowing user configurations\n"

for target_path in "$HOME/.config/fish/functions" "$HOME/.local/bin" "$HOME/.agents"; do
    if [[ -L "$target_path" && ! -e "$target_path" ]]; then
        rm -f "$target_path"
    fi
done

if [[ -L "$HOME/.config/fish/functions" ]]; then
    rm -f "$HOME/.config/fish/functions"
fi

mkdir -p "$HOME/.config/fish/functions" "$HOME/.local/bin"

for mod in "${SELECTED_MODULES[@]}"; do
    user_dir="$DOTFILES_DIR/modules/$mod/user"
    if [[ -d "$user_dir" ]]; then
        printf ":: stowing %s\n" "$mod"

        stow_conflicts=$(stow -n -v -R --no-folding -t "$HOME" -d "$DOTFILES_DIR/modules/$mod" user 2>&1 | \
            sed -nE 's/^[[:space:]]*\*[[:space:]]*existing target.*:[[:space:]]*//p' | sort -u || true)

        if [[ -n "$stow_conflicts" ]]; then
            while IFS= read -r rel_conflict; do
                [[ -z "$rel_conflict" ]] && continue
                conflict_path="$HOME/$rel_conflict"
                if [[ -L "$conflict_path" ]]; then
                    rm -f "$conflict_path"
                elif [[ -e "$conflict_path" ]]; then
                    bak_path="${conflict_path}.bak"
                    if [[ -e "$bak_path" ]]; then
                        bak_path="${conflict_path}.bak.$(date +%s)"
                    fi
                    printf ":: backing up conflicting file %s -> %s\n" "$conflict_path" "$bak_path"
                    mv "$conflict_path" "$bak_path"
                fi
            done <<< "$stow_conflicts"
        fi

        if ! stow -R --no-folding -t "$HOME" -d "$DOTFILES_DIR/modules/$mod" user; then
            printf "warning: failed to stow %s\n" "$mod" >&2
        fi
    fi
done

if [[ " ${SELECTED_MODULES[*]} " =~ " zen " ]] && [[ -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" ]]; then
    printf ":: applying zen browser configuration\n"
    for zen_dir in "$HOME/.config/zen/"*Default* "$HOME/.config/zen/"*default*; do
        if [[ -d "$zen_dir" ]]; then
            cp -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" "$zen_dir/user.js"
        fi
    done
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " niri " ]]; then
    NIRI_AUTOSTART_DIR="$HOME/Projects/niri-autostart"
    sync_repo "https://github.com/trazxdxne/niri-autostart.git" "$NIRI_AUTOSTART_DIR"
    niri_changed="$REPO_CHANGED"

    if [[ ! -x "$HOME/.local/bin/niri-autostart" || "$niri_changed" == true ]]; then
        if ! command -v cargo &>/dev/null; then
            printf "warning: cargo is not installed, cannot build niri-autostart\n" >&2
        elif [[ -f "$NIRI_AUTOSTART_DIR/Cargo.toml" ]]; then
            printf ":: building and installing niri-autostart\n"
            if ! cargo install --path "$NIRI_AUTOSTART_DIR" --root "$HOME/.local" --locked; then
                printf "warning: failed to build/install niri-autostart\n" >&2
            fi
        fi
    fi
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " base " ]]; then
    EQUICORD_PLUGIN_DIR="$HOME/Projects/equicord-os-display-name"
    sync_repo "https://github.com/trazxdxne/equicord-os-display-name.git" "$EQUICORD_PLUGIN_DIR"
    plugin_changed="$REPO_CHANGED"

    EQUICORD_DIR="$HOME/Programs/Equicord"
    sync_repo "https://github.com/Equicord/Equicord.git" "$EQUICORD_DIR"
    equicord_changed="$REPO_CHANGED"

    if [[ -f "$EQUICORD_PLUGIN_DIR/osDisplayName.ts" ]]; then
        mkdir -p "$EQUICORD_DIR/src/userplugins"
        if [[ ! -f "$EQUICORD_DIR/src/userplugins/osDisplayName.ts" ]] || ! cmp -s "$EQUICORD_PLUGIN_DIR/osDisplayName.ts" "$EQUICORD_DIR/src/userplugins/osDisplayName.ts"; then
            printf ":: copying custom equicord plugin\n"
            cp -f "$EQUICORD_PLUGIN_DIR/osDisplayName.ts" "$EQUICORD_DIR/src/userplugins/osDisplayName.ts"
            equicord_changed=true
        fi
    fi

    if [[ "$equicord_changed" == true || "$plugin_changed" == true || ! -d "$EQUICORD_DIR/dist" ]]; then
        if ! command -v pnpm &>/dev/null; then
            printf "warning: pnpm is not installed, skipping Equicord build\n" >&2
        elif [[ -d "$EQUICORD_DIR" ]]; then
            printf ":: building and injecting Equicord\n"
            if ! (
                cd "$EQUICORD_DIR"
                COREPACK_ENABLE_STRICT=0 pnpm install && \
                COREPACK_ENABLE_STRICT=0 pnpm build && \
                printf "\n" | COREPACK_ENABLE_STRICT=0 pnpm inject
            ); then
                printf "warning: Equicord build or inject failed\n" >&2
            fi
        fi
    fi
fi

if [[ " ${SELECTED_MODULES[*]} " =~ " antigravity " ]]; then
    TITUS_DIR="$HOME/Projects/titus-ai"
    sync_repo "https://github.com/trazxdxne/titus-ai.git" "$TITUS_DIR"

    if [[ -f "$TITUS_DIR/scripts/install-antigravity.sh" ]]; then
        printf ":: installing titus-ai antigravity configuration\n"
        if ! bash "$TITUS_DIR/scripts/install-antigravity.sh"; then
            printf "warning: titus-ai antigravity configuration failed\n" >&2
        fi
    fi

    if [[ -f "$HOME/.local/bin/agypatch" ]]; then
        chmod +x "$HOME/.local/bin/agypatch"
    fi
    if [[ -f "$HOME/.local/bin/agyp" ]]; then
        chmod +x "$HOME/.local/bin/agyp"
    fi
fi

printf ":: activating user audio services\n"
systemctl --user daemon-reload
for srv in pipewire.service wireplumber.service; do
    if ! systemctl --user enable --now "$srv"; then
        printf "warning: failed to enable user audio service: %s\n" "$srv" >&2
    fi
done
if [[ "$DISTRO" == "fedora" ]]; then
    if ! systemctl --user enable --now pipewire-pulse.service; then
        printf "warning: failed to enable pipewire-pulse.service\n" >&2
    fi
fi

if [[ ${#USER_SERVICES[@]} -gt 0 ]]; then
    printf ":: enabling user services: %s\n" "${USER_SERVICES[*]}"
    systemctl --user daemon-reload
    for srv in "${USER_SERVICES[@]}"; do
        if ! systemctl --user enable --now "$srv"; then
            printf "warning: failed to enable user service: %s\n" "$srv" >&2
        fi
    done
fi

FISH_BIN=$(command -v fish 2>/dev/null || printf "/usr/bin/fish")
if [[ -x "$FISH_BIN" ]]; then
    CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || printf "")
    if [[ "$CURRENT_SHELL" != "$FISH_BIN" ]]; then
        printf ":: setting default shell to fish (%s)\n" "$FISH_BIN"
        if ! sudo usermod -s "$FISH_BIN" "$USER"; then
            printf "warning: failed to change shell to fish\n" >&2
        fi
    fi
fi

mkdir -p "$STATE_DIR"
printf "%s\n" "${SELECTED_MODULES[@]}" > "$STATE_FILE"

if [[ ${#POST_MESSAGES[@]} -gt 0 ]]; then
    for msg in "${POST_MESSAGES[@]}"; do
        printf ":: note: %s\n" "$msg"
    done
fi

printf ":: installation completed successfully\n"
