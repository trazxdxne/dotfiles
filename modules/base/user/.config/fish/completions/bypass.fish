complete -c bypass -f

complete -c bypass -n "__fish_use_subcommand" -a status -d "Show full bypass & network status"
complete -c bypass -n "__fish_use_subcommand" -a vpn -d "Manage AmneziaWG VPN tunnels"
complete -c bypass -n "__fish_use_subcommand" -a zapret -d "Manage Zapret DPI circumvention"
complete -c bypass -n "__fish_use_subcommand" -a dns -d "Manage system DNS resolvers"
complete -c bypass -n "__fish_use_subcommand" -a test -d "Run automated target health check"
complete -c bypass -n "__fish_use_subcommand" -a tune -d "Auto-benchmark Zapret strategies"
complete -c bypass -n "__fish_use_subcommand" -a menu -d "Interactive TUI or GUI menu"

complete -c bypass -n "__fish_seen_subcommand_from vpn" -a status -d "Show active VPN tunnel status"
complete -c bypass -n "__fish_seen_subcommand_from vpn" -a on -d "Start VPN tunnel"
complete -c bypass -n "__fish_seen_subcommand_from vpn" -a off -d "Stop active VPN tunnel"
complete -c bypass -n "__fish_seen_subcommand_from vpn" -a switch -d "Switch active profile"
complete -c bypass -n "__fish_seen_subcommand_from vpn" -a list -d "List available VPN profiles"

complete -c bypass -n "__fish_seen_subcommand_from zapret" -a status -d "Show Zapret daemon status"
complete -c bypass -n "__fish_seen_subcommand_from zapret" -a on -d "Start Zapret daemon"
complete -c bypass -n "__fish_seen_subcommand_from zapret" -a off -d "Stop Zapret daemon"
complete -c bypass -n "__fish_seen_subcommand_from zapret" -a strategy -d "Switch active strategy"
complete -c bypass -n "__fish_seen_subcommand_from zapret" -a list -d "List available strategies"
complete -c bypass -n "__fish_seen_subcommand_from zapret" -a restart -d "Restart Zapret daemon"

complete -c bypass -n "__fish_seen_subcommand_from dns" -a status -d "Show current DNS configuration"
complete -c bypass -n "__fish_seen_subcommand_from dns" -a list -d "List available DNS presets"
complete -c bypass -n "__fish_seen_subcommand_from dns" -a monitor -d "Live DNS monitor & AI benchmark (DnsConfUI)"
complete -c bypass -n "__fish_seen_subcommand_from dns" -a set -d "Apply DNS preset"
complete -c bypass -n "__fish_seen_subcommand_from dns; and __fish_seen_subcommand_from set" -a "geohide-ru geohide-eu geohide-us comss magicdns bezmezhau wlrus malw dagami dns-ai zapret-dns nextdns comss-alt nulls-proxy xbox-dns controld mullvad cloudflare quad9 adguard isp" -d "DNS Provider"
