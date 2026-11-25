import os
import shutil
from pathlib import Path

from bypass import sysutil


def parse_zapret_conf(conf_path=None):
    path = conf_path or sysutil.ZAPRET_CONF_FILE
    cfg = {}
    if path.is_file():
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, val = line.split("=", 1)
            cfg[key.strip()] = val.strip().strip("'\"")
    return cfg


def get_available_zapret_strategies(cache_dir=None):
    base = cache_dir or sysutil.ZAPRET_CACHE_DIR
    strategies = []
    seen = set()
    search_dirs = [
        base / "custom-strategies",
        base / "zapret-discord-youtube-linux",
        base / "zapret-discord-youtube-linux" / "custom-strategies",
    ]
    for d in search_dirs:
        if d.is_dir():
            for p in sorted(d.glob("*.bat")):
                if p.name not in seen:
                    seen.add(p.name)
                    strategies.append(p.name)
    return strategies


def set_zapret_strategy(strategy_name, conf_path=None):
    path = conf_path or sysutil.ZAPRET_CONF_FILE
    lines = []
    found = False
    if path.is_file():
        for line in path.read_text(encoding="utf-8", errors="ignore").splitlines():
            if line.strip().startswith("strategy="):
                lines.append(f"strategy={strategy_name}")
                found = True
            else:
                lines.append(line)
    if not found:
        if not lines:
            lines = [
                "interface=any",
                "gamefiltertcp=false",
                "gamefilterudp=false",
                "backend=nftables",
            ]
        lines.append(f"strategy={strategy_name}")
    return sysutil.write_root_content("\n".join(lines) + "\n", path, mode="644")


def cmd_zapret(args):
    action = args.zapret_action
    target = args.target

    if action == "tui":
        bin_path = shutil.which("zapret-rust") or "/usr/local/bin/zapret-rust"
        if not Path(bin_path).exists():
            print(f"{sysutil.C_RED}error: zapret-rust not installed.{sysutil.C_RESET} Run ./system/setup-system.sh")
            return 1
        env = dict(os.environ)
        env["ZAPRET_CACHE_DIR"] = str(sysutil.ZAPRET_CACHE_DIR)
        os.execvpe(bin_path, [bin_path], env)

    if action == "status":
        running = sysutil.is_service_active(sysutil.ZAPRET_SERVICE)
        cfg = parse_zapret_conf()
        strat = cfg.get("strategy", "unconfigured")
        iface = cfg.get("interface", "any")
        state_str = f"{sysutil.C_GREEN}ACTIVE{sysutil.C_RESET}" if running else f"{sysutil.C_RED}INACTIVE{sysutil.C_RESET}"
        print(f"Zapret (zapret-rust): {state_str} (strategy: {strat}, interface: {iface})")
        return 0

    if action == "list":
        strategies = get_available_zapret_strategies()
        active = parse_zapret_conf().get("strategy")
        print(f"\n{sysutil.C_BOLD}:: Available zapret-rust Strategies{sysutil.C_RESET}")
        if not strategies:
            print(f"  {sysutil.C_DIM}(none downloaded yet — run 'zapret' and use Downloader){sysutil.C_RESET}\n")
            return 0
        for s in strategies:
            mark = f" {sysutil.C_GREEN}[active]{sysutil.C_RESET}" if s == active else ""
            print(f"  - {s}{mark}")
        print()
        return 0

    if action == "off":
        print(":: stopping zapret-rust.service...")
        ok, _, err = sysutil.run_cmd(["systemctl", "stop", sysutil.ZAPRET_SERVICE])
        if ok:
            print(f"{sysutil.C_GREEN}[+] Zapret stopped.{sysutil.C_RESET}")
            return 0
        print(f"{sysutil.C_RED}failed to stop zapret-rust:{sysutil.C_RESET} {err}")
        return 1

    if action in ("on", "restart", "strategy"):
        if action == "strategy":
            if not target:
                print(f"{sysutil.C_RED}error: specify strategy name (.bat).{sysutil.C_RESET}")
                return 1
            available = get_available_zapret_strategies()
            if available and target not in available:
                print(f"{sysutil.C_RED}error: strategy '{target}' not found.{sysutil.C_RESET}")
                return 1
            ok, _, err = set_zapret_strategy(target)
            if not ok:
                print(f"{sysutil.C_RED}failed to update {sysutil.ZAPRET_CONF_FILE}:{sysutil.C_RESET} {err}")
                return 1

        if not sysutil.ZAPRET_CONF_FILE.is_file():
            print(f"{sysutil.C_RED}error: {sysutil.ZAPRET_CONF_FILE} missing.{sysutil.C_RESET} Run 'zapret' TUI once to download dependencies and save config.")
            return 1

        verb = "start" if action == "on" else "restart"
        print(f":: {verb}ing {sysutil.ZAPRET_SERVICE}...")
        ok, _, err = sysutil.run_cmd(["systemctl", verb, sysutil.ZAPRET_SERVICE])
        if ok:
            strat = parse_zapret_conf().get("strategy", "default")
            print(f"{sysutil.C_GREEN}[+] Zapret active ({strat}).{sysutil.C_RESET}")
            return 0
        print(f"{sysutil.C_RED}failed to {verb} zapret-rust:{sysutil.C_RESET} {err}")
        return 1
    return 1
