import os
import re
import subprocess
import sys
from pathlib import Path

from bypass import sysutil


def run_fzf(items, prompt="bypass > ", header=None):
    cmd = ["fzf", "--prompt", prompt, "--height", "~45%", "--layout=reverse", "--border"]
    if header:
        cmd.extend(["--header", header])
    res = subprocess.run(
        cmd,
        input="\n".join(items),
        stdout=subprocess.PIPE,
        stderr=None,
        text=True,
    )
    if res.returncode == 0:
        return res.stdout.strip()
    return None


def get_active_vpn_service():
    ok, out, _ = sysutil.run_cmd(
        ["systemctl", "list-units", "--type=service", "--state=running", "awg-quick@*", "--no-legend"]
    )
    if ok and out:
        for line in out.splitlines():
            parts = line.split()
            if parts and parts[0].startswith("awg-quick@") and parts[0].endswith(".service"):
                return parts[0][len("awg-quick@") : -len(".service")]
    return None


def get_warp_status():
    if not sysutil.cmd_exists("warp-cli"):
        return "not_installed", ""
    ok, out, err = sysutil.run_cmd(["warp-cli", "status"])
    text = out or err
    lower = text.lower()
    if "connected" in lower and "disconnected" not in lower:
        return "connected", text
    if "connecting" in lower:
        return "connecting", text
    if "registration missing" in lower or "missing registration" in lower:
        return "unregistered", text
    if ok or "disconnected" in lower:
        return "disconnected", text
    return "unknown", text


def get_available_vpn_profiles():
    profiles = set()
    for search_dir in (sysutil.VPN_DIR, sysutil.SYS_VPN_DIR):
        if search_dir.is_dir():
            for p in search_dir.glob("*.conf"):
                profiles.add(p.stem)
    return sorted(profiles)


def validate_wireguard_conf(conf_path):
    path = Path(conf_path)
    if not path.is_file():
        return False, f"file not found: {path}"
    content = path.read_text(encoding="utf-8", errors="ignore")
    if "[Interface]" not in content or "[Peer]" not in content:
        return False, "invalid WireGuard/AWG config: missing [Interface] or [Peer]"
    if "PrivateKey" not in content:
        return False, "invalid WireGuard/AWG config: missing PrivateKey"
    return True, ""


def sanitize_profile_name(raw_name):
    return re.sub(r"[^A-Za-z0-9_.-]+", "_", raw_name.strip()).strip("._-")


def pick_conf_file():
    has_display = bool(os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY"))
    if has_display and sysutil.cmd_exists("zenity"):
        dl_dir = Path.home() / "Downloads"
        start_dir = str(dl_dir if dl_dir.is_dir() else Path.home())
        ok, out, _ = sysutil.run_cmd(
            [
                "zenity",
                "--file-selection",
                "--title=Select AmneziaWG / WireGuard Config",
                f"--filename={start_dir}/",
                "--file-filter=WireGuard configs (*.conf) | *.conf",
                "--file-filter=All files | *",
            ]
        )
        return out.splitlines()[0].strip() if ok and out else None

    if has_display and sysutil.cmd_exists("kdialog"):
        ok, out, _ = sysutil.run_cmd(
            ["kdialog", "--getopenfilename", str(Path.home()), "*.conf|WireGuard Configs"]
        )
        return out.splitlines()[0].strip() if ok and out else None

    candidates = []
    for base in (Path.home() / "Downloads", Path.home(), sysutil.VPN_DIR):
        if base.is_dir():
            candidates.extend(str(p) for p in sorted(base.glob("*.conf")))
    if candidates and sysutil.cmd_exists("fzf") and sys.stdin.isatty():
        sel = run_fzf(candidates, prompt="Select .conf > ")
        if sel:
            return sel

    if sys.stdin.isatty():
        try:
            entered = input("Path to .conf file: ").strip().strip("'\"")
            return entered or None
        except (KeyboardInterrupt, EOFError):
            return None
    return None


def import_vpn_profile(src_path, profile_name=None):
    ok, err = validate_wireguard_conf(src_path)
    if not ok:
        return False, err

    src = Path(src_path).expanduser().resolve()
    name = sanitize_profile_name(profile_name or src.stem)
    if not name:
        return False, "invalid profile name"

    sysutil.VPN_DIR.mkdir(parents=True, exist_ok=True)
    user_dest = sysutil.VPN_DIR / f"{name}.conf"
    user_dest.write_text(src.read_text(encoding="utf-8", errors="ignore"), encoding="utf-8")
    try:
        os.chmod(user_dest, 0o600)
    except OSError:
        pass

    sys_dest = sysutil.SYS_VPN_DIR / f"{name}.conf"
    ok, _, cmd_err = sysutil.install_root_file(user_dest, sys_dest, mode="600")
    if not ok:
        return False, f"saved user copy at {user_dest}, failed system install: {cmd_err}"
    return True, name


def stop_active_awg():
    active = get_active_vpn_service()
    if active:
        ok, _, err = sysutil.run_cmd(["systemctl", "stop", f"awg-quick@{active}.service"])
        return active, ok, err
    return None, True, ""


def ensure_warp_disconnected():
    state, _ = get_warp_status()
    if state in ("connected", "connecting"):
        ok, _, err = sysutil.run_cmd(["warp-cli", "disconnect"])
        return True, ok, err
    return False, True, ""


def cmd_vpn_warp(action):
    if action == "install":
        if sysutil.cmd_exists("warp-cli"):
            print(f"{sysutil.C_GREEN}[+] warp-cli is already installed.{sysutil.C_RESET}")
            return 0
        helper = "yay" if sysutil.cmd_exists("yay") else ("paru" if sysutil.cmd_exists("paru") else None)
        if not helper:
            print(f"{sysutil.C_RED}error: yay/paru not found to install cloudflare-warp-bin.{sysutil.C_RESET}")
            return 1
        print(f":: installing cloudflare-warp-bin via {helper}...")
        ok, _, err = sysutil.run_cmd([helper, "-S", "--needed", "--noconfirm", "cloudflare-warp-bin"], capture=False)
        if not ok:
            print(f"{sysutil.C_RED}failed to install cloudflare-warp-bin:{sysutil.C_RESET} {err}")
            return 1
        sysutil.run_cmd(["systemctl", "enable", "--now", sysutil.WARP_SERVICE])
        return 0

    if not sysutil.cmd_exists("warp-cli"):
        print(f"{sysutil.C_YELLOW}[!] cloudflare-warp-bin is not installed.{sysutil.C_RESET}")
        if sys.stdin.isatty() and input("Install cloudflare-warp-bin now? [y/N]: ").strip().lower() == "y":
            rc = cmd_vpn_warp("install")
            if rc != 0:
                return rc
        else:
            print("Run: bypass vpn warp install")
            return 1

    if action == "status":
        state, text = get_warp_status()
        print(f"WARP Status: {state}")
        if text:
            print(text)
        return 0

    if action == "register":
        state, _ = get_warp_status()
        if state != "unregistered":
            ok, out, _ = sysutil.run_cmd(["warp-cli", "registration", "show"])
            if ok and out:
                print(f"{sysutil.C_GREEN}[+] WARP already registered.{sysutil.C_RESET}")
                return 0
        print(":: registering new WARP device...")
        ok, out, err = sysutil.run_cmd(["warp-cli", "registration", "new"])
        if ok:
            print(f"{sysutil.C_GREEN}[+] WARP registration complete.{sysutil.C_RESET}")
            return 0
        print(f"{sysutil.C_RED}WARP registration failed:{sysutil.C_RESET} {err or out}")
        return 1

    if action == "off":
        ok, _, err = sysutil.run_cmd(["warp-cli", "disconnect"])
        if ok:
            print(f"{sysutil.C_GREEN}[+] WARP disconnected.{sysutil.C_RESET}")
            return 0
        print(f"{sysutil.C_RED}failed to disconnect WARP:{sysutil.C_RESET} {err}")
        return 1

    if action == "on":
        stopped_awg, ok_awg, err_awg = stop_active_awg()
        if stopped_awg:
            if not ok_awg:
                print(f"{sysutil.C_RED}failed to stop AmneziaWG ({stopped_awg}):{sysutil.C_RESET} {err_awg}")
                return 1
            print(f":: stopped AmneziaWG ({stopped_awg}) for mutual exclusion")
        if not sysutil.is_service_active(sysutil.WARP_SERVICE):
            sysutil.run_cmd(["systemctl", "start", sysutil.WARP_SERVICE])
        state, _ = get_warp_status()
        if state == "unregistered":
            rc = cmd_vpn_warp("register")
            if rc != 0:
                return rc
        ok, out, err = sysutil.run_cmd(["warp-cli", "connect"])
        if ok:
            print(f"{sysutil.C_GREEN}[+] WARP connected.{sysutil.C_RESET}")
            return 0
        print(f"{sysutil.C_RED}failed to connect WARP:{sysutil.C_RESET} {err or out}")
        return 1
    return 1


def _vpn_remove(target):
    if not target:
        print(f"{sysutil.C_RED}error: specify profile to remove.{sysutil.C_RESET}")
        return 1
    if get_active_vpn_service() == target:
        sysutil.run_cmd(["systemctl", "stop", f"awg-quick@{target}.service"])
    removed = False
    user_file = sysutil.VPN_DIR / f"{target}.conf"
    if user_file.is_file():
        user_file.unlink()
        removed = True
    sys_file = sysutil.SYS_VPN_DIR / f"{target}.conf"
    if sys_file.is_file():
        ok, _, err = sysutil.remove_root_file(sys_file)
        if not ok:
            print(f"{sysutil.C_RED}failed to remove {sys_file}:{sysutil.C_RESET} {err}")
            return 1
        removed = True
    if not removed:
        print(f"{sysutil.C_RED}error: profile '{target}' not found.{sysutil.C_RESET}")
        return 1
    print(f"{sysutil.C_GREEN}[+] Removed profile '{target}'.{sysutil.C_RESET}")
    return 0


def _vpn_edit(target):
    if not target:
        print(f"{sysutil.C_RED}error: specify profile to edit.{sysutil.C_RESET}")
        return 1
    user_file = sysutil.VPN_DIR / f"{target}.conf"
    sys_file = sysutil.SYS_VPN_DIR / f"{target}.conf"
    if not user_file.is_file() and sys_file.is_file():
        sysutil.VPN_DIR.mkdir(parents=True, exist_ok=True)
        user_file.write_text(sys_file.read_text(encoding="utf-8", errors="ignore"), encoding="utf-8")
    if not user_file.is_file():
        print(f"{sysutil.C_RED}error: profile '{target}' not found.{sysutil.C_RESET}")
        return 1
    editor = os.environ.get("EDITOR") or ("fresh" if sysutil.cmd_exists("fresh") else ("micro" if sysutil.cmd_exists("micro") else "nano"))
    sysutil.run_cmd([editor, str(user_file)], capture=False)
    ok, err = validate_wireguard_conf(user_file)
    if not ok:
        print(f"{sysutil.C_RED}error:{sysutil.C_RESET} {err}")
        return 1
    sysutil.install_root_file(user_file, sys_file, mode="600")
    print(f"{sysutil.C_GREEN}[+] Updated '{target}'.{sysutil.C_RESET}")
    return 0


def cmd_vpn(args):
    action = args.vpn_action
    target = args.target

    if action == "warp":
        warp_action = target or "status"
        if warp_action not in ("status", "on", "off", "register", "install"):
            print(f"{sysutil.C_RED}error: unknown warp action '{warp_action}'.{sysutil.C_RESET}")
            return 1
        return cmd_vpn_warp(warp_action)

    if action == "status":
        active = get_active_vpn_service()
        if active:
            print(f"Active AmneziaWG: {sysutil.C_GREEN}{active}{sysutil.C_RESET}")
            ok, out, _ = sysutil.run_cmd(["ip", "-brief", "address", "show", "dev", active])
            if ok and out:
                print(f"Interface: {out}")
        else:
            print("AmneziaWG: inactive")
        warp_state, _ = get_warp_status()
        if warp_state != "not_installed":
            print(f"Cloudflare WARP: {warp_state}")
        return 0

    if action == "list":
        profiles = get_available_vpn_profiles()
        active = get_active_vpn_service()
        print(f"\n{sysutil.C_BOLD}:: AmneziaWG Profiles{sysutil.C_RESET}")
        if not profiles:
            print(f"  {sysutil.C_DIM}(none — import with 'bypass vpn add'){sysutil.C_RESET}")
        for p in profiles:
            mark = f" {sysutil.C_GREEN}[active]{sysutil.C_RESET}" if p == active else ""
            print(f"  - {p}{mark}")
        warp_state, _ = get_warp_status()
        print(f"\n  warp-cli: {warp_state}\n")
        return 0

    if action == "add":
        chosen = target or pick_conf_file()
        if not chosen:
            print(f"{sysutil.C_YELLOW}[!] No config file selected.{sysutil.C_RESET}")
            return 1
        ok, res = import_vpn_profile(chosen, profile_name=getattr(args, "name", None))
        if ok:
            print(f"{sysutil.C_GREEN}[+] Imported VPN profile '{res}'.{sysutil.C_RESET}")
            return 0
        print(f"{sysutil.C_RED}error:{sysutil.C_RESET} {res}")
        return 1

    if action == "remove":
        return _vpn_remove(target)
    if action == "edit":
        return _vpn_edit(target)

    if action == "off":
        stopped = False
        active = get_active_vpn_service()
        if active:
            print(f":: stopping awg-quick@{active}.service...")
            ok, _, err = sysutil.run_cmd(["systemctl", "stop", f"awg-quick@{active}.service"])
            if not ok:
                print(f"{sysutil.C_RED}failed to stop {active}:{sysutil.C_RESET} {err}")
                return 1
            print(f"{sysutil.C_GREEN}[+] AmneziaWG stopped.{sysutil.C_RESET}")
            stopped = True
        had_warp, ok_w, err_w = ensure_warp_disconnected()
        if had_warp:
            if not ok_w:
                print(f"{sysutil.C_RED}failed to disconnect WARP:{sysutil.C_RESET} {err_w}")
                return 1
            print(f"{sysutil.C_GREEN}[+] WARP disconnected.{sysutil.C_RESET}")
            stopped = True
        if not stopped:
            print("VPN is already stopped.")
        return 0

    if action in ("on", "switch"):
        profiles = get_available_vpn_profiles()
        if not profiles:
            print(f"{sysutil.C_RED}error: no VPN profiles found.{sysutil.C_RESET} Run 'bypass vpn add' first.")
            return 1
        target = target or ("WARPw_93" if "WARPw_93" in profiles else profiles[0])
        if target not in profiles:
            print(f"{sysutil.C_RED}error: profile '{target}' not found.{sysutil.C_RESET}")
            print(f"Available: {', '.join(profiles)}")
            return 1
        had_warp, ok_w, err_w = ensure_warp_disconnected()
        if had_warp:
            if not ok_w:
                print(f"{sysutil.C_RED}failed to disconnect WARP:{sysutil.C_RESET} {err_w}")
                return 1
            print(":: disconnected WARP for mutual exclusion")
        active = get_active_vpn_service()
        if active and active != target:
            print(f":: stopping current profile {active}...")
            sysutil.run_cmd(["systemctl", "stop", f"awg-quick@{active}.service"])
        sys_target = sysutil.SYS_VPN_DIR / f"{target}.conf"
        if not sys_target.is_file() and (sysutil.VPN_DIR / f"{target}.conf").is_file():
            sysutil.install_root_file(sysutil.VPN_DIR / f"{target}.conf", sys_target, mode="600")
        print(f":: starting awg-quick@{target}.service...")
        ok, _, err = sysutil.run_cmd(["systemctl", "start", f"awg-quick@{target}.service"])
        if ok:
            print(f"{sysutil.C_GREEN}[+] Connected to {target}.{sysutil.C_RESET}")
            return 0
        print(f"{sysutil.C_RED}failed to start VPN:{sysutil.C_RESET} {err}")
        return 1
    return 1
