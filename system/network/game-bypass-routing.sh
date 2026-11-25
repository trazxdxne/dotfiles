#!/usr/bin/env bash
set -euo pipefail

start() {
    sysctl -w net.ipv4.conf.all.rp_filter=2 >/dev/null 2>&1 || true
    sysctl -w net.ipv4.conf.default.rp_filter=2 >/dev/null 2>&1 || true
    for f in /proc/sys/net/ipv4/conf/*/rp_filter; do
        if [[ -f "$f" ]]; then
            echo 2 > "$f" 2>/dev/null || true
        fi
    done

    mkdir -p /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/game.slice/game-bypass.slice 2>/dev/null || true
    chown -R 1000:1000 /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/game.slice 2>/dev/null || true
    if command -v loginctl >/dev/null 2>&1; then
        for uid in $(loginctl list-users --no-legend 2>/dev/null | awk '{print $1}'); do
            mkdir -p "/sys/fs/cgroup/user.slice/user-${uid}.slice/user@${uid}.service/game.slice/game-bypass.slice" 2>/dev/null || true
            chown -R "${uid}:${uid}" "/sys/fs/cgroup/user.slice/user-${uid}.slice/user@${uid}.service/game.slice" 2>/dev/null || true
        done
    fi

    while ip rule show | grep -q "fwmark 0x51 lookup main"; do
        ip rule del fwmark 0x51 lookup main 2>/dev/null || break
    done
    while ip -6 rule show 2>/dev/null | grep -q "fwmark 0x51 lookup main"; do
        ip -6 rule del fwmark 0x51 lookup main 2>/dev/null || break
    done

    ip rule add fwmark 0x51 lookup main priority 10
    ip -6 rule add fwmark 0x51 lookup main priority 10 2>/dev/null || true

    nft delete table inet game_bypass 2>/dev/null || true

    NFT_RULES="table inet game_bypass {\n    chain output {\n        type route hook output priority -160; policy accept;\n"
    for cg in /sys/fs/cgroup/user.slice/user-*.slice/user@*.service/game.slice/game-bypass.slice; do
        if [[ -d "$cg" ]]; then
            rel_cg="${cg#/sys/fs/cgroup/}"
            NFT_RULES="${NFT_RULES}        socket cgroupv2 level 5 \"${rel_cg}\" mark set 0x51\n"
        fi
    done
    NFT_RULES="${NFT_RULES}    }\n    chain postrouting {\n        type nat hook postrouting priority srcnat; policy accept;\n        meta mark 0x51 masquerade\n    }\n}\n"

    printf "%b" "$NFT_RULES" | nft -f -
    printf ":: game-bypass routing initialized\n"
}

stop() {
    nft delete table inet game_bypass 2>/dev/null || true
    while ip rule show | grep -q "fwmark 0x51 lookup main"; do
        ip rule del fwmark 0x51 lookup main 2>/dev/null || break
    done
    while ip -6 rule show 2>/dev/null | grep -q "fwmark 0x51 lookup main"; do
        ip -6 rule del fwmark 0x51 lookup main 2>/dev/null || break
    done
    printf ":: game-bypass routing stopped\n"
}

case "${1:-start}" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    status)
        printf "=== IP Rules ===\n"
        ip rule show | grep 0x51 || true
        ip -6 rule show 2>/dev/null | grep 0x51 || true
        printf "=== NFTables Table ===\n"
        nft list table inet game_bypass 2>/dev/null || printf "table inet game_bypass not found\n"
        ;;
    *)
        printf "Usage: %s {start|stop|restart|status}\n" "$0" >&2
        exit 1
        ;;
esac
