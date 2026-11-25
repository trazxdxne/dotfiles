import importlib.machinery
import importlib.util
import json
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
REPOSYNC_PATH = REPO_ROOT / "modules" / "antigravity" / "user" / ".local" / "bin" / "reposync"


def load_reposync():
    loader = importlib.machinery.SourceFileLoader("reposync_mod", str(REPOSYNC_PATH))
    spec = importlib.util.spec_from_loader("reposync_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def _git(cwd, *args):
    res = subprocess.run(["git", "-C", str(cwd), *args], capture_output=True, text=True)
    assert res.returncode == 0, res.stderr + res.stdout
    return res.stdout.strip()


def test_discover_repos_dedup_and_inspect_sync_states(tmp_path, monkeypatch):
    mod = load_reposync()
    fake_home = tmp_path / "home"
    projects = fake_home / "Projects"
    projects.mkdir(parents=True)

    remote = tmp_path / "remote.git"
    subprocess.run(["git", "init", "--bare", str(remote)], check=True, capture_output=True)

    win_clone = projects / "demo"
    subprocess.run(["git", "clone", str(remote), str(win_clone)], check=True, capture_output=True)
    _git(win_clone, "config", "user.email", "t@example.com")
    _git(win_clone, "config", "user.name", "Tester")
    (win_clone / "a.txt").write_text("init\n", encoding="utf-8")
    _git(win_clone, "add", "a.txt")
    _git(win_clone, "commit", "-m", "init")
    _git(win_clone, "push", "-u", "origin", "HEAD")

    linux_clone = tmp_path / "linux_clone"
    subprocess.run(["git", "clone", str(remote), str(linux_clone)], check=True, capture_output=True)
    _git(linux_clone, "config", "user.email", "t@example.com")
    _git(linux_clone, "config", "user.name", "Tester")
    (linux_clone / "b.txt").write_text("from cachyos\n", encoding="utf-8")
    _git(linux_clone, "add", "b.txt")
    _git(linux_clone, "commit", "-m", "cachyos commit")
    _git(linux_clone, "push")

    monkeypatch.setattr(Path, "home", staticmethod(lambda: fake_home))
    found = mod.discover_repos(extra_roots=[win_clone])
    assert found == [win_clone.resolve()]

    info_behind = mod.inspect_repo(win_clone, fetch=True)
    assert info_behind["behind"] == 1
    assert info_behind["ahead"] == 0
    assert "behind:1" in info_behind["state"]

    assert mod.cmd_pull([win_clone]) == 0
    assert (win_clone / "b.txt").is_file()

    (win_clone / "c.txt").write_text("from win\n", encoding="utf-8")
    _git(win_clone, "add", "c.txt")
    _git(win_clone, "commit", "-m", "win commit")

    assert mod.cmd_status([win_clone]) == 1
    assert mod.cmd_push([win_clone]) == 0
    assert mod.cmd_status([win_clone]) == 0


def test_antigravity_cross_os_files_valid():
    ecc_mcp = json.loads(
        (REPO_ROOT / "modules" / "antigravity" / "user" / ".gemini" / "config" / "plugins" / "ecc" / "mcp_config.json").read_text(
            encoding="utf-8"
        )
    )
    args = ecc_mcp["mcpServers"]["ecc-memory"]["args"]
    assert not any("/c/Users/" in a for a in args)
    assert (REPO_ROOT / ".gitattributes").is_file()
    assert (REPO_ROOT / "modules" / "antigravity" / "install-windows.ps1").is_file()
    assert (REPO_ROOT / "modules" / "antigravity" / "user" / ".gemini" / "config" / "plugins" / "ecc" / "rules" / "common-cross-os-sync.md").is_file()
