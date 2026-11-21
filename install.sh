#!/usr/bin/env bash
# Dotfiles Installer & GNU Stow Overlay
# Fast, unprivileged, seamless user-space environment deployer.
set -euo pipefail

if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    printf "error: please run as your normal user, not root\n" >&2
    exit 1
fi

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DOTFILES_DIR"

INSTALL_PACKAGES=false
TARGET_MODULES=()

usage() {
    cat << 'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  -p, --packages    Install missing system packages (Arch/CachyOS via pacman & yay)
  -m, --modules     Comma-separated list of modules to install (e.g. base,niri,hyprland)
  -a, --all         Install all available modules
  -h, --help        Show this help message
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--packages)
            INSTALL_PACKAGES=true
            shift
            ;;
        -m|--modules)
            IFS=',' read -r -a TARGET_MODULES <<< "$2"
            shift 2
            ;;
        -a|--all)
            TARGET_MODULES=("all")
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            printf "warning: unknown option %s\n" "$1" >&2
            shift
            ;;
    esac
done

# Check for stow
if ! command -v stow &>/dev/null; then
    printf ":: stow is missing. Attempting to install via pacman...\n"
    if command -v pkexec &>/dev/null; then
        pkexec pacman -S --needed --noconfirm stow
    elif command -v sudo &>/dev/null; then
        sudo pacman -S --needed --noconfirm stow
    else
        printf "error: GNU Stow is required. Please install stow first.\n" >&2
        exit 1
    fi
fi

# Load module definitions from modules.toml if python3 available
MODULE_LIST=()
if [[ ${#TARGET_MODULES[@]} -eq 0 ]]; then
    if command -v python3 &>/dev/null && [[ -f "$DOTFILES_DIR/modules.toml" ]]; then
        mapfile -t MODULE_LIST < <(python3 -c '
import tomllib
with open("modules.toml", "rb") as f:
    data = tomllib.load(f).get("modules", {})
for name, cfg in data.items():
    if cfg.get("always", False):
        print(name)
' 2>/dev/null || true)
    fi
    if [[ ${#MODULE_LIST[@]} -eq 0 ]]; then
        MODULE_LIST=("base" "niri" "hyprland" "noctalia" "audio" "reshade" "antigravity")
    fi
elif [[ "${TARGET_MODULES[0]}" == "all" ]]; then
    for mod_dir in "$DOTFILES_DIR/modules"/*; do
        if [[ -d "$mod_dir/user" ]]; then
            MODULE_LIST+=("$(basename "$mod_dir")")
        fi
    done
else
    MODULE_LIST=("${TARGET_MODULES[@]}")
fi

printf ":: active modules: %s\n" "${MODULE_LIST[*]}"

# Package installation if requested
if [[ "$INSTALL_PACKAGES" == true ]] && [[ -f "$DOTFILES_DIR/modules.toml" ]] && command -v python3 &>/dev/null; then
    printf ":: resolving package dependencies\n"
    mapfile -t REQUIRED_PKGS < <(python3 -c '
import sys, tomllib
with open("modules.toml", "rb") as f:
    data = tomllib.load(f).get("modules", {})
active = sys.argv[1:]
pkgs = set()
for mod in active:
    if mod in data:
        pkgs.update(data[mod].get("packages", []))
for p in sorted(pkgs):
    print(p)
' "${MODULE_LIST[@]}" 2>/dev/null || true)

    TO_INSTALL_PACMAN=()
    TO_INSTALL_AUR=()

    for pkg in "${REQUIRED_PKGS[@]}"; do
        base_pkg="${pkg%-bin}"
        if ! pacman -Q "$pkg" &>/dev/null && ! pacman -Q "$base_pkg" &>/dev/null; then
            if pacman -Si "$pkg" &>/dev/null; then
                TO_INSTALL_PACMAN+=("$pkg")
            elif command -v yay &>/dev/null; then
                TO_INSTALL_AUR+=("$pkg")
            fi
        fi
    done

    if [[ ${#TO_INSTALL_PACMAN[@]} -gt 0 ]]; then
        printf ":: installing official packages: %s\n" "${TO_INSTALL_PACMAN[*]}"
        if command -v pkexec &>/dev/null; then
            pkexec pacman -S --needed --noconfirm "${TO_INSTALL_PACMAN[@]}"
        else
            sudo pacman -S --needed --noconfirm "${TO_INSTALL_PACMAN[@]}"
        fi
    fi

    if [[ ${#TO_INSTALL_AUR[@]} -gt 0 ]]; then
        printf ":: installing AUR packages: %s\n" "${TO_INSTALL_AUR[*]}"
        yay -S --needed --noconfirm "${TO_INSTALL_AUR[@]}"
    fi
fi

# Clean up broken symlinks in standard target dirs
for target_path in "$HOME/.config/fish/functions" "$HOME/.local/bin" "$HOME/.agents"; do
    if [[ -L "$target_path" && ! -e "$target_path" ]]; then
        rm -f "$target_path"
    fi
done
mkdir -p "$HOME/.config/fish/functions" "$HOME/.local/bin"

# Stow modules into $HOME
printf ":: deploying user configurations via GNU Stow\n"
for mod in "${MODULE_LIST[@]}"; do
    user_dir="$DOTFILES_DIR/modules/$mod/user"
    if [[ -d "$user_dir" ]]; then
        printf "   -> stowing %s\n" "$mod"
        
        # Check and resolve conflicting unmanaged files
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
                    [[ -e "$bak_path" ]] && bak_path="${conflict_path}.bak.$(date +%s)"
                    printf "      backing up conflict: %s -> %s\n" "$conflict_path" "$bak_path"
                    mv "$conflict_path" "$bak_path"
                fi
            done <<< "$stow_conflicts"
        fi

        if ! stow -R --no-folding -t "$HOME" -d "$DOTFILES_DIR/modules/$mod" user; then
            printf "warning: failed to stow module: %s\n" "$mod" >&2
        fi
    fi
done

# Zen browser user.js copy if zen is present
if [[ -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" ]]; then
    for zen_dir in "$HOME/.config/zen/"*Default* "$HOME/.config/zen/"*default*; do
        if [[ -d "$zen_dir" ]]; then
            cp -f "$DOTFILES_DIR/modules/zen/user/.config/zen/user.js" "$zen_dir/user.js"
        fi
    done
fi

# Ensure user executable permissions
for script_file in "$HOME/.local/bin"/*; do
    [[ -f "$script_file" ]] && chmod +x "$script_file" 2>/dev/null || true
done

# Activate audio user services
if command -v systemctl &>/dev/null; then
    systemctl --user daemon-reload 2>/dev/null || true
    for srv in pipewire.service wireplumber.service; do
        systemctl --user enable --now "$srv" 2>/dev/null || true
    done
fi

# Switch shell to fish if installed
FISH_BIN=$(command -v fish 2>/dev/null || printf "")
if [[ -n "$FISH_BIN" ]]; then
    CURRENT_SHELL=$(getent passwd "$USER" 2>/dev/null | cut -d: -f7 || printf "")
    if [[ "$CURRENT_SHELL" != "$FISH_BIN" ]]; then
        printf ":: notice: default shell is currently %s. To change to fish, run: chsh -s %s\n" "$CURRENT_SHELL" "$FISH_BIN"
    fi
fi

printf ":: dotfiles deployment completed successfully!\n"
