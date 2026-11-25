import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
RESHADE_STEAM = REPO_ROOT / "modules" / "reshade" / "user" / ".local" / "bin" / "reshade-steam"


def _bash():
    bash_bin = shutil.which("bash")
    if not bash_bin:
        git_bash = Path(r"C:\Program Files\Git\bin\bash.exe")
        if git_bash.is_file():
            bash_bin = str(git_bash)
    return bash_bin


def test_reshade_steam_bash_syntax():
    bash_bin = _bash()
    if not bash_bin:
        pytest.skip("bash not installed")
    res = subprocess.run([bash_bin, "-n", str(RESHADE_STEAM)], capture_output=True, text=True)
    assert res.returncode == 0, res.stderr


def test_reshade_steam_cleans_conflicting_dlls_and_copies_d3dcompiler(tmp_path):
    bash_bin = _bash()
    if not bash_bin:
        pytest.skip("bash not installed")

    home_dir = tmp_path / "home"
    bin_dir = home_dir / ".local" / "share" / "reshade" / "reshade" / "latest"
    presets_dir = home_dir / ".local" / "share" / "reshade" / "presets"
    bin_dir.mkdir(parents=True)
    presets_dir.mkdir(parents=True)

    (bin_dir / "ReShade64.dll").write_bytes(b"FAKE_RESHADE_64_BINARY")
    (bin_dir / "ReShade32.dll").write_bytes(b"FAKE_RESHADE_32_BINARY")
    (bin_dir / "d3dcompiler_47.dll").write_bytes(b"FAKE_D3DCOMPILER_47")
    (presets_dir / "Normal.ini").write_text("[CAS.fx]\n", encoding="utf-8")

    game_dir = tmp_path / "game"
    game_dir.mkdir()
    (game_dir / "d3d12.dll").write_bytes(b"FAKE_RESHADE_64_BINARY")
    (game_dir / "d3d11.dll").write_bytes(b"FAKE_RESHADE_64_BINARY")

    env = dict(os.environ)
    env["HOME"] = str(home_dir).replace("\\", "/")
    env["XDG_DATA_HOME"] = str(home_dir / ".local" / "share").replace("\\", "/")

    game_posix = str(game_dir).replace("\\", "/")
    script_posix = str(RESHADE_STEAM).replace("\\", "/")

    res = subprocess.run(
        [bash_bin, script_posix, "install", game_posix, "dxgi"],
        env=env,
        capture_output=True,
        text=True,
    )
    assert res.returncode == 0, res.stderr + res.stdout
    assert (game_dir / "dxgi.dll").read_bytes() == b"FAKE_RESHADE_64_BINARY"
    assert (game_dir / "d3dcompiler_47.dll").read_bytes() == b"FAKE_D3DCOMPILER_47"
    assert not (game_dir / "d3d12.dll").exists()
    assert not (game_dir / "d3d11.dll").exists()

    status_res = subprocess.run(
        [bash_bin, script_posix, "status", game_posix],
        env=env,
        capture_output=True,
        text=True,
    )
    assert status_res.returncode == 0
    assert "[+] hook DLL: dxgi.dll" in status_res.stdout
    assert "collision" not in status_res.stdout


def test_apply_and_remove_wine_override_missing_section(tmp_path):
    bash_bin = _bash()
    if not bash_bin:
        pytest.skip("bash not installed")

    pfx_dir = tmp_path / "pfx"
    pfx_dir.mkdir()
    user_reg = pfx_dir / "user.reg"
    user_reg.write_text('WINE REGISTRY Version 2\n\n[Software\\\\Wine\\\\Direct3D]\n"MaxVersionGL"=dword:00030002\n', encoding="utf-8")

    home_dir = tmp_path / "home"
    home_dir.mkdir()
    env = dict(os.environ)
    env["HOME"] = str(home_dir).replace("\\", "/")
    env["PATH"] = str(Path(sys.executable).parent) + os.pathsep + env.get("PATH", "")

    pfx_posix = str(pfx_dir).replace("\\", "/")
    script_posix = str(RESHADE_STEAM).replace("\\", "/")
    cmd = f'source <(sed "/^main \\"\\$@\\"$/d" "{script_posix}"); apply_wine_override "{pfx_posix}" dxgi'
    res = subprocess.run([bash_bin, "-c", cmd], env=env, capture_output=True, text=True)
    assert res.returncode == 0, res.stderr
    content = user_reg.read_text(encoding="utf-8")
    assert "[Software\\\\Wine\\\\DllOverrides]" in content
    assert '"dxgi"="native,builtin"' in content
    assert '"d3dcompiler_47"="native,builtin"' in content

    rm_cmd = f'source <(sed "/^main \\"\\$@\\"$/d" "{script_posix}"); remove_wine_override "{pfx_posix}" dxgi'
    rm_res = subprocess.run([bash_bin, "-c", rm_cmd], env=env, capture_output=True, text=True)
    assert rm_res.returncode == 0, rm_res.stderr
    after = user_reg.read_text(encoding="utf-8")
    assert '"dxgi"=' not in after
    assert '"d3dcompiler_47"=' not in after
