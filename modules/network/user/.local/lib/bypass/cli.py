import argparse
import sys

from bypass import dns, menu, probes, vpn, zapret


def build_parser():
    parser = argparse.ArgumentParser(description="Unified Network Bypass Controller (AWG, WARP, Zapret, Blocky DNS)")
    subparsers = parser.add_subparsers(dest="command")

    subparsers.add_parser("status", help="Show full network bypass status")

    p_vpn = subparsers.add_parser("vpn", help="Manage AmneziaWG and Cloudflare WARP")
    p_vpn.add_argument(
        "vpn_action",
        choices=["status", "on", "off", "switch", "list", "add", "remove", "edit", "warp"],
        nargs="?",
        default="status",
    )
    p_vpn.add_argument("target", nargs="?", default=None)
    p_vpn.add_argument("--name", default=None, help="Optional profile name for 'add'")

    p_zapret = subparsers.add_parser("zapret", help="Manage zapret-rust DPI service")
    p_zapret.add_argument(
        "zapret_action",
        choices=["status", "on", "off", "restart", "list", "strategy", "tui"],
        nargs="?",
        default="status",
    )
    p_zapret.add_argument("target", nargs="?", default=None)

    p_dns = subparsers.add_parser("dns", help="Manage Blocky DoH/DoT DNS presets")
    p_dns.add_argument("dns_action", choices=["status", "list", "set", "monitor", "test"], nargs="?", default="status")
    p_dns.add_argument("provider", nargs="?", default=None)
    p_dns.add_argument("profile_id", nargs="?", default=None)

    p_test = subparsers.add_parser("test", help="Run strict network health checks")
    p_test.add_argument("--full", action="store_true", help="Include stream chunk probe")
    p_test.add_argument("--check-game-bypass", action="store_true", default=True)
    p_test.add_argument("--no-game-bypass", dest="check_game_bypass", action="store_false")

    subparsers.add_parser("menu", help="Interactive terminal fzf menu")
    return parser


def main(argv=None):
    parser = build_parser()
    arg_list = sys.argv[1:] if argv is None else argv
    if not arg_list:
        return probes.cmd_status(argparse.Namespace())
    args = parser.parse_args(arg_list)
    dispatch = {
        "status": probes.cmd_status,
        "vpn": vpn.cmd_vpn,
        "zapret": zapret.cmd_zapret,
        "dns": dns.cmd_dns,
        "test": probes.cmd_test,
        "menu": menu.cmd_menu,
    }
    fn = dispatch.get(args.command)
    if fn:
        return fn(args) or 0
    parser.print_help()
    return 0
