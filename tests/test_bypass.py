import argparse
import socket
import struct
import subprocess
import sys
from pathlib import Path
from unittest.mock import MagicMock

import pytest

REPO_ROOT = Path(__file__).resolve().parent.parent
LIB_DIR = REPO_ROOT / "modules" / "network" / "user" / ".local" / "lib"
BIN_PATH = REPO_ROOT / "modules" / "network" / "user" / ".local" / "bin" / "bypass"

if str(LIB_DIR) not in sys.path:
    sys.path.insert(0, str(LIB_DIR))

from bypass import cli, dns, menu, probes, sysutil, vpn, zapret


@pytest.fixture(autouse=True)
def isolated_paths(tmp_path, monkeypatch):
    monkeypatch.setattr(sysutil, "CONFIG_DIR", tmp_path / "config_bypass")
    monkeypatch.setattr(sysutil, "VPN_DIR", tmp_path / "config_bypass" / "vpn")
    monkeypatch.setattr(sysutil, "SYS_VPN_DIR", tmp_path / "etc_awg")
    monkeypatch.setattr(sysutil, "SYS_RESOLVED_CONF", tmp_path / "resolved_bypass.conf")
    monkeypatch.setattr(sysutil, "SYS_BLOCKY_CONF", tmp_path / "blocky.yml")
    monkeypatch.setattr(sysutil, "ZAPRET_CACHE_DIR", tmp_path / "zapret_cache")
    monkeypatch.setattr(sysutil, "ZAPRET_CONF_FILE", tmp_path / "zapret_cache" / "conf.env")
    monkeypatch.setattr(sysutil, "CATALOG_PATH", REPO_ROOT / "system" / "network" / "dns" / "catalog.json")


def _make_dns_a_response(tx_id, domain, ip_str, rcode=0):
    flags = 0x8180 | (rcode & 0x0F)
    header = tx_id + struct.pack(">HHHHH", flags, 1, 1 if rcode == 0 else 0, 0, 0)
    labels = b"".join(bytes([len(p)]) + p.encode("ascii") for p in domain.split(".")) + b"\x00"
    question = labels + struct.pack(">HH", 1, 1)
    if rcode != 0:
        return header + question
    answer = b"\xc0\x0c" + struct.pack(">HHIH", 1, 1, 60, 4) + socket.inet_aton(ip_str)
    return header + question + answer


def test_entrypoint_help():
    res = subprocess.run([sys.executable, str(BIN_PATH), "--help"], capture_output=True, text=True)
    assert res.returncode == 0
    assert "Unified Network Bypass Controller" in res.stdout


def test_load_dns_catalog_schema():
    catalog = dns.load_dns_catalog()
    assert "comss" in catalog
    assert "dns-ai" in catalog
    assert "isp" in catalog
    for key, entry in catalog.items():
        assert entry["name"]
        assert entry["mode"] in ("doh", "dot", "isp")
        if entry["mode"] != "isp":
            assert entry["upstreams"], f"{key} missing upstreams"
            assert entry["bootstrap"], f"{key} missing bootstrap"


def test_render_blocky_yml_standard_and_nextdns():
    catalog = dns.load_dns_catalog()
    yml = dns.render_blocky_yml("comss", catalog["comss"])
    assert "# bypass-managed: comss" in yml
    assert "https://dns.comss.one/dns-query" in yml
    assert "127.0.0.1:53" in yml
    assert 'upstream: "93.115.24.204"' in yml

    next_yml = dns.render_blocky_yml("nextdns", catalog["nextdns"], profile_id="ab12cd;rm")
    assert "https://dns.nextdns.io/ab12cdrm" in next_yml


def test_dns_set_blocky_and_isp(monkeypatch):
    writes = []
    cmds = []
    monkeypatch.setattr(sysutil, "write_root_content", lambda c, d, mode="644": writes.append((str(d), c, mode)) or (True, "", ""))
    monkeypatch.setattr(sysutil, "run_cmd", lambda cmd, **kw: cmds.append(cmd) or (True, "", ""))

    assert dns.cmd_dns(argparse.Namespace(dns_action="set", provider="dns-ai", profile_id=None)) == 0
    assert any("blocky.yml" in w[0] and "dns.dns-ai.ru" in w[1] for w in writes)
    assert any("resolved_bypass.conf" in w[0] and "DNS=127.0.0.1" in w[1] for w in writes)
    assert ["systemctl", "restart", "blocky.service"] in cmds
    assert ["systemctl", "restart", "systemd-resolved.service"] in cmds

    writes.clear()
    cmds.clear()
    assert dns.cmd_dns(argparse.Namespace(dns_action="set", provider="isp", profile_id=None)) == 0
    assert ["systemctl", "stop", "blocky.service"] in cmds
    assert any("DNSOverTLS=no" in w[1] and "127.0.0.1" not in w[1] for w in writes)


def test_dns_wire_query_and_response_parser():
    tx_id, packet = dns.build_dns_query("gemini.google.com")
    assert len(tx_id) == 2
    assert b"gemini" in packet

    resp = _make_dns_a_response(tx_id, "gemini.google.com", "142.250.74.46")
    assert dns.parse_dns_response(resp, expected_tx_id=tx_id) == (True, ["142.250.74.46"])
    assert dns.parse_dns_response(resp, expected_tx_id=b"\x00\x00") == (False, [])

    nxdomain = _make_dns_a_response(tx_id, "gemini.google.com", "0.0.0.0", rcode=3)
    assert dns.parse_dns_response(nxdomain, expected_tx_id=tx_id) == (False, [])
    assert dns.parse_dns_response(b"short") == (False, [])


def test_dns_monitor_uses_doh_and_dot_fallback(monkeypatch, capsys):
    monkeypatch.setattr(
        dns,
        "load_dns_catalog",
        lambda: {
            "doh_ok": {
                "name": "DoH OK",
                "mode": "doh",
                "upstreams": ["https://ok.example/dns-query"],
                "bootstrap": ["1.1.1.1"],
                "dot": [],
                "routing": "Direct",
            },
            "dot_fb": {
                "name": "DoT Fallback",
                "mode": "doh",
                "upstreams": ["https://fail.example/dns-query"],
                "bootstrap": ["9.9.9.9"],
                "dot": ["tcp-tls:9.9.9.9:853"],
                "routing": "Fallback",
            },
            "isp": {"name": "ISP", "mode": "isp", "upstreams": [], "bootstrap": [], "dot": []},
        },
    )
    monkeypatch.setattr(
        dns,
        "probe_dns_doh",
        lambda url: (True, 12.0, ["1.2.3.4"]) if "ok.example" in url else (False, 50.0, []),
    )
    monkeypatch.setattr(dns, "probe_dns_dot", lambda spec: (True, 25.0, ["5.6.7.8"]))

    assert dns.cmd_dns(argparse.Namespace(dns_action="monitor", provider=None, profile_id=None)) == 0
    out = capsys.readouterr().out
    assert "doh_ok" in out and "1.2.3.4" in out
    assert "dot_fb" in out and "DoT" in out and "5.6.7.8" in out
    assert "isp" not in out


def test_validate_and_import_vpn_profile(tmp_path, monkeypatch):
    bad_file = tmp_path / "bad.conf"
    bad_file.write_text("[Interface]\nAddress = 10.0.0.2/32\n", encoding="utf-8")
    ok, msg = vpn.validate_wireguard_conf(bad_file)
    assert ok is False
    assert "Peer" in msg

    good_file = tmp_path / "my warp!.conf"
    good_file.write_text("[Interface]\nPrivateKey = abc=\n[Peer]\nPublicKey = xyz=\n", encoding="utf-8")

    installed = []
    monkeypatch.setattr(sysutil, "install_root_file", lambda s, d, mode="644": installed.append((Path(s), Path(d), mode)) or (True, "", ""))

    ok, name = vpn.import_vpn_profile(good_file)
    assert ok is True
    assert name == "my_warp"
    assert (sysutil.VPN_DIR / "my_warp.conf").is_file()
    assert installed and installed[0][1] == sysutil.SYS_VPN_DIR / "my_warp.conf"
    assert installed[0][2] == "600"


def test_pick_conf_file_gui_and_fallback(tmp_path, monkeypatch):
    monkeypatch.setenv("WAYLAND_DISPLAY", "wayland-0")
    monkeypatch.setattr(sysutil, "cmd_exists", lambda n: n == "zenity")
    monkeypatch.setattr(sysutil, "run_cmd", lambda cmd, **kw: (True, "/tmp/chosen.conf", ""))
    assert vpn.pick_conf_file() == "/tmp/chosen.conf"

    monkeypatch.delenv("WAYLAND_DISPLAY", raising=False)
    monkeypatch.delenv("DISPLAY", raising=False)
    dl = tmp_path / "Downloads"
    dl.mkdir()
    conf = dl / "warp.conf"
    conf.write_text("[Interface]\n", encoding="utf-8")
    monkeypatch.setattr(Path, "home", staticmethod(lambda: tmp_path))
    monkeypatch.setattr(sysutil, "cmd_exists", lambda n: n == "fzf")
    monkeypatch.setattr(sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr(vpn, "run_fzf", lambda items, **kw: items[0])
    assert vpn.pick_conf_file() == str(conf)


def test_vpn_awg_and_warp_mutual_exclusion(monkeypatch):
    sysutil.VPN_DIR.mkdir(parents=True)
    (sysutil.VPN_DIR / "prof1.conf").write_text("[Interface]\nPrivateKey=a\n[Peer]\n", encoding="utf-8")
    sysutil.SYS_VPN_DIR.mkdir(parents=True)
    (sysutil.SYS_VPN_DIR / "prof1.conf").write_text("[Interface]\nPrivateKey=a\n[Peer]\n", encoding="utf-8")

    cmds = []
    monkeypatch.setattr(sysutil, "cmd_exists", lambda n: n == "warp-cli")
    monkeypatch.setattr(vpn, "get_warp_status", lambda: ("connected", "Connected"))
    monkeypatch.setattr(vpn, "get_active_vpn_service", lambda: "old_awg")
    monkeypatch.setattr(sysutil, "run_cmd", lambda cmd, **kw: cmds.append(cmd) or (True, "", ""))

    assert vpn.cmd_vpn(argparse.Namespace(vpn_action="on", target="prof1")) == 0
    assert ["warp-cli", "disconnect"] in cmds
    assert ["systemctl", "stop", "awg-quick@old_awg.service"] in cmds
    assert ["systemctl", "start", "awg-quick@prof1.service"] in cmds

    cmds.clear()
    monkeypatch.setattr(vpn, "get_active_vpn_service", lambda: "prof1")
    monkeypatch.setattr(sysutil, "is_service_active", lambda s: s == "warp-svc.service")
    monkeypatch.setattr(vpn, "get_warp_status", lambda: ("unregistered", "Registration Missing"))

    assert vpn.cmd_vpn(argparse.Namespace(vpn_action="warp", target="on")) == 0
    assert ["systemctl", "stop", "awg-quick@prof1.service"] in cmds
    assert ["warp-cli", "registration", "new"] in cmds
    assert ["warp-cli", "connect"] in cmds


def test_vpn_warp_install_via_yay(monkeypatch):
    cmds = []
    monkeypatch.setattr(sysutil, "cmd_exists", lambda n: n == "yay")
    monkeypatch.setattr(sysutil, "run_cmd", lambda cmd, **kw: cmds.append(cmd) or (True, "", ""))
    assert vpn.cmd_vpn_warp("install") == 0
    assert ["yay", "-S", "--needed", "--noconfirm", "cloudflare-warp-bin"] in cmds
    assert ["systemctl", "enable", "--now", "warp-svc.service"] in cmds


def test_zapret_rust_management(monkeypatch):
    repo_dir = sysutil.ZAPRET_CACHE_DIR / "zapret-discord-youtube-linux"
    repo_dir.mkdir(parents=True)
    (repo_dir / "general.bat").write_text("mock", encoding="utf-8")
    (repo_dir / "discord.bat").write_text("mock", encoding="utf-8")

    assert zapret.get_available_zapret_strategies() == ["discord.bat", "general.bat"]

    written = []
    cmds = []

    def fake_write(content, dest, mode="644"):
        Path(dest).parent.mkdir(parents=True, exist_ok=True)
        Path(dest).write_text(content, encoding="utf-8")
        written.append(content)
        return True, "", ""

    monkeypatch.setattr(sysutil, "write_root_content", fake_write)
    monkeypatch.setattr(sysutil, "run_cmd", lambda cmd, **kw: cmds.append(cmd) or (True, "", ""))

    assert zapret.cmd_zapret(argparse.Namespace(zapret_action="strategy", target="discord.bat")) == 0
    assert "strategy=discord.bat" in written[0]
    assert ["systemctl", "restart", "zapret-rust.service"] in cmds


def test_evaluate_http_probe_strict_security():
    assert probes.evaluate_http_probe(200, "<html>Welcome</html>") == ("PASS", True)
    assert probes.evaluate_http_probe(403, "Forbidden") == ("BLOCKED (403)", False)
    assert probes.evaluate_http_probe(401, "Unauthorized", allow_auth_401=False) == ("HTTP 401", False)
    assert probes.evaluate_http_probe(401, "Invalid API key", allow_auth_401=True) == ("PASS (401)", True)
    assert probes.evaluate_http_probe(200, "Gemini isn't currently supported in your region") == ("GEO_BLOCKED", False)
    assert probes.evaluate_http_probe(403, '{"error":{"code":"unsupported_country"}}', allow_auth_401=True) == ("GEO_BLOCKED", False)
    assert probes.evaluate_http_probe(200, "", check_stream=True, stream_bytes=512) == ("PASS", True)
    assert probes.evaluate_http_probe(403, "", check_stream=True, stream_bytes=0) == ("HTTP 403", False)


def test_verify_game_bypass_routing_priority(monkeypatch):
    monkeypatch.setattr(sysutil, "is_service_active", lambda s: s == "game-bypass-routing.service")
    monkeypatch.setattr(sysutil, "cmd_exists", lambda n: n == "game-bypass")
    monkeypatch.setattr(vpn, "get_active_vpn_service", lambda: "WARPw_93")
    monkeypatch.setattr(vpn, "get_warp_status", lambda: ("disconnected", ""))

    def fake_run_bad(cmd, **kw):
        if cmd == ["ip", "rule", "show"]:
            return True, "0:\tfrom all lookup local\n90:\tfrom all fwmark 0x51 lookup main\n", ""
        return True, "1.2.3.4", ""

    monkeypatch.setattr(sysutil, "run_cmd", fake_run_bad)
    ok, msg = probes.verify_game_bypass_routing()
    assert ok is False
    assert "priority (90)" in msg

    def fake_run_good(cmd, **kw):
        if cmd == ["ip", "rule", "show"]:
            return True, "0:\tfrom all lookup local\n10:\tfrom all fwmark 0x51 lookup main\n", ""
        if isinstance(cmd, str) and cmd.startswith("game-bypass"):
            return True, "95.10.20.30", ""
        return True, "104.28.1.1", ""

    monkeypatch.setattr(sysutil, "run_cmd", fake_run_good)
    ok, msg = probes.verify_game_bypass_routing()
    assert ok is True
    assert "95.10.20.30" in msg


def test_menu_fzf_and_no_fuzzel(monkeypatch):
    for py_file in LIB_DIR.glob("bypass/*.py"):
        assert "fuzzel" not in py_file.read_text(encoding="utf-8").lower()

    monkeypatch.setattr(sysutil, "cmd_exists", lambda n: n == "fzf")
    monkeypatch.setattr(sys.stdin, "isatty", lambda: True)
    monkeypatch.setattr(vpn, "get_active_vpn_service", lambda: None)
    monkeypatch.setattr(vpn, "get_warp_status", lambda: ("disconnected", ""))
    monkeypatch.setattr(sysutil, "is_service_active", lambda s: False)
    monkeypatch.setattr(dns, "get_active_dns_provider", lambda: "comss")

    fake_proc = MagicMock(returncode=0, stdout="0. Exit\n")
    called = []
    monkeypatch.setattr(vpn.subprocess, "run", lambda *a, **kw: called.append(kw) or fake_proc)
    assert menu.cmd_menu(argparse.Namespace()) == 0
    assert called[0]["stderr"] is None


def test_status_and_cli_dispatch(monkeypatch, capsys):
    monkeypatch.setattr(vpn, "get_active_vpn_service", lambda: None)
    monkeypatch.setattr(vpn, "get_warp_status", lambda: ("connected", "Connected"))
    monkeypatch.setattr(sysutil, "is_service_active", lambda s: s in (sysutil.ZAPRET_SERVICE, sysutil.BLOCKY_SERVICE))
    monkeypatch.setattr(dns, "get_active_dns_provider", lambda: "comss")
    monkeypatch.setattr(probes, "get_public_ip_info", lambda: ("1.1.1.1", "NL"))
    sysutil.ZAPRET_CACHE_DIR.mkdir(parents=True)
    sysutil.ZAPRET_CONF_FILE.write_text("strategy=general.bat\ninterface=any\n", encoding="utf-8")

    assert cli.main(["status"]) == 0
    out = capsys.readouterr().out
    assert "Cloudflare WARP" in out
    assert "general.bat" in out
    assert "comss" in out
    assert "1.1.1.1 [NL]" in out


def test_vpn_list_remove_edit_off(monkeypatch, capsys):
    sysutil.VPN_DIR.mkdir(parents=True)
    prof = sysutil.VPN_DIR / "lab.conf"
    prof.write_text("[Interface]\nPrivateKey=k\n[Peer]\n", encoding="utf-8")

    monkeypatch.setattr(vpn, "get_active_vpn_service", lambda: "lab")
    monkeypatch.setattr(vpn, "get_warp_status", lambda: ("disconnected", ""))
    cmds = []
    monkeypatch.setattr(sysutil, "run_cmd", lambda cmd, **kw: cmds.append(cmd) or (True, "", ""))
    monkeypatch.setattr(sysutil, "remove_root_file", lambda p: (True, "", ""))

    assert vpn.cmd_vpn(argparse.Namespace(vpn_action="list", target=None)) == 0
    assert "lab" in capsys.readouterr().out

    assert vpn.cmd_vpn(argparse.Namespace(vpn_action="off", target=None)) == 0
    assert ["systemctl", "stop", "awg-quick@lab.service"] in cmds

    assert vpn.cmd_vpn(argparse.Namespace(vpn_action="remove", target="lab")) == 0
    assert not prof.exists()


def test_cmd_test_aggregation_and_failure_exit(monkeypatch, capsys):
    async def fake_checks(full=False):
        return [
            {"name": "Google Gemini", "category": "AI", "status": "PASS", "time_ms": 15.0, "success": True},
            {"name": "OpenAI API", "category": "AI", "status": "GEO_BLOCKED", "time_ms": 20.0, "success": False},
        ]

    monkeypatch.setattr(probes, "run_healthchecks", fake_checks)
    monkeypatch.setattr(probes, "verify_game_bypass_routing", lambda: (True, "default=1.1.1.1, game-bypass=2.2.2.2"))
    assert probes.cmd_test(argparse.Namespace(full=False, check_game_bypass=True)) == 1
    out = capsys.readouterr().out
    assert "1/2 accessible" in out
    assert "GEO_BLOCKED" in out
    assert "game-bypass=2.2.2.2" in out
