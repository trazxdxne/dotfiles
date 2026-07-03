#!/usr/bin/env bash
# Update and rebuild qml-niri from source.
# Run this script whenever you want to pull upstream changes.
#
# Usage: ~/dotfiles/scripts/update-qml-niri.sh

set -e

REPO="$HOME/dotfiles/qml-niri"
INSTALL_PATH="/usr/lib/qt6/qml"

echo "==> Pulling latest qml-niri..."
git -C "$REPO" pull

echo "==> Building..."
cmake -B "$REPO/build" -DCMAKE_BUILD_TYPE=Release -S "$REPO"
cmake --build "$REPO/build" -j"$(nproc)"

echo "==> Installing to $INSTALL_PATH/Niri/ (needs root)..."
pkexec sh -c "cp -r '$REPO/build/Niri' '$INSTALL_PATH/'"

echo "==> Restarting Quickshell..."
qs --no-duplicate 2>/dev/null || true
pkill -x qs 2>/dev/null || true
sleep 0.5
qs &

echo "==> Done. qml-niri updated to: $(git -C "$REPO" describe --tags --always)"
