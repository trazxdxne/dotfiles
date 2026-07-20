#!/bin/bash
set -euo pipefail

echo "======================================"
echo "Obsidian LiveSync CouchDB & Tailscale Setup"
echo "======================================"

read -p "Enter CouchDB admin username [admin]: " COUCH_USER
COUCH_USER=${COUCH_USER:-admin}

read -s -p "Enter CouchDB admin password [password]: " COUCH_PASS
echo
COUCH_PASS=${COUCH_PASS:-password}

echo "Initializing CouchDB databases..."
curl -s -X PUT "http://${COUCH_USER}:${COUCH_PASS}@127.0.0.1:5984/_users" || true
curl -s -X PUT "http://${COUCH_USER}:${COUCH_PASS}@127.0.0.1:5984/_replicator" || true
curl -s -X PUT "http://${COUCH_USER}:${COUCH_PASS}@127.0.0.1:5984/_global_changes" || true

echo "Checking databases:"
curl -s -X GET "http://${COUCH_USER}:${COUCH_PASS}@127.0.0.1:5984/_all_dbs" | grep -q "_users" && echo "Success!" || echo "Check failed."

if command -v tailscale &> /dev/null; then
    echo "Setting up Tailscale Serve for CouchDB (port 5984)..."
    sudo tailscale serve --bg http://127.0.0.1:5984
    echo "Tailscale serve configured."
else
    echo "Tailscale is not installed. Skipping tailscale serve."
fi

echo "Setup complete."
