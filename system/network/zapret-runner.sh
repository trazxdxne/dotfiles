#!/usr/bin/env bash
set -euo pipefail

RUN_DIR="/run"
PID_FILE="$RUN_DIR/zapret.pid"
CONFIG_DIR="/etc/bypass"
STRATEGIES_DIR="$CONFIG_DIR/strategies"
ACTIVE_STRATEGY_FILE="$CONFIG_DIR/active_strategy"
FALLBACK_DOTFILES_DIR="/home/trazxdxne/Projects/dotfiles/system/network/zapret-strategies"

NFT_TABLE="inet zapretunix"
NFT_MARK="0x40000000"
NFT_QUEUE_NUM=220

find_nfqws_bin() {
    for bin_path in "/opt/zapret/nfqws" "/usr/bin/nfqws" "/usr/local/bin/nfqws" "/home/trazxdxne/Projects/dotfiles/system/zapret/nfqws"; do
        if [[ -x "$bin_path" ]]; then
            printf "%s" "$bin_path"
            return 0
        fi
    done
    command -v nfqws || return 1
}

cleanup_rules() {
    if command -v nft >/dev/null 2>&1; then
        if nft list tables 2>/dev/null | grep -q "zapretunix"; then
            nft delete table inet zapretunix 2>/dev/null || true
        fi
    fi
}

stop_daemon() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
            sleep 0.5
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
    fi
    pkill -f "nfqws.*zapretunix" 2>/dev/null || true
    cleanup_rules
}

apply_nft_rules() {
    local tcp_ports="$1"
    local udp_ports="$2"

    cleanup_rules

    local nft_rules="table inet zapretunix {
    chain post {
        type filter hook postrouting priority mangle; policy accept;
"
    if [[ -n "$tcp_ports" ]]; then
        nft_rules="${nft_rules}        meta mark and ${NFT_MARK} == 0 tcp dport { ${tcp_ports} } ct original packets 1-6 queue num ${NFT_QUEUE_NUM} bypass\n"
    fi
    if [[ -n "$udp_ports" ]]; then
        nft_rules="${nft_rules}        meta mark and ${NFT_MARK} == 0 udp dport { ${udp_ports} } ct original packets 1-6 queue num ${NFT_QUEUE_NUM} bypass\n"
    fi
    nft_rules="${nft_rules}    }
    chain pre {
        type filter hook prerouting priority filter; policy accept;
"
    if [[ -n "$tcp_ports" ]]; then
        nft_rules="${nft_rules}        tcp sport { ${tcp_ports} } ct reply packets 1-3 queue num ${NFT_QUEUE_NUM} bypass\n"
    fi
    nft_rules="${nft_rules}    }
}"

    printf "%b" "$nft_rules" | nft -f -
}

start_daemon() {
    local requested_strategy="${1:-}"
    local strategy_name=""

    if [[ -n "$requested_strategy" ]]; then
        strategy_name="$requested_strategy"
    elif [[ -f "$ACTIVE_STRATEGY_FILE" ]]; then
        strategy_name=$(cat "$ACTIVE_STRATEGY_FILE" | tr -d '[:space:]')
    fi

    [[ -z "$strategy_name" ]] && strategy_name="discord_youtube"

    local strategy_file=""
    if [[ -f "$STRATEGIES_DIR/${strategy_name}.conf" ]]; then
        strategy_file="$STRATEGIES_DIR/${strategy_name}.conf"
    elif [[ -f "$FALLBACK_DOTFILES_DIR/${strategy_name}.conf" ]]; then
        strategy_file="$FALLBACK_DOTFILES_DIR/${strategy_name}.conf"
    elif [[ -f "${strategy_name}" ]]; then
        strategy_file="${strategy_name}"
    else
        printf "error: strategy %s not found\n" "$strategy_name" >&2
        return 1
    fi

    stop_daemon

    local TCP_PORTS=""
    local UDP_PORTS=""
    local NFQWS_OPT=""
    local NAME=""

    # shellcheck disable=SC1090
    source "$strategy_file"

    if [[ -z "$TCP_PORTS" && -z "$UDP_PORTS" ]]; then
        printf "error: no ports defined in strategy %s\n" "$strategy_file" >&2
        return 1
    fi

    local nfqws_bin
    nfqws_bin=$(find_nfqws_bin) || {
        printf "error: nfqws binary not found in standard paths\n" >&2
        return 1
    }

    apply_nft_rules "$TCP_PORTS" "$UDP_PORTS"

    mkdir -p "$CONFIG_DIR"
    printf "%s" "$strategy_name" > "$ACTIVE_STRATEGY_FILE"

    local cmd=("$nfqws_bin" "--daemon" "--pidfile=$PID_FILE" "--dpi-desync-fwmark=$NFT_MARK" "--qnum=$NFT_QUEUE_NUM")
    # shellcheck disable=SC2086
    eval cmd+=($NFQWS_OPT)

    "${cmd[@]}"
    printf ":: zapret started using strategy: %s\n" "${NAME:-$strategy_name}"
}

status_daemon() {
    local running=false
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null || true)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            running=true
        fi
    fi

    if $running; then
        local active="unknown"
        [[ -f "$ACTIVE_STRATEGY_FILE" ]] && active=$(cat "$ACTIVE_STRATEGY_FILE")
        printf "Status: running (pid %s, strategy: %s)\n" "$(cat "$PID_FILE")" "$active"
        if command -v nft >/dev/null 2>&1; then
            nft list table inet zapretunix 2>/dev/null || printf "warning: nft table zapretunix missing\n"
        fi
        return 0
    else
        printf "Status: stopped\n"
        return 3
    fi
}

case "${1:-start}" in
    start)
        start_daemon "${2:-}"
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        start_daemon "${2:-}"
        ;;
    status)
        status_daemon
        ;;
    *)
        printf "Usage: %s {start|stop|restart|status} [strategy_name]\n" "$0" >&2
        exit 1
        ;;
esac
