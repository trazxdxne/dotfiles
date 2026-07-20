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

if ! command -v gum &> /dev/null; then
    echo "Installing gum for interactivity..."
    sudo $PKG_INSTALL gum
fi

echo "Parsing modules.toml..."
# Convert TOML to JSON for jq
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
        # Extract module name (before space)
        mod_name=$(echo "$line" | awk '{print $1}')
        SELECTED_MODULES+=("$mod_name")
    fi
done <<< "$SELECTED_OPTIONAL"

if [ ${#SELECTED_MODULES[@]} -eq 0 ]; then
    echo "No modules selected. Exiting."
    exit 0
fi

echo "Generating /tmp/dotfiles-root.sh..."
ROOT_SH="/tmp/dotfiles-root.sh"
cat > "$ROOT_SH" << 'EOF'
#!/bin/bash
set -euo pipefail
EOF
chmod +x "$ROOT_SH"

PACKAGES=()
declare -A USER_SYMLINKS
declare -A ROOT_COPIES
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
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].packages.${DISTRO}[]? // empty")

    # Links
    while read -r src dest; do
        if [ -n "$src" ]; then
            USER_SYMLINKS["$src"]="$dest"
        fi
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].links | to_entries[]? | \"\(.key) \(.value)\"")

    # Root Copies
    while read -r src dest; do
        if [ -n "$src" ]; then
            ROOT_COPIES["$src"]="$dest"
        fi
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].root_copies | to_entries[]? | \"\(.key) \(.value)\"")

    # Root Services
    while read -r srv; do
        [ -n "$srv" ] && ROOT_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].root_services.enable[]? // empty")

    # Root Commands
    while read -r cmd; do
        [ -n "$cmd" ] && ROOT_COMMANDS+=("$cmd")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].root_commands | to_entries[]? | .value")

    # User Services
    while read -r srv; do
        [ -n "$srv" ] && USER_SERVICES+=("$srv")
    done < <(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].user_services | to_entries[]? | .key")

    # Post Message
    msg=$(echo "$JSON_DATA" | jq -r ".modules[\"$mod\"].post_message.text // empty")
    if [ -n "$msg" ]; then
        POST_MESSAGES+=("$msg")
    fi
done

# Write to root script
if [ ${#PACKAGES[@]} -gt 0 ]; then
    echo "echo 'Installing packages...'" >> "$ROOT_SH"
    echo "$PKG_INSTALL ${PACKAGES[*]}" >> "$ROOT_SH"
fi

if [ ${#ROOT_COPIES[@]} -gt 0 ]; then
    echo "echo 'Copying root files...'" >> "$ROOT_SH"
    for src in "${!ROOT_COPIES[@]}"; do
        dest="${ROOT_COPIES[$src]}"
        echo "if [ -f \"$dest\" ]; then cp \"$dest\" \"${dest}.bak_\$(date +%Y%m%d_%H%M%S)\"; fi" >> "$ROOT_SH"
        echo "mkdir -p \"\$(dirname \"$dest\")\"" >> "$ROOT_SH"
        echo "cp \"$DOTFILES_DIR/$src\" \"$dest\"" >> "$ROOT_SH"
    done
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

echo "Creating user symlinks..."
for src in "${!USER_SYMLINKS[@]}"; do
    dest="${USER_SYMLINKS[$src]}"
    eval dest="$dest" # expand ~
    mkdir -p "$(dirname "$dest")"
    if [ -d "$dest" ] && [ ! -L "$dest" ]; then
        mv "$dest" "${dest}.bak_\$(date +%Y%m%d_%H%M%S)"
    fi
    ln -sfn "$DOTFILES_DIR/$src" "$dest"
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
