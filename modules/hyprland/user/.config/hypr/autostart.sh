#!/usr/bin/env bash
# Hyprland layout autostart (Omarchy & Arch)
# Replicates the niri-autostart layout:
# Workspace 1: AyuGram + Discord (tabbed group, left) | Brave (right)
set -euo pipefail

# 1. Core Desktop Services
gnome-keyring-daemon --start --components=secrets &
if command -v noctalia &>/dev/null; then
    noctalia &
elif command -v waybar &>/dev/null; then
    waybar &
fi

# 2. Workspace 1: Sequenced Layout Convergence
# Start AyuGram (initializes the left group)
AyuGram &
sleep 0.8

# Start Discord (merges into the left tabbed group with AyuGram)
discord &
sleep 0.8

# Start Brave (takes the right column)
if [[ -x /opt/brave-origin-bin/brave-origin ]]; then
    /opt/brave-origin-bin/brave-origin --new-window &
elif command -v brave &>/dev/null; then
    brave --new-window &
fi
