import asyncio
import json
import os
import re
import socket
import ssl
import struct
import time
import urllib.request

from bypass import sysutil

FALLBACK_CATALOG = {
    "comss": {
        "name": "Comss.one Primary (AI & Geo-Bypass)",
        "mode": "doh",
        "upstreams": ["https://dns.comss.one/dns-query"],
        "bootstrap": ["93.115.24.204", "93.115.24.205"],
        "dot": ["tcp-tls:93.115.24.204:853", "tcp-tls:93.115.24.205:853"],
        "routing": "SmartDNS Proxy",
    },
    "dns-ai": {
        "name": "DNS-AI.ru (Gemini / Claude / ChatGPT)",
        "mode": "doh",
        "upstreams": ["https://dns.dns-ai.ru/dns-query"],
        "bootstrap": ["194.87.196.13", "45.151.102.219"],
        "dot": ["tcp-tls:194.87.196.13:853", "tcp-tls:45.151.102.219:853"],
        "routing": "AI SNI Proxy",
    },
    "cloudflare": {
        "name": "Cloudflare 1.1.1.1 (Privacy Strict DoH)",
        "mode": "doh",
        "upstreams": ["https://cloudflare-dns.com/dns-query"],
        "bootstrap": ["1.1.1.1", "1.0.0.1"],
        "dot": ["tcp-tls:1.1.1.1:853", "tcp-tls:1.0.0.1:853"],
        "routing": "Direct Fast DoH",
    },
    "isp": {
        "name": "Direct ISP (Bypass Blocky / Plaintext DHCP)",
        "mode": "isp",
        "upstreams": [],
        "bootstrap": [],
        "dot": [],
        "routing": "Direct ISP",
    },
}


def load_dns_catalog():
    if sysutil.CATALOG_PATH.is_file():
        try:
            return json.loads(sysutil.CATALOG_PATH.read_text(encoding="utf-8"))
        except Exception:
            pass
    local_catalog = sysutil.CONFIG_DIR / "dns-catalog.json"
    if local_catalog.is_file():
        try:
            return json.loads(local_catalog.read_text(encoding="utf-8"))
        except Exception:
            pass
    return dict(FALLBACK_CATALOG)


def render_blocky_yml(provider_key, entry, profile_id=None):
    upstreams = list(entry.get("upstreams", []))
    if provider_key == "nextdns" and profile_id:
        pid = re.sub(r"[^A-Za-z0-9_-]", "", profile_id.strip())
        if pid:
            upstreams = [f"https://dns.nextdns.io/{pid}"]

    bootstrap = entry.get("bootstrap", []) or ["1.1.1.1", "9.9.9.9"]
    lines = [
        f"# bypass-managed: {provider_key}",
        "upstreams:",
        "  groups:",
        "    default:",
    ]
    for u in upstreams:
        lines.append(f'      - "{u}"')
    lines.extend(["  strategy: strict", "  timeout: 5s", "", "bootstrapDns:"])
    for ip in bootstrap:
        lines.append(f'  - upstream: "{ip}"')
    lines.extend(
        [
            "",
            "ports:",
            "  dns:",
            "    - 127.0.0.1:53",
            '    - "[::1]:53"',
            "",
            "caching:",
            "  minTime: 5m",
            "  maxTime: 30m",
            "  prefetching: true",
            "",
        ]
    )
    return "\n".join(lines)


def get_active_dns_provider():
    if sysutil.SYS_RESOLVED_CONF.is_file():
        content = sysutil.SYS_RESOLVED_CONF.read_text(encoding="utf-8", errors="ignore")
        if "DNS=127.0.0.1" not in content and "DNSOverTLS=no" in content:
            return "isp"
    if sysutil.SYS_BLOCKY_CONF.is_file():
        first_line = sysutil.SYS_BLOCKY_CONF.read_text(encoding="utf-8", errors="ignore").splitlines()[0:1]
        if first_line and first_line[0].startswith("# bypass-managed:"):
            return first_line[0].split(":", 1)[1].strip()
        return "custom (blocky)"
    return "system-default"


def build_dns_query(domain, qtype=1):
    tx_id = os.urandom(2)
    header = tx_id + struct.pack(">HHHHH", 0x0100, 1, 0, 0, 0)
    labels = b"".join(bytes([len(part)]) + part.encode("ascii") for part in domain.strip(".").split(".") if part)
    question = labels + b"\x00" + struct.pack(">HH", qtype, 1)
    return tx_id, header + question


def _skip_dns_name(packet, offset):
    while offset < len(packet):
        length = packet[offset]
        if length == 0:
            return offset + 1
        if (length & 0xC0) == 0xC0:
            return offset + 2
        offset += 1 + length
    return offset


def parse_dns_response(packet, expected_tx_id=None):
    if len(packet) < 12:
        return False, []
    _, flags, qdcount, ancount, _, _ = struct.unpack(">HHHHHH", packet[:12])
    if expected_tx_id is not None and packet[:2] != expected_tx_id:
        return False, []
    if (flags & 0x0F) != 0 or ancount == 0:
        return False, []

    offset = 12
    for _ in range(qdcount):
        offset = _skip_dns_name(packet, offset) + 4

    ips = []
    for _ in range(ancount):
        if offset >= len(packet):
            break
        offset = _skip_dns_name(packet, offset)
        if offset + 10 > len(packet):
            break
        rtype, _, _, rdlength = struct.unpack(">HHIH", packet[offset : offset + 10])
        offset += 10
        rdata = packet[offset : offset + rdlength]
        offset += rdlength
        if rtype == 1 and len(rdata) == 4:
            ips.append(socket.inet_ntop(socket.AF_INET, rdata))
        elif rtype == 28 and len(rdata) == 16:
            ips.append(socket.inet_ntop(socket.AF_INET6, rdata))
    return len(ips) > 0, ips


def probe_dns_doh(url, domain="gemini.google.com", timeout=2.5):
    tx_id, wire = build_dns_query(domain)
    ctx = ssl.create_default_context()
    req = urllib.request.Request(
        url,
        data=wire,
        method="POST",
        headers={
            "Content-Type": "application/dns-message",
            "Accept": "application/dns-message",
            "User-Agent": "bypass/2.0",
        },
    )
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
            body = resp.read()
        ms = (time.perf_counter() - t0) * 1000
        ok, ips = parse_dns_response(body, tx_id)
        return ok, ms, ips
    except Exception:
        return False, (time.perf_counter() - t0) * 1000, []


def probe_dns_dot(dot_spec, domain="gemini.google.com", timeout=2.5):
    spec = dot_spec.replace("tcp-tls:", "")
    host, _, port_str = spec.rpartition(":")
    port = int(port_str) if port_str.isdigit() else 853
    tx_id, wire = build_dns_query(domain)
    payload = struct.pack(">H", len(wire)) + wire
    ctx = ssl.create_default_context()
    t0 = time.perf_counter()
    try:
        with socket.create_connection((host, port), timeout=timeout) as sock:
            with ctx.wrap_socket(sock, server_hostname=host) as ssock:
                ssock.sendall(payload)
                raw_len = ssock.recv(2)
                if len(raw_len) < 2:
                    return False, (time.perf_counter() - t0) * 1000, []
                resp_len = struct.unpack(">H", raw_len)[0]
                buf = b""
                while len(buf) < resp_len:
                    chunk = ssock.recv(resp_len - len(buf))
                    if not chunk:
                        break
                    buf += chunk
        ms = (time.perf_counter() - t0) * 1000
        ok, ips = parse_dns_response(buf, tx_id)
        return ok, ms, ips
    except Exception:
        return False, (time.perf_counter() - t0) * 1000, []


def cmd_dns(args):
    action = args.dns_action
    provider = args.provider
    catalog = load_dns_catalog()

    if action == "list":
        active = get_active_dns_provider()
        print(f"\n{sysutil.C_BOLD}:: Available DNS Presets (Blocky DoH/DoT){sysutil.C_RESET}")
        for key, entry in catalog.items():
            mark = f" {sysutil.C_GREEN}[active]{sysutil.C_RESET}" if key == active else ""
            proto = entry.get("mode", "doh").upper()
            print(f"  - {sysutil.C_BOLD}{key:<14}{sysutil.C_RESET} [{proto}] {entry['name']}{mark}")
        print()
        return 0

    if action == "status":
        print(f"Active DNS Provider: {get_active_dns_provider()}")
        print(f"Blocky Service: {'active' if sysutil.is_service_active(sysutil.BLOCKY_SERVICE) else 'inactive'}")
        if sysutil.SYS_BLOCKY_CONF.is_file():
            print(f"\n{sysutil.C_DIM}--- {sysutil.SYS_BLOCKY_CONF} ---{sysutil.C_RESET}")
            print(sysutil.SYS_BLOCKY_CONF.read_text(encoding="utf-8", errors="ignore").strip())
        return 0

    if action in ("monitor", "test"):
        print(f"\n{sysutil.C_BOLD}{sysutil.C_CYAN}:: Live Encrypted DNS Benchmark (Real DoH/DoT Wire Probes){sysutil.C_RESET}\n")
        print(f"  {sysutil.C_BOLD}{'Provider':<14} {'Protocol':<6} {'Status':<18} {'Resolved IP':<18} {'Routing'}{sysutil.C_RESET}")
        print(f"  {'-' * 78}")

        async def probe_provider(key, entry):
            if entry.get("mode", "doh") == "isp":
                return None
            upstreams = entry.get("upstreams", [])
            dot_list = entry.get("dot", [])
            ok, ms, ips = False, 0.0, []
            proto = "DoH"
            if upstreams:
                ok, ms, ips = await asyncio.to_thread(probe_dns_doh, upstreams[0])
            if not ok and dot_list:
                proto = "DoT"
                ok, ms, ips = await asyncio.to_thread(probe_dns_dot, dot_list[0])
            return {"key": key, "proto": proto, "ok": ok, "ms": ms, "ip": ips[0] if ips else "-", "routing": entry.get("routing", "")}

        async def run_all():
            return await asyncio.gather(*[probe_provider(k, v) for k, v in catalog.items() if v.get("mode") != "isp"])

        for r in asyncio.run(run_all()):
            if not r:
                continue
            color = sysutil.C_GREEN if r["ok"] else sysutil.C_RED
            status_str = f"[+] {r['ms']:.0f} ms" if r["ok"] else "[-] offline"
            print(f"  {r['key']:<14} {r['proto']:<6} {color}{status_str:<18}{sysutil.C_RESET} {r['ip']:<18} {sysutil.C_DIM}{r['routing']}{sysutil.C_RESET}")
        print(f"  {'-' * 78}\n")
        return 0

    if action == "set":
        if not provider or provider not in catalog:
            print(f"{sysutil.C_RED}error: invalid provider '{provider}'.{sysutil.C_RESET} Run 'bypass dns list'.")
            return 1
        entry = catalog[provider]
        if entry.get("mode") == "isp":
            print(":: disabling Blocky and restoring direct ISP DNS...")
            sysutil.run_cmd(["systemctl", "stop", sysutil.BLOCKY_SERVICE])
            ok, _, err = sysutil.write_root_content("[Resolve]\nDNSOverTLS=no\n", sysutil.SYS_RESOLVED_CONF, mode="644")
            if not ok:
                print(f"{sysutil.C_RED}failed to update resolved config:{sysutil.C_RESET} {err}")
                return 1
            sysutil.run_cmd(["systemctl", "restart", "systemd-resolved.service"])
            print(f"{sysutil.C_GREEN}[+] DNS set to direct ISP.{sysutil.C_RESET}")
            return 0

        blocky_yml = render_blocky_yml(provider, entry, profile_id=getattr(args, "profile_id", None))
        print(f":: configuring Blocky DNS -> {entry['name']}...")
        ok, _, err = sysutil.write_root_content(blocky_yml, sysutil.SYS_BLOCKY_CONF, mode="644")
        if not ok:
            print(f"{sysutil.C_RED}failed to deploy {sysutil.SYS_BLOCKY_CONF}:{sysutil.C_RESET} {err}")
            return 1
        ok_res, _, err_res = sysutil.write_root_content(
            "[Resolve]\nDNS=127.0.0.1\nDomains=~.\nDNSOverTLS=no\n", sysutil.SYS_RESOLVED_CONF, mode="644"
        )
        if not ok_res:
            print(f"{sysutil.C_RED}failed to update {sysutil.SYS_RESOLVED_CONF}:{sysutil.C_RESET} {err_res}")
            return 1
        ok_blk, _, err_blk = sysutil.run_cmd(["systemctl", "restart", sysutil.BLOCKY_SERVICE])
        if not ok_blk:
            print(f"{sysutil.C_RED}failed to restart {sysutil.BLOCKY_SERVICE}:{sysutil.C_RESET} {err_blk}")
            return 1
        sysutil.run_cmd(["systemctl", "restart", "systemd-resolved.service"])
        print(f"{sysutil.C_GREEN}[+] Blocky DNS set to {provider}.{sysutil.C_RESET}")
        return 0
    return 1
