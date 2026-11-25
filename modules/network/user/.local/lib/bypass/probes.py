import asyncio
import json
import re
import ssl
import time
import urllib.error
import urllib.request

from bypass import dns, sysutil, vpn, zapret

GEO_BLOCK_PATTERNS = (
    "isn't available in your country",
    "not available in your country",
    "unsupported_country",
    "not available in your region",
    "service is not available in your country",
    "gemini isn't currently supported",
)


def get_public_ip_info():
    ctx = ssl.create_default_context()
    try:
        req = urllib.request.Request("https://1.1.1.1/cdn-cgi/trace", headers={"User-Agent": "bypass/2.0"})
        with urllib.request.urlopen(req, timeout=2.5, context=ctx) as resp:
            data = resp.read().decode("utf-8", errors="ignore")
            info = dict(line.split("=", 1) for line in data.splitlines() if "=" in line)
            return info.get("ip", "unknown"), info.get("loc", "unknown")
    except Exception:
        pass
    try:
        req = urllib.request.Request("https://api.ipify.org?format=json", headers={"User-Agent": "bypass/2.0"})
        with urllib.request.urlopen(req, timeout=2.5, context=ctx) as resp:
            data = json.loads(resp.read().decode("utf-8", errors="ignore"))
            return data.get("ip", "unknown"), "?"
    except Exception:
        return "unreachable", "?"


def evaluate_http_probe(code, body_text, allow_auth_401=False, check_stream=False, stream_bytes=0):
    lower = (body_text or "").lower()
    for pat in GEO_BLOCK_PATTERNS:
        if pat in lower:
            return "GEO_BLOCKED", False
    if check_stream:
        if 200 <= code < 400 and stream_bytes > 0:
            return "PASS", True
        return f"HTTP {code}", False
    if 200 <= code < 400:
        return "PASS", True
    if allow_auth_401 and code == 401:
        return "PASS (401)", True
    if code == 403:
        return "BLOCKED (403)", False
    return f"HTTP {code}", False


async def probe_endpoint(name, url, category, timeout=3.5, check_stream=False, allow_auth_401=False):
    start = time.perf_counter()
    ctx = ssl.create_default_context()

    def fetch():
        req = urllib.request.Request(
            url,
            headers={"User-Agent": "Mozilla/5.0 (X11; Linux x86_64) Chrome/131.0.0.0 Safari/537.36"},
        )
        try:
            with urllib.request.urlopen(req, timeout=timeout, context=ctx) as resp:
                chunk = resp.read(4096)
                return evaluate_http_probe(
                    resp.getcode(),
                    chunk.decode("utf-8", errors="ignore"),
                    allow_auth_401=allow_auth_401,
                    check_stream=check_stream,
                    stream_bytes=len(chunk),
                )
        except urllib.error.HTTPError as e:
            body = ""
            try:
                body = e.read(4096).decode("utf-8", errors="ignore")
            except Exception:
                pass
            return evaluate_http_probe(
                e.code, body, allow_auth_401=allow_auth_401, check_stream=check_stream, stream_bytes=0
            )

    try:
        status, ok = await asyncio.wait_for(asyncio.to_thread(fetch), timeout=timeout + 0.5)
        elapsed = (time.perf_counter() - start) * 1000
        return {"name": name, "category": category, "status": status, "time_ms": elapsed, "success": ok}
    except Exception as e:
        elapsed = (time.perf_counter() - start) * 1000
        err_str = str(e).lower()
        if isinstance(e, asyncio.TimeoutError) or "timed out" in err_str:
            err_msg = "TIMEOUT"
        elif isinstance(e, ssl.SSLError) or "certificate" in err_str or "ssl" in err_str:
            err_msg = "SSL_ERROR"
        elif "reset" in err_str:
            err_msg = "CONN_RESET"
        else:
            err_msg = type(e).__name__
        return {"name": name, "category": category, "status": err_msg, "time_ms": elapsed, "success": False}


def parse_ip_rule_priorities(ip_rule_output):
    rules = []
    for line in ip_rule_output.splitlines():
        m = re.match(r"^\s*(\d+):\s*(.+)$", line)
        if m:
            rules.append((int(m.group(1)), m.group(2).strip()))
    return rules


def verify_game_bypass_routing():
    if not sysutil.is_service_active(sysutil.GAME_BYPASS_SERVICE):
        return False, "game-bypass-routing.service is not active"
    ok_rule, rule_out, _ = sysutil.run_cmd(["ip", "rule", "show"])
    if ok_rule:
        rules = parse_ip_rule_priorities(rule_out)
        gb_prio = next((prio for prio, body in rules if "0x51" in body and "main" in body), None)
        if gb_prio is None:
            return False, "fwmark 0x51 policy rule missing"
        if gb_prio > 50:
            return False, f"fwmark 0x51 priority ({gb_prio}) is too low (expected <= 50)"
    if not sysutil.cmd_exists("game-bypass"):
        return False, "game-bypass wrapper missing"
    ok1, normal_ip, _ = sysutil.run_cmd("curl -s --connect-timeout 3 https://1.1.1.1/cdn-cgi/trace | sed -n 's/^ip=//p'")
    ok2, game_ip, _ = sysutil.run_cmd("game-bypass curl -s --connect-timeout 3 https://1.1.1.1/cdn-cgi/trace | sed -n 's/^ip=//p'")
    if not (ok1 and ok2 and normal_ip and game_ip):
        return False, "failed to probe default vs game-bypass public IP"
    vpn_active = bool(vpn.get_active_vpn_service()) or vpn.get_warp_status()[0] == "connected"
    if vpn_active and normal_ip == game_ip:
        return False, f"VPN active ({normal_ip}) but game-bypass routed through same IP"
    return True, f"default={normal_ip}, game-bypass={game_ip}"


async def run_healthchecks(full=False):
    targets = [
        ("Google Gemini", "https://gemini.google.com", "AI / Gemini", False, False),
        ("Google AI Studio", "https://aistudio.google.com", "AI / Gemini", False, False),
        ("Gemini API", "https://generativelanguage.googleapis.com", "AI / Gemini", False, False),
        ("OpenAI API", "https://api.openai.com/v1/models", "AI / ChatGPT", False, True),
        ("YouTube (Web)", "https://www.youtube.com", "Video / Google", False, False),
        ("Discord (API)", "https://discord.com/api/v10/gateway", "Discord", False, False),
        ("Discord (CDN)", "https://cdn.discordapp.com", "Discord", False, False),
        ("RuTracker", "https://rutracker.org", "Blocked Web", False, False),
        ("X / Twitter", "https://x.com", "Blocked Web", False, False),
        ("VKontakte", "https://vk.com", "Domestic", False, False),
        ("Yandex", "https://ya.ru", "Domestic", False, False),
    ]
    if full:
        targets.append(("YouTube (CDN)", "https://redirector.googlevideo.com", "Video / Stream", True, False))
    return await asyncio.gather(
        *[
            probe_endpoint(name, url, cat, check_stream=stream, allow_auth_401=auth_401)
            for name, url, cat, stream, auth_401 in targets
        ]
    )


def cmd_test(args):
    print(f"\n{sysutil.C_BOLD}{sysutil.C_CYAN}:: Running Strict Network Health Checks{sysutil.C_RESET}\n")
    results = asyncio.run(run_healthchecks(full=args.full))

    print(f"  {sysutil.C_BOLD}{'Service':<18} {'Category':<16} {'Status':<18} {'Latency'}{sysutil.C_RESET}")
    print(f"  {'-' * 64}")
    passed = 0
    for r in results:
        color = sysutil.C_GREEN if r["success"] else sysutil.C_RED
        mark = "+" if r["success"] else "-"
        print(f"  {r['name']:<18} {sysutil.C_DIM}{r['category']:<16}{sysutil.C_RESET} {color}[{mark}] {r['status']:<14}{sysutil.C_RESET} {r['time_ms']:.0f} ms")
        if r["success"]:
            passed += 1

    print(f"  {'-' * 64}")
    total = len(results)
    summary_color = sysutil.C_GREEN if passed == total else (sysutil.C_YELLOW if passed > 0 else sysutil.C_RED)
    print(f"  Result: {summary_color}{passed}/{total} accessible{sysutil.C_RESET}\n")

    if getattr(args, "check_game_bypass", False):
        ok, msg = verify_game_bypass_routing()
        color = sysutil.C_GREEN if ok else sysutil.C_YELLOW
        tag = "[+]" if ok else "[!]"
        print(f"  {sysutil.C_BOLD}Game Split-Tunneling:{sysutil.C_RESET} {color}{tag} {msg}{sysutil.C_RESET}\n")
    return 0 if passed == total else 1


def cmd_status(_args):
    print(f"\n{sysutil.C_BOLD}{sysutil.C_CYAN}:: Network Bypass Status{sysutil.C_RESET}\n")

    vpn_active = vpn.get_active_vpn_service()
    warp_state, _ = vpn.get_warp_status()
    if vpn_active:
        print(f"  {sysutil.C_GREEN}[●]{sysutil.C_RESET} {sysutil.C_BOLD}VPN (AmneziaWG):{sysutil.C_RESET} {sysutil.C_GREEN}ACTIVE{sysutil.C_RESET} ({vpn_active})")
    elif warp_state == "connected":
        print(f"  {sysutil.C_GREEN}[●]{sysutil.C_RESET} {sysutil.C_BOLD}VPN (Cloudflare WARP):{sysutil.C_RESET} {sysutil.C_GREEN}CONNECTED{sysutil.C_RESET}")
    else:
        print(f"  {sysutil.C_DIM}[○]{sysutil.C_RESET} {sysutil.C_BOLD}VPN:{sysutil.C_RESET} {sysutil.C_DIM}INACTIVE{sysutil.C_RESET}")

    zapret_running = sysutil.is_service_active(sysutil.ZAPRET_SERVICE)
    strat = zapret.parse_zapret_conf().get("strategy", "unconfigured")
    if zapret_running:
        print(f"  {sysutil.C_GREEN}[●]{sysutil.C_RESET} {sysutil.C_BOLD}Zapret (zapret-rust):{sysutil.C_RESET} {sysutil.C_GREEN}ACTIVE{sysutil.C_RESET} ({strat})")
    else:
        print(f"  {sysutil.C_DIM}[○]{sysutil.C_RESET} {sysutil.C_BOLD}Zapret (zapret-rust):{sysutil.C_RESET} {sysutil.C_DIM}INACTIVE{sysutil.C_RESET} ({strat})")

    blocky_running = sysutil.is_service_active(sysutil.BLOCKY_SERVICE)
    dns_mode = dns.get_active_dns_provider()
    if dns_mode == "isp":
        print(f"  {sysutil.C_YELLOW}[○]{sysutil.C_RESET} {sysutil.C_BOLD}DNS Resolver:{sysutil.C_RESET} isp (Blocky bypassed)")
    elif blocky_running:
        print(f"  {sysutil.C_GREEN}[●]{sysutil.C_RESET} {sysutil.C_BOLD}DNS Resolver (Blocky):{sysutil.C_RESET} {sysutil.C_GREEN}{dns_mode}{sysutil.C_RESET}")
    else:
        print(f"  {sysutil.C_RED}[!]{sysutil.C_RESET} {sysutil.C_BOLD}DNS Resolver (Blocky):{sysutil.C_RESET} {sysutil.C_RED}STOPPED{sysutil.C_RESET} (configured: {dns_mode})")

    if sysutil.is_service_active(sysutil.GAME_BYPASS_SERVICE):
        print(f"  {sysutil.C_GREEN}[●]{sysutil.C_RESET} {sysutil.C_BOLD}Game Split-Tunnel:{sysutil.C_RESET} {sysutil.C_GREEN}ACTIVE{sysutil.C_RESET} (fwmark 0x51)")
    else:
        print(f"  {sysutil.C_DIM}[○]{sysutil.C_RESET} {sysutil.C_BOLD}Game Split-Tunnel:{sysutil.C_RESET} {sysutil.C_DIM}INACTIVE{sysutil.C_RESET}")

    pub_ip, loc = get_public_ip_info()
    print(f"  {sysutil.C_CYAN}[i]{sysutil.C_RESET} {sysutil.C_BOLD}Public IP:{sysutil.C_RESET} {pub_ip} [{loc}]\n")
    return 0
