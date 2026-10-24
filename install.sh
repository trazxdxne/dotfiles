#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dotfiles Universal Installer (Arch + Fedora)
# Single-elevation idempotent bootstrap with Zapret, DNS, and WARP
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# Prevent running directly as root
if [ "$EUID" -eq 0 ]; then
    echo "[-] Error: Please run this script as a normal user. Root tasks are executed via sudo/pkexec."
    exit 1
fi

# Prefer sudo for terminal credential caching; fallback to pkexec
if command -v sudo &> /dev/null; then
    ELEVATE="sudo"
elif command -v pkexec &> /dev/null; then
    ELEVATE="pkexec"
else
    echo "[-] Error: Neither sudo nor pkexec found."
    exit 1
fi

# -----------------------------------------------------------------------------
# 1. Distro Detection
# -----------------------------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
else
    echo "[-] Error: Cannot determine OS: /etc/os-release missing."
    exit 1
fi

case "$DISTRO_ID $DISTRO_LIKE" in
    *arch*|*cachyos*|*endeavouros*|*manjaro*)
        DISTRO="arch"
        PKG_INSTALL="pacman -S --noconfirm --needed"
        PKG_UPDATE="pacman -Syu --noconfirm"
        ;;
    *fedora*|*nobara*)
        DISTRO="fedora"
        PKG_INSTALL="dnf install -y"
        PKG_UPDATE="dnf upgrade -y"
        ;;
    *)
        echo "[-] Error: Unsupported distribution: $DISTRO_ID (requires Arch-based or Fedora-based)."
        exit 1
esac

echo "=========================================================="
echo ":: Dotfiles Installer | Detected: $DISTRO ($DISTRO_ID)"
echo "=========================================================="

# -----------------------------------------------------------------------------
# 2. Module Selection (Offline, No Root Required)
# -----------------------------------------------------------------------------
echo ""
echo ":: [Step 1/4] Configuring modules..."

JSON_DATA=$(python3 -c 'import sys,tomllib,json; json.dump(tomllib.load(sys.stdin.buffer), sys.stdout)' < modules.toml)
MODULES=$(echo "$JSON_DATA" | jq -r '.modules | keys[]')

ALWAYS_MODULES=()
OPTIONAL_MODULES=()

for mod in $MODULES; do
    ALWAYS=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].always // false")
    if [ "$ALWAYS" = "true" ]; then
        ALWAYS_MODULES+=("$mod")
    else
        DESC=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].description // \"$mod\"")
        OPTIONAL_MODULES+=("$mod ($DESC)")
    fi
done

SELECTED_OPTIONAL=""
if command -v gum &> /dev/null; then
    echo ":: Select optional modules to install (Space to toggle, Enter to confirm):"
    SELECTED_OPTIONAL=$(printf "%s\n" "${OPTIONAL_MODULES[@]}" | gum choose --no-limit)
else
    echo ":: Available optional modules:"
    for i in "${!OPTIONAL_MODULES[@]}"; do
        printf "   [%d] %s\n" "$((i+1))" "${OPTIONAL_MODULES[$i]}"
    done
    read -r -p ":: Enter numbers to install (space/comma separated, or 'all') [all]: " user_choice
    user_choice="${user_choice:-all}"
    if [ "$user_choice" = "all" ]; then
        SELECTED_OPTIONAL=$(printf "%s\n" "${OPTIONAL_MODULES[@]}")
    else
        for num in $(echo "$user_choice" | tr ',' ' '); do
            idx=$((num-1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "${#OPTIONAL_MODULES[@]}" ]; then
                SELECTED_OPTIONAL+="${OPTIONAL_MODULES[$idx]}"$'\n'
            fi
        done
    fi
fi

SELECTED_MODULES=("${ALWAYS_MODULES[@]}")
while IFS= read -r line; do
    if [ -n "$line" ]; then
        mod_name=$(echo "$line" | awk '{print $1}')
        SELECTED_MODULES+=("$mod_name")
    fi
done <<< "$SELECTED_OPTIONAL"

echo ":: Selected modules: ${SELECTED_MODULES[*]}"

# -----------------------------------------------------------------------------
# 3. GPU Detection (Offline)
# -----------------------------------------------------------------------------
DETECTED_GPU=""
if command -v lspci &> /dev/null; then
    VGA_INFO=$(lspci -nn | grep -E "VGA|3D|Display" || true)
    if echo "$VGA_INFO" | grep -iq "NVIDIA"; then
        DETECTED_GPU="nvidia"
    elif echo "$VGA_INFO" | grep -iq -E "AMD|Advanced Micro Devices|ATI"; then
        DETECTED_GPU="amd"
    fi
fi

if [ -z "$DETECTED_GPU" ]; then
    for vendor_file in /sys/class/drm/card*/device/vendor; do
        if [ -f "$vendor_file" ]; then
            VENDOR=$(cat "$vendor_file" 2>/dev/null || true)
            if [ "$VENDOR" = "0x10de" ]; then
                DETECTED_GPU="nvidia"
                break
            elif [ "$VENDOR" = "0x1002" ]; then
                DETECTED_GPU="amd"
                break
            fi
        fi
    done
fi

if [ -n "$DETECTED_GPU" ]; then
    echo ":: Detected GPU: $DETECTED_GPU"
else
    echo "[!] Could not auto-detect GPU."
    if command -v gum &> /dev/null; then
        DETECTED_GPU=$(gum choose "amd" "nvidia" "intel" "none")
    else
        read -r -p ":: Select GPU (amd/nvidia/intel/none) [none]: " DETECTED_GPU
        DETECTED_GPU="${DETECTED_GPU:-none}"
    fi
fi

# Detect network interface for Zapret template
ZAPRET_DIR="$DOTFILES_DIR/modules/network/zapret"
DETECTED_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)
DETECTED_IFACE="${DETECTED_IFACE:-any}"
echo ":: Detected network interface: $DETECTED_IFACE"

if [ -f "$ZAPRET_DIR/conf.env.template" ]; then
    sed "s/__INTERFACE__/$DETECTED_IFACE/g" "$ZAPRET_DIR/conf.env.template" > "$ZAPRET_DIR/conf.env"
fi

# -----------------------------------------------------------------------------
# 4. Compile Unified Single-Pass Root Script
# -----------------------------------------------------------------------------
echo ""
echo ":: [Step 2/4] Compiling unified root script..."

ROOT_SH="/tmp/dotfiles-root.sh"
cat > "$ROOT_SH" << 'EOF'
#!/bin/bash
set -euo pipefail

TARGET_USER="${SUDO_USER:-$USER}"
TARGET_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
EOF

# 4.1 Step: Network Pre-flight Setup (DNS + Zapret + Repos)
cat >> "$ROOT_SH" << EOF

echo "-> [1/6] Configuring DNS over TLS (malw.link)..."
mkdir -p /etc/systemd/resolved.conf.d
if [ -f "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" ]; then
    cp "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" /etc/systemd/resolved.conf.d/malw-dns.conf
fi
systemctl enable --now systemd-resolved 2>/dev/null || true
systemctl restart systemd-resolved 2>/dev/null || true

echo "-> [2/6] Configuring Zapret DPI bypass service..."
if [ -d "$ZAPRET_DIR" ]; then
    chmod +x "$ZAPRET_DIR/nfqws" "$ZAPRET_DIR/service.sh" "$ZAPRET_DIR"/auto_tune*.sh 2>/dev/null || true
    cat > /etc/systemd/system/zapret_discord_youtube.service << 'UNIT_EOF'
[Unit]
Description=Zapret Discord Youtube Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$ZAPRET_DIR
User=root
ExecStart=/usr/bin/env bash $ZAPRET_DIR/service.sh daemon
ExecStop=/usr/bin/env bash $ZAPRET_DIR/service.sh kill
ExecStopPost=/usr/bin/env echo "Zapret service stopped"
PIDFile=/run/zapret_discord_youtube.pid

[Install]
WantedBy=multi-user.target
UNIT_EOF
    systemctl daemon-reload
    systemctl enable --now zapret_discord_youtube.service 2>/dev/null || true
fi

echo "-> [3/6] Setting up package repositories..."
EOF

if [ "$DISTRO" = "fedora" ]; then
    cat >> "$ROOT_SH" << 'EOF'
if ! rpm -q rpmfusion-free-release &>/dev/null; then
    echo "   Installing RPMFusion..."
    dnf install -y \
        https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
        https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 2>/dev/null || true
fi

if [ ! -f /etc/yum.repos.d/cloudflare-warp.repo ]; then
    echo "   Adding Cloudflare WARP repo..."
    rpm --import https://pkg.cloudflareclient.com/pubkey.gpg 2>/dev/null || true
    curl -fsSl https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo > /etc/yum.repos.d/cloudflare-warp.repo 2>/dev/null || true
fi

dnf copr enable -y solopasha/hyprland 2>/dev/null || true
dnf copr enable -y atim/gum 2>/dev/null || true
EOF
elif [ "$DISTRO" = "arch" ]; then
    cat >> "$ROOT_SH" << 'EOF'
if grep -q "^#\[multilib\]" /etc/pacman.conf; then
    echo "   Enabling multilib in pacman.conf..."
    sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
fi
EOF
fi

# 4.2 Collect all packages to install in ONE pass
ALL_PACKAGES=("stow")

# Essential installer & base tools
if [ "$DISTRO" = "fedora" ]; then
    ALL_PACKAGES+=("gum" "jq" "cloudflare-warp" "pipewire" "wireplumber" "pipewire-pulseaudio" "pipewire-alsa")
elif [ "$DISTRO" = "arch" ]; then
    ALL_PACKAGES+=("gum" "jq" "pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa")
fi

ROOT_SERVICES=()
ROOT_COMMANDS=()
POST_MESSAGES=()
USER_SERVICES=()

for mod in "${SELECTED_MODULES[@]}"; do
    # Module packages
    while read -r pkg; do
        [ -n "$pkg" ] && ALL_PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].packages[]? // empty")
    
    # Distro-specific packages
    while read -r pkg; do
        [ -n "$pkg" ] && ALL_PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].distro_packages.${DISTRO}[]? // empty")

    # GPU packages
    if [ -n "$DETECTED_GPU" ] && [ "$DETECTED_GPU" != "none" ]; then
        while read -r pkg; do
            [ -n "$pkg" ] && ALL_PACKAGES+=("$pkg")
        done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].gpu_packages.${DETECTED_GPU}.${DISTRO}.packages[]? // empty")
    fi

    # Root services
    while read -r srv; do
        [ -n "$srv" ] && ROOT_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].root_services.enable[]? // empty")

    # Root commands
    while read -r cmd; do
        [ -n "$cmd" ] && ROOT_COMMANDS+=("$cmd")
    done < <(echo "$JSON_DATA" | jq -r "(.modules[\"$mod\"].root_commands // {}) | to_entries[]? | .value")

    # User services
    while read -r srv; do
        [ -n "$srv" ] && USER_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r "(.modules[\"$mod\"].user_services // {}) | to_entries[]? | .key")

    # Post message
    msg=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].post_message.text // empty")
    if [ -n "$msg" ]; then
        POST_MESSAGES+=("$msg")
    fi

    # Root package files
    if [ -d "$DOTFILES_DIR/modules/$mod/root" ]; then
        echo "echo '   Deploying root files for $mod...'" >> "$ROOT_SH"
        echo "cp -a --remove-destination \"$DOTFILES_DIR/modules/$mod/root/.\" /" >> "$ROOT_SH"
        
        if [ "$DETECTED_GPU" = "amd" ] && [ "$mod" = "system-hw" ]; then
            echo "if [ -f /etc/default/limine ]; then" >> "$ROOT_SH"
            echo "    sed -i 's/nvidia_drm.modeset=1 nvidia_drm.fbdev=1 //g' /etc/default/limine" >> "$ROOT_SH"
            echo "fi" >> "$ROOT_SH"
            echo "if [ -f /etc/mkinitcpio.conf ]; then" >> "$ROOT_SH"
            echo "    sed -i 's/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm/MODULES=(/g' /etc/mkinitcpio.conf" >> "$ROOT_SH"
            echo "fi" >> "$ROOT_SH"
        fi
    fi
done

# Deduplicate packages
UNIQUE_PACKAGES=($(echo "${ALL_PACKAGES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

cat >> "$ROOT_SH" << EOF

echo "-> [4/6] Installing packages in single pass..."
EOF

if [ "$DISTRO" = "fedora" ]; then
    echo "dnf install -y --skip-unavailable ${UNIQUE_PACKAGES[*]}" >> "$ROOT_SH"
elif [ "$DISTRO" = "arch" ]; then
    echo "pacman -S --noconfirm --needed ${UNIQUE_PACKAGES[*]}" >> "$ROOT_SH"
fi

cat >> "$ROOT_SH" << EOF

echo "-> [5/6] Enabling system services..."
systemctl enable --now warp-svc.service 2>/dev/null || true
EOF

if [ ${#ROOT_SERVICES[@]} -gt 0 ]; then
    echo "systemctl enable --now ${ROOT_SERVICES[*]} 2>/dev/null || true" >> "$ROOT_SH"
fi

if [ ${#ROOT_COMMANDS[@]} -gt 0 ]; then
    echo "echo '-> Running post-install commands...'" >> "$ROOT_SH"
    for cmd in "${ROOT_COMMANDS[@]}"; do
        echo "SUDO_USER=\"\$TARGET_USER\" bash -c '$cmd'" >> "$ROOT_SH"
    done
fi

cat >> "$ROOT_SH" << 'EOF'

echo "-> [6/6] Configuring user default shell..."
FISH_BIN=$(command -v fish 2>/dev/null || echo "/usr/bin/fish")
if [ -x "$FISH_BIN" ]; then
    usermod -s "$FISH_BIN" "$TARGET_USER"
    echo "   Default shell set to fish for $TARGET_USER"
fi
EOF

chmod +x "$ROOT_SH"

# -----------------------------------------------------------------------------
# 5. Execute Root Operations (EXACTLY ONE AUTHENTICATION)
# -----------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo ":: [Step 3/4] Root Operations (Single Authentication Pass)"
echo "=========================================================="
echo ":: The following operations will be executed in a single batch:"
echo "   - Configure DNS over TLS & Zapret service"
echo "   - Setup package repositories"
echo "   - Install packages: ${UNIQUE_PACKAGES[*]}"
echo "   - Deploy /etc configurations & enable system services"
echo "   - Set default shell to fish for $USER"
echo ""

EXECUTE_ROOT=true
if command -v gum &> /dev/null; then
    if ! gum confirm "Execute root operations?"; then
        EXECUTE_ROOT=false
    fi
else
    read -r -p ":: Proceed with root operations? [Y/n]: " ans
    if [[ "$ans" =~ ^[Nn] ]]; then
        EXECUTE_ROOT=false
    fi
fi

if [ "$EXECUTE_ROOT" = "true" ]; then
    $ELEVATE bash "$ROOT_SH"
    echo "[+] Root operations completed."
else
    echo "[!] Skipped root operations."
fi

# -----------------------------------------------------------------------------
# 6. User Space Setup (Stow, Services, Connectivity)
# -----------------------------------------------------------------------------
echo ""
echo "=========================================================="
echo ":: [Step 4/4] User Environment Setup"
echo "=========================================================="

# 6.1 Connect Cloudflare WARP
if command -v warp-cli &> /dev/null; then
    if ! warp-cli status 2>/dev/null | grep -iq "Connected"; then
        echo ":: Connecting Cloudflare WARP..."
        warp-cli registration new 2>/dev/null || true
        warp-cli connect 2>/dev/null || true
        sleep 2
    fi
fi

# 6.2 Check Connectivity
echo ":: Verifying network connectivity..."
if curl -s --connect-timeout 5 https://1.1.1.1 >/dev/null 2>&1 || curl -s --connect-timeout 5 https://google.com >/dev/null 2>&1; then
    echo "   [+] Network is ONLINE and bypass is ACTIVE."
else
    echo "   [!] Warning: Direct probe timed out. Continuing..."
fi

# 6.3 Setup User Audio
echo ":: Activating user audio services (PipeWire / WirePlumber)..."
systemctl --user daemon-reload
systemctl --user enable --now pipewire.service wireplumber.service 2>/dev/null || true
if [ "$DISTRO" = "fedora" ]; then
    systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
fi

# 6.4 Stow User Configs
echo ":: Stowing user configurations..."
for mod in "${SELECTED_MODULES[@]}"; do
    if [ -d "$DOTFILES_DIR/modules/$mod/user" ]; then
        echo "   -> Linking: $mod"
        stow --adopt -R -t "$HOME" -d "$DOTFILES_DIR/modules/$mod" user 2>/dev/null || true
        if [ -d "$DOTFILES_DIR/.git" ]; then
            git checkout -- "modules/$mod/user" 2>/dev/null || true
        fi
    fi
done

# 6.5 Dynamic Zen Browser Profile
if [[ " ${SELECTED_MODULES[*]} " =~ " zen " ]] && [ -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" ]; then
    echo ":: Applying Zen Browser configuration..."
    for zen_dir in "$HOME/.config/zen/"*Default* "$HOME/.config/zen/"*default*; do
        if [ -d "$zen_dir" ]; then
            cp -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" "$zen_dir/user.js"
            echo "   -> Linked user.js to: $zen_dir"
        fi
    done
fi

# 6.6 User Systemd Services
if [ ${#USER_SERVICES[@]} -gt 0 ]; then
    echo ":: Enabling user services: ${USER_SERVICES[*]}..."
    systemctl --user daemon-reload
    systemctl --user enable --now "${USER_SERVICES[@]}" 2>/dev/null || true
fi

# Clean temporary root script
rm -f "$ROOT_SH"

echo ""
echo "=========================================================="
echo "[+] Dotfiles installation completed successfully!"
echo "=========================================================="

if [ ${#POST_MESSAGES[@]} -gt 0 ]; then
    echo ""
    echo ":: Notes:"
    for msg in "${POST_MESSAGES[@]}"; do
        echo "   - $msg"
    done
fi

echo ""
echo ":: Useful commands:"
echo "   - Zapret manager: zapret"
echo "   - WARP status:    warp-cli status"
echo "   - Audio status:   wpctl status"
echo ""
