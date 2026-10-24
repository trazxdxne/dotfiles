#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Dotfiles Universal Installer (Arch + Fedora)
# Idempotent bootstrap with Network Pre-flight (Zapret + DNS + WARP)
# =============================================================================

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

# Privilege escalation detection
if [ "$EUID" -eq 0 ]; then
    echo "❌ Please run this script as a normal user. It uses pkexec/sudo for root operations."
    exit 1
fi

ELEVATE="sudo"
if command -v pkexec &> /dev/null; then
    ELEVATE="pkexec"
fi

# -----------------------------------------------------------------------------
# 1. Distro Detection
# -----------------------------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_LIKE="${ID_LIKE:-}"
else
    echo "❌ Cannot determine OS: /etc/os-release missing."
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
        echo "❌ Unsupported distribution: $DISTRO_ID (requires Arch-based or Fedora-based)."
        exit 1
esac

echo "=========================================================="
echo "🚀 Dotfiles Installer | Detected: $DISTRO ($DISTRO_ID)"
echo "=========================================================="

# -----------------------------------------------------------------------------
# 2. Pre-flight: Network Bootstrap (DNS -> Zapret -> WARP)
# -----------------------------------------------------------------------------
echo ""
echo "🌐 [Phase 0] Network Pre-flight Bootstrap..."

# 2.1 DNS over TLS (malw.link)
echo "  [1/4] Configuring DNS over TLS (malw.link)..."
$ELEVATE mkdir -p /etc/systemd/resolved.conf.d
if [ -f "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" ]; then
    $ELEVATE cp "$DOTFILES_DIR/modules/network/root/etc/systemd/resolved.conf.d/malw-dns.conf" /etc/systemd/resolved.conf.d/malw-dns.conf
fi
$ELEVATE systemctl enable --now systemd-resolved 2>/dev/null || true
$ELEVATE systemctl restart systemd-resolved 2>/dev/null || true

# 2.2 Zapret Bootstrap
echo "  [2/4] Setting up Zapret DPI bypass..."
ZAPRET_DIR="$DOTFILES_DIR/modules/network/zapret"
if [ -d "$ZAPRET_DIR" ]; then
    chmod +x "$ZAPRET_DIR/nfqws" "$ZAPRET_DIR/service.sh" "$ZAPRET_DIR"/auto_tune*.sh 2>/dev/null || true

    # Auto-detect default network interface
    DETECTED_IFACE=$(ip route show default 2>/dev/null | awk '/default/ {print $5}' | head -n1)
    if [ -z "$DETECTED_IFACE" ]; then
        DETECTED_IFACE="any"
    fi
    echo "        Detected network interface: $DETECTED_IFACE"

    if [ -f "$ZAPRET_DIR/conf.env.template" ]; then
        sed "s/__INTERFACE__/$DETECTED_IFACE/g" "$ZAPRET_DIR/conf.env.template" > "$ZAPRET_DIR/conf.env"
    fi

    # Install zapret systemd service
    $ELEVATE bash -c "cat > /etc/systemd/system/zapret_discord_youtube.service" <<EOF
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
EOF
    $ELEVATE systemctl daemon-reload
    $ELEVATE systemctl enable --now zapret_discord_youtube.service 2>/dev/null || true
fi

# 2.3 Repositories & WARP setup
echo "  [3/4] Setting up package repositories & Cloudflare WARP..."
if [ "$DISTRO" = "fedora" ]; then
    # RPMFusion (free + nonfree)
    if ! rpm -q rpmfusion-free-release &>/dev/null; then
        echo "        Installing RPMFusion repositories..."
        $ELEVATE dnf install -y \
            https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
            https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm 2>/dev/null || true
    fi

    # Cloudflare WARP repo
    if [ ! -f /etc/yum.repos.d/cloudflare-warp.repo ]; then
        echo "        Adding Cloudflare WARP repository..."
        $ELEVATE rpm --import https://pkg.cloudflareclient.com/pubkey.gpg 2>/dev/null || true
        curl -fsSl https://pkg.cloudflareclient.com/cloudflare-warp-ascii.repo | $ELEVATE tee /etc/yum.repos.d/cloudflare-warp.repo >/dev/null 2>&1 || true
    fi

    # COPRs
    $ELEVATE dnf copr enable -y solopasha/hyprland 2>/dev/null || true
    $ELEVATE dnf copr enable -y atim/gum 2>/dev/null || true

    # Install warp-cli if missing
    if ! command -v warp-cli &>/dev/null; then
        echo "        Installing cloudflare-warp..."
        $ELEVATE dnf install -y cloudflare-warp 2>/dev/null || true
    fi
elif [ "$DISTRO" = "arch" ]; then
    # Enable multilib if disabled
    if grep -q "^#\[multilib\]" /etc/pacman.conf; then
        echo "        Enabling multilib repository in pacman.conf..."
        $ELEVATE sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
    fi
fi

# Connect WARP
if command -v warp-cli &>/dev/null; then
    $ELEVATE systemctl enable --now warp-svc.service 2>/dev/null || true
    if ! warp-cli status 2>/dev/null | grep -iq "Connected"; then
        echo "        Connecting Cloudflare WARP..."
        warp-cli registration new 2>/dev/null || true
        warp-cli connect 2>/dev/null || true
        sleep 2
    fi
fi

# 2.4 Connectivity check
echo "  [4/4] Verifying network connectivity..."
if curl -s --connect-timeout 5 https://1.1.1.1 >/dev/null 2>&1 || curl -s --connect-timeout 5 https://google.com >/dev/null 2>&1; then
    echo "  ✅ Network is ONLINE and bypass is ACTIVE!"
else
    echo "  ⚠️ Warning: Direct curl probe timed out. Continuing with installation..."
fi

# -----------------------------------------------------------------------------
# 3. System Update & Essential Installer Tools
# -----------------------------------------------------------------------------
echo ""
echo "📦 [Phase 1] Ensuring Core Utilities & Updating System..."
if [ "$DISTRO" = "fedora" ]; then
    if ! command -v gum &>/dev/null; then
        $ELEVATE dnf install -y gum 2>/dev/null || true
    fi
    if ! command -v stow &>/dev/null; then
        $ELEVATE dnf install -y stow 2>/dev/null || true
    fi
    if ! command -v jq &>/dev/null; then
        $ELEVATE dnf install -y jq 2>/dev/null || true
    fi
elif [ "$DISTRO" = "arch" ]; then
    if ! command -v gum &>/dev/null || ! command -v stow &>/dev/null || ! command -v jq &>/dev/null; then
        $ELEVATE pacman -Sy --noconfirm --needed gum stow jq
    fi
fi

# -----------------------------------------------------------------------------
# 4. Audio Stack (Audio из коробки)
# -----------------------------------------------------------------------------
echo ""
echo "🔊 [Phase 2] Setting up PipeWire Audio Stack..."
if [ "$DISTRO" = "fedora" ]; then
    $ELEVATE dnf install -y wireplumber pipewire pipewire-pulseaudio pipewire-alsa 2>/dev/null || true
elif [ "$DISTRO" = "arch" ]; then
    $ELEVATE pacman -S --noconfirm --needed wireplumber pipewire pipewire-pulse pipewire-alsa 2>/dev/null || true
fi

systemctl --user daemon-reload
systemctl --user enable --now pipewire.service wireplumber.service 2>/dev/null || true
if [ "$DISTRO" = "fedora" ]; then
    systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 5. Module Selection & Parsing
# -----------------------------------------------------------------------------
echo ""
echo "📋 [Phase 3] Module Configuration..."

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

if command -v gum &> /dev/null; then
    echo "Select modules to install (Space to toggle, Enter to confirm):"
    SELECTED_OPTIONAL=$(printf "%s\n" "${OPTIONAL_MODULES[@]}" | gum choose --no-limit)
else
    echo "gum not found, selecting all optional modules by default."
    SELECTED_OPTIONAL=$(printf "%s\n" "${OPTIONAL_MODULES[@]}")
fi

SELECTED_MODULES=("${ALWAYS_MODULES[@]}")
while IFS= read -r line; do
    if [ -n "$line" ]; then
        mod_name=$(echo "$line" | awk '{print $1}')
        SELECTED_MODULES+=("$mod_name")
    fi
done <<< "$SELECTED_OPTIONAL"

echo ""
echo "Selected modules: ${SELECTED_MODULES[*]}"

# -----------------------------------------------------------------------------
# 6. GPU Detection
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
    echo "🎮 Detected GPU: $DETECTED_GPU"
else
    echo "⚠️ Could not auto-detect GPU."
    if command -v gum &> /dev/null; then
        DETECTED_GPU=$(gum choose "amd" "nvidia" "intel" "none")
    else
        DETECTED_GPU="none"
    fi
fi

# -----------------------------------------------------------------------------
# 7. Collect Packages, Services, Commands & Root Files
# -----------------------------------------------------------------------------
ROOT_SH="/tmp/dotfiles-root.sh"
cat > "$ROOT_SH" << 'EOF'
#!/bin/bash
set -euo pipefail
EOF
chmod +x "$ROOT_SH"

PACKAGES=()
ROOT_SERVICES=()
ROOT_COMMANDS=()
POST_MESSAGES=()
USER_SERVICES=()

for mod in "${SELECTED_MODULES[@]}"; do
    # General packages
    while read -r pkg; do
        [ -n "$pkg" ] && PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].packages[]? // empty")
    
    # Distro-specific packages
    while read -r pkg; do
        [ -n "$pkg" ] && PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].distro_packages.${DISTRO}[]? // empty")

    # GPU packages
    if [ -n "$DETECTED_GPU" ] && [ "$DETECTED_GPU" != "none" ]; then
        while read -r pkg; do
            [ -n "$pkg" ] && PACKAGES+=("$pkg")
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

    # Root package files (copied with preserved permissions)
    if [ -d "$DOTFILES_DIR/modules/$mod/root" ]; then
        echo "echo 'Deploying root configuration files for $mod...'" >> "$ROOT_SH"
        echo "cp -a --remove-destination \"$DOTFILES_DIR/modules/$mod/root/.\" /" >> "$ROOT_SH"
        
        # Hardware specific cleanup
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

# Write package installation to root script
if [ ${#PACKAGES[@]} -gt 0 ]; then
    # Deduplicate packages
    UNIQUE_PACKAGES=($(echo "${PACKAGES[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
    echo "echo 'Installing packages: ${UNIQUE_PACKAGES[*]}...'" >> "$ROOT_SH"
    if [ "$DISTRO" = "fedora" ]; then
        echo "dnf install -y --skip-unavailable ${UNIQUE_PACKAGES[*]}" >> "$ROOT_SH"
    elif [ "$DISTRO" = "arch" ]; then
        echo "pacman -S --noconfirm --needed ${UNIQUE_PACKAGES[*]}" >> "$ROOT_SH"
    fi
fi

# Write root services
if [ ${#ROOT_SERVICES[@]} -gt 0 ]; then
    echo "echo 'Enabling root services: ${ROOT_SERVICES[*]}...'" >> "$ROOT_SH"
    echo "systemctl enable --now ${ROOT_SERVICES[*]} 2>/dev/null || true" >> "$ROOT_SH"
fi

# Write root commands
if [ ${#ROOT_COMMANDS[@]} -gt 0 ]; then
    echo "echo 'Running root post-install commands...'" >> "$ROOT_SH"
    for cmd in "${ROOT_COMMANDS[@]}"; do
        echo "SUDO_USER=\"\${SUDO_USER:-\$USER}\" bash -c '$cmd'" >> "$ROOT_SH"
    done
fi

# Ensure default shell is set to fish if fish is in packages
if [[ " ${PACKAGES[*]} " =~ " fish " ]] || command -v fish &>/dev/null; then
    echo "echo 'Setting fish as default user shell...'" >> "$ROOT_SH"
    echo "FISH_BIN=\$(command -v fish 2>/dev/null || echo '/usr/bin/fish')" >> "$ROOT_SH"
    echo "TARGET_USER=\"\${SUDO_USER:-\$USER}\"" >> "$ROOT_SH"
    echo "if [ -x \"\$FISH_BIN\" ]; then" >> "$ROOT_SH"
    echo "    usermod -s \"\$FISH_BIN\" \"\$TARGET_USER\"" >> "$ROOT_SH"
    echo "fi" >> "$ROOT_SH"
fi

# -----------------------------------------------------------------------------
# 8. Execute Root Operations
# -----------------------------------------------------------------------------
echo ""
echo "🔐 [Phase 4] System (Root) Operations:"
cat "$ROOT_SH"
echo ""

EXECUTE_ROOT=true
if command -v gum &> /dev/null; then
    if ! gum confirm "Execute root operations?"; then
        EXECUTE_ROOT=false
    fi
fi

if [ "$EXECUTE_ROOT" = "true" ]; then
    $ELEVATE bash "$ROOT_SH"
else
    echo "⚠️ Skipped root operations."
fi

# -----------------------------------------------------------------------------
# 9. Stow User Configurations
# -----------------------------------------------------------------------------
echo ""
echo "🔗 [Phase 5] Stowing user configurations..."

for mod in "${SELECTED_MODULES[@]}"; do
    if [ -d "$DOTFILES_DIR/modules/$mod/user" ]; then
        echo "  Linking module: $mod..."
        # Stow with adopt and overwrite cleanly
        stow --adopt -R -t "$HOME" -d "$DOTFILES_DIR/modules/$mod" user 2>/dev/null || true
        # Restore any tracked repo file if stow --adopt pulled modified user states
        if [ -d "$DOTFILES_DIR/.git" ]; then
            git checkout -- "modules/$mod/user" 2>/dev/null || true
        fi
    fi
done

# Handle Zen Browser profiles dynamically if zen module is chosen
if [[ " ${SELECTED_MODULES[*]} " =~ " zen " ]] && [ -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" ]; then
    echo "  Applying Zen Browser user.js to profiles..."
    for zen_dir in "$HOME/.config/zen/"*Default* "$HOME/.config/zen/"*default*; do
        if [ -d "$zen_dir" ]; then
            cp -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" "$zen_dir/user.js"
            echo "  Linked user.js to: $zen_dir"
        fi
    done
fi

# -----------------------------------------------------------------------------
# 10. Enable User Services
# -----------------------------------------------------------------------------
if [ ${#USER_SERVICES[@]} -gt 0 ]; then
    echo ""
    echo "⚙️ [Phase 6] Enabling user services..."
    systemctl --user daemon-reload
    systemctl --user enable --now "${USER_SERVICES[@]}" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# 11. Cleanup & Summary
# -----------------------------------------------------------------------------
rm -f "$ROOT_SH"

echo ""
echo "=========================================================="
echo "🎉 Dotfiles installation completed successfully!"
echo "=========================================================="

if [ ${#POST_MESSAGES[@]} -gt 0 ]; then
    echo ""
    echo "📌 Notes:"
    for msg in "${POST_MESSAGES[@]}"; do
        echo "  - $msg"
    done
fi

echo ""
echo "💡 Quick tips:"
echo "  - Manage Zapret: type 'zapret' in terminal"
echo "  - Manage WARP:   type 'warp-cli status' / 'warp-cli connect'"
echo "  - Audio status:  type 'wpctl status'"
echo ""
