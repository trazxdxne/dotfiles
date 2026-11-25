import os
import shutil
import subprocess
import tempfile
from pathlib import Path

CONFIG_DIR = Path.home() / ".config" / "bypass"
VPN_DIR = CONFIG_DIR / "vpn"
SYS_VPN_DIR = Path("/etc/amnezia/amneziawg")
SYS_RESOLVED_CONF = Path("/etc/systemd/resolved.conf.d/bypass-dns.conf")
SYS_BLOCKY_CONF = Path("/etc/blocky/blocky.yml")
ZAPRET_CACHE_DIR = Path(os.environ.get("ZAPRET_CACHE_DIR", "/var/lib/zapret-rust"))
ZAPRET_CONF_FILE = ZAPRET_CACHE_DIR / "conf.env"
ZAPRET_SERVICE = "zapret-rust.service"
BLOCKY_SERVICE = "blocky.service"
WARP_SERVICE = "warp-svc.service"
GAME_BYPASS_SERVICE = "game-bypass-routing.service"

C_RESET = "\033[0m"
C_BOLD = "\033[1m"
C_GREEN = "\033[32m"
C_RED = "\033[31m"
C_YELLOW = "\033[33m"
C_CYAN = "\033[36m"
C_DIM = "\033[2m"


def find_dotfiles_dir():
    try:
        p = Path(__file__).resolve()
        for parent in p.parents:
            if (parent / "modules.toml").is_file():
                return parent
    except Exception:
        pass
    for candidate in (Path.home() / ".dotfiles", Path.home() / "Projects" / "dotfiles"):
        if candidate.is_dir():
            return candidate
    return Path("/home/trazxdxne/Projects/dotfiles")


DOTFILES_DIR = find_dotfiles_dir()
CATALOG_PATH = DOTFILES_DIR / "system" / "network" / "dns" / "catalog.json"


def run_cmd(cmd, capture=True, input_text=None):
    try:
        res = subprocess.run(
            cmd,
            shell=isinstance(cmd, str),
            input=input_text,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
            text=True,
        )
        out = res.stdout.strip() if res.stdout else ""
        err = res.stderr.strip() if res.stderr else ""
        return res.returncode == 0, out, err
    except Exception as e:
        return False, "", str(e)


def cmd_exists(name):
    return shutil.which(name) is not None


def is_service_active(service_name):
    _, out, _ = run_cmd(["systemctl", "is-active", service_name])
    return out == "active"


def is_root():
    return getattr(os, "geteuid", lambda: 1000)() == 0


def install_root_file(src_path, dest_path, mode="644"):
    cmd = ["install", f"-Dm{mode}", str(src_path), str(dest_path)]
    if not is_root():
        cmd = ["pkexec", *cmd]
    return run_cmd(cmd)


def write_root_content(content, dest_path, mode="644"):
    with tempfile.NamedTemporaryFile("w", encoding="utf-8", delete=False) as tf:
        tf.write(content)
        tmp_path = Path(tf.name)
    try:
        return install_root_file(tmp_path, dest_path, mode=mode)
    finally:
        tmp_path.unlink(missing_ok=True)


def remove_root_file(dest_path):
    cmd = ["rm", "-f", str(dest_path)]
    if not is_root():
        cmd = ["pkexec", *cmd]
    return run_cmd(cmd)
