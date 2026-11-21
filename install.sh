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

When run without -m or -a, an interactive selection menu is presented.
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

PYTHON_BIN=""
if command -v python3 &>/dev/null && python3 -c 'import tomllib' &>/dev/null; then
    PYTHON_BIN="python3"
elif command -v python &>/dev/null && python -c 'import tomllib' &>/dev/null; then
    PYTHON_BIN="python"
fi

# Load module definitions from modules.toml if python available
MOD_NAMES=()
MOD_DESCS=()
MOD_DEFAULTS=()

if [[ -n "$PYTHON_BIN" ]] && [[ -f "$DOTFILES_DIR/modules.toml" ]]; then
    while IFS=$'\t' read -r m_name m_always m_desc; do
        [[ -z "$m_name" ]] && continue
        MOD_NAMES+=("$m_name")
        MOD_DEFAULTS+=("$m_always")
        MOD_DESCS+=("$m_desc")
    done < <("$PYTHON_BIN" -c '
import tomllib
with open("modules.toml", "rb") as f:
    data = tomllib.load(f).get("modules", {})
for name, cfg in data.items():
    desc = cfg.get("description", "")
    always = "1" if cfg.get("always", False) else "0"
    print(f"{name}\t{always}\t{desc}")
' 2>/dev/null || true)
fi

if [[ ${#MOD_NAMES[@]} -eq 0 ]]; then
    for mod_dir in "$DOTFILES_DIR/modules"/*; do
        if [[ -d "$mod_dir/user" ]]; then
            m_name="$(basename "$mod_dir")"
            MOD_NAMES+=("$m_name")
            MOD_DESCS+=("Module $m_name")
            case "$m_name" in
                base|niri|noctalia|audio|network|reshade|antigravity)
                    MOD_DEFAULTS+=("1")
                    ;;
                *)
                    MOD_DEFAULTS+=("0")
                    ;;
            esac
        fi
    done
fi

MODULE_LIST=()
if [[ "${TARGET_MODULES[0]:-}" == "all" ]]; then
    MODULE_LIST=("${MOD_NAMES[@]}")
elif [[ ${#TARGET_MODULES[@]} -gt 0 ]]; then
    MODULE_LIST=("${TARGET_MODULES[@]}")
elif [[ ! -t 0 || ! -t 1 ]]; then
    for i in "${!MOD_NAMES[@]}"; do
        if [[ "${MOD_DEFAULTS[i]}" -eq 1 ]]; then
            MODULE_LIST+=("${MOD_NAMES[i]}")
        fi
    done
    printf ":: non-interactive session detected, selected default modules: %s\n" "${MODULE_LIST[*]}"
else
    MOD_SELECTED=("${MOD_DEFAULTS[@]}")
    while true; do
        printf "\n\033[1;34m:: Dotfiles Module Selection\033[0m\n"
        printf "Select modules to deploy via GNU Stow:\n\n"
        for i in "${!MOD_NAMES[@]}"; do
            mark=" "
            [[ "${MOD_SELECTED[i]}" -eq 1 ]] && mark="\033[1;32mX\033[0m"
            printf "  %2d) [%b] \033[1m%-12s\033[0m - %s\n" "$((i + 1))" "$mark" "${MOD_NAMES[i]}" "${MOD_DESCS[i]}"
        done
        printf "\nCommands: \033[1m<num>\033[0m to toggle (e.g. 1 3), \033[1m[a]\033[0mll, \033[1m[n]\033[0mone, \033[1m[d]\033[0mefaults, \033[1m[Enter]\033[0m confirm, \033[1m[q]\033[0muit\n"
        printf "Selection: "
        input=""
        read -r input || break
        input=$(echo "$input" | tr '[:upper:]' '[:lower:]' | xargs 2>/dev/null || echo "$input")
        case "$input" in
            "")
                selected_count=0
                for i in "${!MOD_SELECTED[@]}"; do
                    [[ "${MOD_SELECTED[i]}" -eq 1 ]] && ((selected_count++)) || true
                done
                if [[ $selected_count -eq 0 ]]; then
                    printf "warning: no modules selected. Press Enter again to proceed with 0 modules, or select modules: "
                    read -r confirm || break
                    [[ -z "$confirm" ]] && break
                else
                    break
                fi
                ;;
            q|quit|exit)
                printf ":: aborted by user\n"
                exit 0
                ;;
            a|all)
                for i in "${!MOD_SELECTED[@]}"; do
                    MOD_SELECTED[i]=1
                done
                ;;
            n|none)
                for i in "${!MOD_SELECTED[@]}"; do
                    MOD_SELECTED[i]=0
                done
                ;;
            d|default|defaults)
                for i in "${!MOD_SELECTED[@]}"; do
                    MOD_SELECTED[i]="${MOD_DEFAULTS[i]}"
                done
                ;;
            *)
                IFS=', ' read -r -a tokens <<< "$input"
                for tok in "${tokens[@]}"; do
                    if [[ "$tok" =~ ^[0-9]+$ ]]; then
                        idx=$((tok - 1))
                        if [[ $idx -ge 0 && $idx -lt ${#MOD_NAMES[@]} ]]; then
                            if [[ "${MOD_SELECTED[idx]}" -eq 1 ]]; then
                                MOD_SELECTED[idx]=0
                            else
                                MOD_SELECTED[idx]=1
                            fi
                        else
                            printf "warning: invalid module number %s\n" "$tok"
                        fi
                    fi
                done
                ;;
        esac
    done

    MODULE_LIST=()
    for i in "${!MOD_NAMES[@]}"; do
        if [[ "${MOD_SELECTED[i]}" -eq 1 ]]; then
            MODULE_LIST+=("${MOD_NAMES[i]}")
        fi
    done
fi

printf ":: active modules: %s\n" "${MODULE_LIST[*]}"

# Package installation if requested
if [[ "$INSTALL_PACKAGES" == true ]] && [[ -f "$DOTFILES_DIR/modules.toml" ]] && [[ -n "$PYTHON_BIN" ]]; then
    printf ":: resolving package dependencies\n"
    mapfile -t REQUIRED_PKGS < <("$PYTHON_BIN" -c '
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
for target_path in "$HOME/.config/fish/functions" "$HOME/.local/bin" "$HOME/.agents" "$HOME/.gemini"; do
    if [[ -L "$target_path" && ! -e "$target_path" ]]; then
        rm -f "$target_path"
    fi
done
mkdir -p "$HOME/.config/fish/functions" "$HOME/.local/bin" "$HOME/.gemini"

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

# Adapt user-specific home paths in antigravity mcp_config if running on a non-standard home
if [[ "$HOME" != "/home/trazxdxne" ]] && [[ -f "$DOTFILES_DIR/modules/antigravity/user/.gemini/config/plugins/ecc/mcp_config.json" ]]; then
    sed -i "s|/home/trazxdxne|$HOME|g" "$DOTFILES_DIR/modules/antigravity/user/.gemini/config/plugins/ecc/mcp_config.json" 2>/dev/null || true
fi

# Ensure user executable permissions
for script_file in "$HOME/.local/bin"/* "$DOTFILES_DIR/modules/hyprland/user/.config/hypr/autostart.sh"; do
    [[ -f "$script_file" ]] && chmod +x "$script_file" 2>/dev/null || true
done

# Ensure niri-autostart binary is present for Niri layout convergence (from original developer)
if [[ " ${MODULE_LIST[*]} " =~ " niri " ]] && ! command -v niri-autostart &>/dev/null; then
    printf ":: niri-autostart not found in PATH, checking original repository (partanskiy/niri-autostart)...\n"
    NIRI_AUTOSTART_DIR="$HOME/Projects/niri-autostart"
    if [[ ! -d "$NIRI_AUTOSTART_DIR/.git" ]]; then
        mkdir -p "$HOME/Projects"
        git clone "https://github.com/partanskiy/niri-autostart.git" "$NIRI_AUTOSTART_DIR" || true
    else
        printf ":: updating niri-autostart from upstream...\n"
        git -C "$NIRI_AUTOSTART_DIR" pull --ff-only 2>/dev/null || true
    fi
    if command -v cargo &>/dev/null && [[ -f "$NIRI_AUTOSTART_DIR/Cargo.toml" ]]; then
        printf ":: building niri-autostart with cargo...\n"
        cargo install --path "$NIRI_AUTOSTART_DIR" --root "$HOME/.local" --locked || true
    fi
fi

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
