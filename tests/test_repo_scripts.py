import json
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent


def test_dns_catalog_valid_json():
    catalog_path = REPO_ROOT / "system" / "network" / "dns" / "catalog.json"
    data = json.loads(catalog_path.read_text(encoding="utf-8"))
    assert len(data) >= 15
    for key, val in data.items():
        assert isinstance(key, str) and key
        assert "name" in val and "mode" in val


def test_niri_config_has_no_bypass_fuzzel_binding():
    niri_cfg = (REPO_ROOT / "modules" / "niri" / "user" / ".config" / "niri" / "config.kdl").read_text(
        encoding="utf-8"
    )
    assert "bypass" not in niri_cfg
    assert "Mod+Shift+V" not in niri_cfg


def test_zapret_fish_uses_zapret_rust_and_cache_dir():
    fish_fn = (
        REPO_ROOT / "modules" / "base" / "user" / ".config" / "fish" / "functions" / "zapret.fish"
    ).read_text(encoding="utf-8")
    assert "zapret-rust" in fish_fn
    assert "ZAPRET_CACHE_DIR /var/lib/zapret-rust" in fish_fn


def test_polkit_and_routing_rules():
    polkit = (REPO_ROOT / "system" / "hardware" / "40-network-bypass.rules").read_text(encoding="utf-8")
    for unit in ("zapret-rust.service", "blocky.service", "warp-svc.service", "game-bypass-routing.service", "awg-quick@"):
        assert unit in polkit

    routing = (REPO_ROOT / "system" / "network" / "game-bypass-routing.sh").read_text(encoding="utf-8")
    assert "priority 10" in routing


def test_legacy_zapret_artifacts_removed():
    assert not (REPO_ROOT / "system" / "zapret").exists()
    assert not (REPO_ROOT / "system" / "network" / "zapret-runner.sh").exists()
    assert not (REPO_ROOT / "system" / "network" / "zapret-strategies").exists()
    assert not (REPO_ROOT / "system" / "network" / "zapret.service").exists()


@pytest.mark.parametrize(
    "script_rel",
    [
        "install.sh",
        "system/setup-system.sh",
        "system/network/game-bypass-routing.sh",
        "modules/network/user/.local/bin/game-bypass",
    ],
)
def test_bash_syntax_when_available(script_rel):
    bash_bin = shutil.which("bash")
    if not bash_bin:
        git_bash = Path(r"C:\Program Files\Git\bin\bash.exe")
        if git_bash.is_file():
            bash_bin = str(git_bash)
    if not bash_bin:
        pytest.skip("bash not installed")
    res = subprocess.run([bash_bin, "-n", str(REPO_ROOT / script_rel)], capture_output=True, text=True)
    assert res.returncode == 0, res.stderr


def test_fish_syntax_when_available():
    fish_bin = shutil.which("fish")
    if not fish_bin:
        pytest.skip("fish not installed")
    for fish_file in REPO_ROOT.rglob("*.fish"):
        res = subprocess.run([fish_bin, "-n", str(fish_file)], capture_output=True, text=True)
        assert res.returncode == 0, f"{fish_file}: {res.stderr}"
