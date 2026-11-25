import argparse
import sys

from bypass import dns, probes, sysutil, vpn, zapret


def cmd_menu(_args):
    has_fzf = sysutil.cmd_exists("fzf") and sys.stdin.isatty()
    catalog = dns.load_dns_catalog()

    while True:
        vpn_active = vpn.get_active_vpn_service()
        warp_state, _ = vpn.get_warp_status()
        zap_active = sysutil.is_service_active(sysutil.ZAPRET_SERVICE)
        dns_active = dns.get_active_dns_provider()
        header = (
            f"VPN: {vpn_active or ('WARP' if warp_state == 'connected' else 'off')} "
            f"| Zapret: {'on' if zap_active else 'off'} | DNS: {dns_active}"
        )

        menu_items = [
            "1. VPN: Toggle / Switch AmneziaWG",
            "2. VPN: Import .conf (File Picker)",
            "3. WARP: Toggle Cloudflare WARP",
            "4. Zapret: Toggle Service",
            "5. Zapret: Switch Strategy",
            "6. Zapret: Open zapret-rust TUI",
            "7. DNS: Switch Blocky Preset",
            "8. DNS: Live Benchmark (Monitor)",
            "9. Test: Full Healthcheck & Split-Tunnel",
            "0. Exit",
        ]

        if has_fzf:
            choice = vpn.run_fzf(menu_items, prompt="bypass > ", header=header)
        else:
            print(f"\n{sysutil.C_BOLD}{sysutil.C_CYAN}:: Bypass Control{sysutil.C_RESET} ({header})")
            for item in menu_items:
                print(f"  {item}")
            try:
                choice = input("\nSelect [0-9]: ").strip()
            except (KeyboardInterrupt, EOFError):
                print()
                return 0

        if not choice or choice.startswith("0"):
            return 0
        if choice.startswith("1"):
            profiles = vpn.get_available_vpn_profiles()
            if not profiles:
                print("No profiles found. Use option 2 to import a .conf.")
                continue
            opts = (["[Disconnect AWG]"] if vpn_active else []) + profiles
            sel = vpn.run_fzf(opts, prompt="AWG Profile > ") if has_fzf else opts[0]
            if sel == "[Disconnect AWG]":
                vpn.cmd_vpn(argparse.Namespace(vpn_action="off", target=None))
            elif sel:
                vpn.cmd_vpn(argparse.Namespace(vpn_action="switch", target=sel))
        elif choice.startswith("2"):
            vpn.cmd_vpn(argparse.Namespace(vpn_action="add", target=None, name=None))
        elif choice.startswith("3"):
            vpn.cmd_vpn_warp("off" if warp_state == "connected" else "on")
        elif choice.startswith("4"):
            zapret.cmd_zapret(argparse.Namespace(zapret_action="off" if zap_active else "on", target=None))
        elif choice.startswith("5"):
            strats = zapret.get_available_zapret_strategies()
            if not strats:
                print("No strategies downloaded yet. Open zapret-rust TUI (option 6) -> Downloader.")
                continue
            sel = vpn.run_fzf(strats, prompt="Strategy > ") if has_fzf else strats[0]
            if sel:
                zapret.cmd_zapret(argparse.Namespace(zapret_action="strategy", target=sel))
        elif choice.startswith("6"):
            zapret.cmd_zapret(argparse.Namespace(zapret_action="tui", target=None))
        elif choice.startswith("7"):
            sel = vpn.run_fzf(list(catalog.keys()), prompt="DNS > ") if has_fzf else None
            if sel:
                dns.cmd_dns(argparse.Namespace(dns_action="set", provider=sel, profile_id=None))
        elif choice.startswith("8"):
            dns.cmd_dns(argparse.Namespace(dns_action="monitor", provider=None, profile_id=None))
            if has_fzf:
                input("Press Enter to continue...")
        elif choice.startswith("9"):
            probes.cmd_test(argparse.Namespace(full=True, check_game_bypass=True))
            if has_fzf:
                input("Press Enter to continue...")
