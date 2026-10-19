#!/bin/bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

if command -v pacman &> /dev/null; then
    DISTRO="arch"
    PKG_INSTALL="pacman -S --noconfirm"
elif command -v dnf &> /dev/null; then
    DISTRO="fedora"
    PKG_INSTALL="dnf install -y"
else
    echo "Unsupported distribution (not arch or fedora)."
    exit 1
fi

if [ "$DISTRO" = "fedora" ]; then
    echo "Enabling Fedora COPR repositories..."
    sudo dnf copr enable -y solopasha/hyprland || true
    sudo dnf copr enable -y atim/gum || true
fi

if ! command -v gum &> /dev/null; then
    echo "Installing gum for interactivity..."
    sudo $PKG_INSTALL gum
fi

if ! command -v stow &> /dev/null; then
    echo "Installing stow..."
    sudo $PKG_INSTALL stow
fi

echo "Parsing modules.toml..."
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

echo "Select modules to install (Space to toggle, Enter to confirm):"
SELECTED_OPTIONAL=$(printf "%s\n" "${OPTIONAL_MODULES[@]}" | gum choose --no-limit)

SELECTED_MODULES=("${ALWAYS_MODULES[@]}")
while IFS= read -r line; do
    if [ -n "$line" ]; then
        mod_name=$(echo "$line" | awk '{print $1}')
        SELECTED_MODULES+=("$mod_name")
    fi
done <<< "$SELECTED_OPTIONAL"

if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
    echo "No modules selected. Exiting."
    exit 0
fi

# Detect GPU
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
    echo "Auto-detected GPU: $DETECTED_GPU"
else
    echo "Could not auto-detect GPU. Please select your primary GPU:"
    DETECTED_GPU=$(gum choose "amd" "nvidia" "intel" "none")
fi

echo "Generating /tmp/dotfiles-root.sh..."
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
    # Packages
    while read -r pkg; do
        [ -n "$pkg" ] && PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].packages[]? // empty")
    
    # Distro-specific packages
    while read -r pkg; do
        [ -n "$pkg" ] && PACKAGES+=("$pkg")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].distro_packages.${DISTRO}[]? // empty")

    # GPU-specific packages
    if [ -n "$DETECTED_GPU" ]; then
        while read -r pkg; do
            [ -n "$pkg" ] && PACKAGES+=("$pkg")
        done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].gpu_packages.${DETECTED_GPU}.${DISTRO}.packages[]? // empty")
    fi

    # Root Services
    while read -r srv; do
        [ -n "$srv" ] && ROOT_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].root_services.enable[]? // empty")

    # Root Commands
    while read -r cmd; do
        [ -n "$cmd" ] && ROOT_COMMANDS+=("$cmd")
    done < <(echo "$JSON_DATA" | jq -r "(.modules[\"$mod\"].root_commands // {}) | to_entries[]? | .value")

    # User Services
    while read -r srv; do
        [ -n "$srv" ] && USER_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r "(.modules[\"$mod\"].user_services // {}) | to_entries[]? | .key")

    # Post Message
    msg=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].post_message.text // empty")
    if [ -n "$msg" ]; then
        POST_MESSAGES+=("$msg")
    fi

    # Root package files (copied, not stowed, to ensure proper permissions in /etc)
    if [ -d "$DOTFILES_DIR/modules/$mod/root" ]; then
        echo "echo 'Copying root package files for $mod...'" >> "$ROOT_SH"
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

# Write to root script
if [ ${#PACKAGES[@]} -gt 0 ]; then
    echo "echo 'Installing packages...'" >> "$ROOT_SH"
    echo "$PKG_INSTALL ${PACKAGES[*]}" >> "$ROOT_SH"
fi

if [ ${#ROOT_SERVICES[@]} -gt 0 ]; then
    echo "echo 'Enabling root services...'" >> "$ROOT_SH"
    echo "systemctl enable --now ${ROOT_SERVICES[*]}" >> "$ROOT_SH"
fi

if [ ${#ROOT_COMMANDS[@]} -gt 0 ]; then
    echo "echo 'Running root commands...'" >> "$ROOT_SH"
    for cmd in "${ROOT_COMMANDS[@]}"; do
        echo "SUDO_USER=\"\${SUDO_USER:-\$USER}\" bash -c '$cmd'" >> "$ROOT_SH"
    done
fi

echo "Summary of root operations (to be executed via pkexec):"
cat "$ROOT_SH"
echo ""

if gum confirm "Execute root operations?"; then
    pkexec bash "$ROOT_SH"
else
    echo "Skipped root operations."
fi

echo "Stowing user packages..."
for mod in "${SELECTED_MODULES[@]}"; do
    if [ -d "$DOTFILES_DIR/modules/$mod/user" ]; then
        echo "Stowing user package for $mod..."
        stow --adopt -R -t "$HOME" -d "$DOTFILES_DIR/modules/$mod" user
        git checkout -- "modules/$mod/user"
    fi
done

if [ ${#USER_SERVICES[@]} -gt 0 ]; then
    echo "Enabling user services..."
    systemctl --user daemon-reload
    systemctl --user enable --now "${USER_SERVICES[@]}"
fi

echo "Cleanup..."
rm -f "$ROOT_SH"

if [ ${#POST_MESSAGES[@]} -gt 0 ]; then
    echo ""
    echo "========================================"
    echo "Post-install messages:"
    for msg in "${POST_MESSAGES[@]}"; do
        echo "- $msg"
    done
    echo "========================================"
fi

echo "Done!"
