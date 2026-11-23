param(
    [string]$Preset = "status",
    [string]$InterfaceAlias,
    [switch]$List,
    [switch]$DisableIPv6,
    [switch]$EnableIPv6
)

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin -and $Preset -ne "status" -and -not $List) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Preset $Preset"
    if ($InterfaceAlias) { $argList += " -InterfaceAlias `"$InterfaceAlias`"" }
    if ($DisableIPv6) { $argList += " -DisableIPv6" }
    if ($EnableIPv6) { $argList += " -EnableIPv6" }
    Start-Process powershell.exe -ArgumentList $argList -Verb RunAs
    exit
}

if (-not $InterfaceAlias) {
    $activeAdapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if ($activeAdapter) {
        $InterfaceAlias = $activeAdapter.Name
    } else {
        $InterfaceAlias = "Ethernet"
    }
}

$DnsConfigs = [ordered]@{
    "comss" = @{
        Name = "Comss.one Primary (AI & Geo-Bypass)"
        Servers = @("93.115.24.204", "93.115.24.205")
        Template = "https://dns.comss.one/dns-query"
        Desc = "Popular Russian bypass DNS with proxying for AI and blocked resources"
    }
    "comss-alt" = @{
        Name = "Comss.one East/Secondary"
        Servers = @("195.133.25.16", "195.133.25.99")
        ServersIPv6 = @("2a03:6f00:a::3f24", "2a03:6f00:a::2944")
        Template = "https://dns.comss.one/dns-query"
        Desc = "Alternative Comss routing nodes"
    }
    "dns-ai" = @{
        Name = "DNS-AI.ru (Optimized for Gemini, Claude, ChatGPT & AI Studio)"
        Servers = @("194.87.196.13", "45.151.102.219")
        ServersIPv6 = @("2a00:b700:5::3:62", "2a12:5940:d4ef::219")
        Template = "https://dns.dns-ai.ru/dns-query"
        Desc = "Specialized SNI-proxying DNS for AI services with full IPv4/IPv6 support"
    }
    "geohide-eu" = @{
        Name = "GeoHide EU (European Routing & DE Proxy)"
        Servers = @("5.175.161.3", "5.175.161.40", "45.13.237.213", "143.20.64.192")
        Template = "https://eu.geohide.ru/dns-query"
        Desc = "GeoHide network routing via Germany proxy"
    }
    "geohide-us" = @{
        Name = "GeoHide US (US Routing & Fast US Proxy)"
        Servers = @("192.255.159.240", "192.255.159.241", "107.175.76.134")
        Template = "https://us.geohide.ru/dns-query"
        Desc = "US-based proxy for American services requiring US geolocation"
    }
    "geohide-ru" = @{
        Name = "GeoHide RU (Russian Routing & DE Proxy)"
        Servers = @("193.233.112.130", "193.233.112.67", "37.230.192.51")
        Template = "https://ru.geohide.ru/dns-query"
        Desc = "Fast Russian gateway with German AI egress proxy"
    }
    "malw" = @{
        Name = "Malw DNS (DE Proxy for ChatGPT & AI)"
        Servers = @("179.254.166.171", "164.5.224.81")
        Template = "https://dns.malw.link/dns-query"
        Desc = "German egress proxy for unblocking AI and services"
    }
    "magicdns" = @{
        Name = "MagicDNS (FI Proxy for ChatGPT & AI)"
        Servers = @("109.120.187.249", "217.144.190.216")
        Template = "https://dns.magicdns.ru/dns-query"
        Desc = "Finnish egress proxy"
    }
    "bezmezhau" = @{
        Name = "Bezmezhau (NL Proxy for AI & Unblocking)"
        Servers = @("143.20.64.55")
        Template = "https://dns.bezmezhau.com/dns-query"
        Desc = "Netherlands egress proxy"
    }
    "dagami" = @{
        Name = "Dagami (US Proxy for ChatGPT & AI)"
        Servers = @("179.254.186.80")
        Template = "https://dns.dagami.ru/dns-query"
        Desc = "US egress proxy"
    }
    "zapret-dns" = @{
        Name = "Zapret.moe DNS (Community Unblock)"
        Servers = @("83.217.211.149")
        ServersIPv6 = @("2a03:afc0:9::235d")
        Template = "https://dns.zapret.moe/dns-query"
        Desc = "Community anti-censorship DNS"
    }
    "nulls-proxy" = @{
        Name = "Null's Proxy DNS (Gaming & AI Proxy)"
        Servers = @("141.95.97.120", "185.175.46.137", "45.139.239.54")
        Template = "https://nullsproxy.com/dns-query"
        Desc = "Null's proxy for Supercell games and AI services"
    }
    "xbox-dns" = @{
        Name = "Xbox-DNS.ru (Consoles & Geo-Bypass)"
        Servers = @("176.99.11.77", "80.78.247.254")
        Template = "https://xbox-dns.ru/dns-query"
        Desc = "Xbox and gaming bypass DNS"
    }
    "cloudflare" = @{
        Name = "Cloudflare 1.1.1.1 (Privacy Strict)"
        Servers = @("1.1.1.1", "1.0.0.1")
        ServersIPv6 = @("2606:4700:4700::1111", "2606:4700:4700::1001")
        Template = "https://cloudflare-dns.com/dns-query"
        Desc = "High-speed encrypted privacy DNS (does NOT bypass geo-blocks)"
    }
    "quad9" = @{
        Name = "Quad9 9.9.9.9 (Malware Blocking)"
        Servers = @("9.9.9.9", "149.112.112.112")
        ServersIPv6 = @("2620:fe::fe", "2620:fe::9")
        Template = "https://dns.quad9.net/dns-query"
        Desc = "Secure DNS with threat protection"
    }
    "adguard" = @{
        Name = "AdGuard DNS (Ad & Tracker Blocking)"
        Servers = @("94.140.14.14", "94.140.15.15")
        ServersIPv6 = @("2a10:50c0::ad1:ff", "2a10:50c0::ad2:ff")
        Template = "https://dns.adguard-dns.com/dns-query"
        Desc = "Encrypted ad-blocking DNS"
    }
}

if ($List) {
    Write-Host "`n:: Available DNS Presets (from dns-conf-ui / dotfiles):" -ForegroundColor Cyan
    Write-Host "--------------------------------------------------------------------------------"
    foreach ($key in $DnsConfigs.Keys) {
        $entry = $DnsConfigs[$key]
        Write-Host "  $($key.PadRight(14)) - $($entry.Name)" -ForegroundColor Green
        Write-Host "                 $($entry.Desc)" -ForegroundColor Gray
    }
    Write-Host "--------------------------------------------------------------------------------"
    Write-Host "Usage: .\setup-windows-doh.ps1 -Preset <name>" -ForegroundColor Yellow
    Write-Host "       .\setup-windows-doh.ps1 -DisableIPv6   (prevents Russian IPv6 geo-leak)" -ForegroundColor Yellow
    Write-Host "       .\setup-windows-doh.ps1 -Preset reset  (restore DHCP DNS)`n" -ForegroundColor Yellow
    exit
}

if ($DisableIPv6) {
    Write-Host ":: Disabling IPv6 on adapter '$InterfaceAlias' to prevent ISP IPv6 geo-leak..." -ForegroundColor Yellow
    Disable-NetAdapterBinding -Name $InterfaceAlias -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    Write-Host "[OK] IPv6 disabled on $InterfaceAlias." -ForegroundColor Green
    if ($Preset -eq "status") { exit }
}

if ($EnableIPv6) {
    Write-Host ":: Enabling IPv6 on adapter '$InterfaceAlias'..." -ForegroundColor Cyan
    Enable-NetAdapterBinding -Name $InterfaceAlias -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue
    Write-Host "[OK] IPv6 enabled on $InterfaceAlias." -ForegroundColor Green
    if ($Preset -eq "status") { exit }
}

if ($Preset -eq "status") {
    Write-Host "`n:: Active Network Interface: $InterfaceAlias" -ForegroundColor Cyan
    $ipv6Status = (Get-NetAdapterBinding -Name $InterfaceAlias -ComponentID ms_tcpip6 -ErrorAction SilentlyContinue).Enabled
    if ($ipv6Status) {
        Write-Host "   IPv6 Protocol: ENABLED (Warning: Can leak Russian IPv6 to Google Gemini / AI Studio!)" -ForegroundColor Yellow
    } else {
        Write-Host "   IPv6 Protocol: DISABLED (Protected from IPv6 geo-leak)" -ForegroundColor Green
    }

    Write-Host "`n:: Current IPv4 DNS Servers on ${InterfaceAlias}:" -ForegroundColor Cyan
    Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | Select-Object -ExpandProperty ServerAddresses

    Write-Host "`n:: Current IPv6 DNS Servers on ${InterfaceAlias}:" -ForegroundColor Cyan
    Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv6 | Select-Object -ExpandProperty ServerAddresses

    Write-Host "`n:: Windows Registered DoH Servers:" -ForegroundColor Cyan
    Get-DnsClientDohServerAddress | Format-Table ServerAddress, AllowFallbackToUdp, AutoUpgrade, DohTemplate -AutoSize
    exit
}

if ($Preset -eq "reset") {
    Write-Host ":: Resetting DNS on $InterfaceAlias to automatic (DHCP)..." -ForegroundColor Cyan
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses
    Clear-DnsClientCache
    Write-Host "[OK] Reset complete. DNS assigned by router/DHCP." -ForegroundColor Green
    exit
}

if (-not $DnsConfigs.Contains($Preset)) {
    Write-Host "[!] Unknown preset '$Preset'." -ForegroundColor Red
    Write-Host "    Available presets: $($DnsConfigs.Keys -join ', ')" -ForegroundColor Yellow
    Write-Host "    Use -List to see detailed descriptions." -ForegroundColor Gray
    exit 1
}

$cfg = $DnsConfigs[$Preset]
Write-Host ":: Applying $($cfg.Name) to interface $InterfaceAlias..." -ForegroundColor Cyan

# Register IPv4 DoH templates
foreach ($srv in $cfg.Servers) {
    try {
        Add-DnsClientDohServerAddress -ServerAddress $srv -DohTemplate $cfg.Template -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue
    } catch {}
}

# Register IPv6 DoH templates if present
if ($cfg.ServersIPv6) {
    foreach ($srv6 in $cfg.ServersIPv6) {
        try {
            Add-DnsClientDohServerAddress -ServerAddress $srv6 -DohTemplate $cfg.Template -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue
        } catch {}
    }
}

# Apply DNS servers to adapter (supports both IPv4 and IPv6 in one call)
$allServers = @($cfg.Servers)
if ($cfg.ServersIPv6) {
    $allServers += $cfg.ServersIPv6
}
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $allServers

Clear-DnsClientCache

Write-Host "[OK] $($cfg.Name) successfully applied to $InterfaceAlias." -ForegroundColor Green
Write-Host ":: DNS cache cleared. Current configuration:" -ForegroundColor Cyan
Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias | Format-Table InterfaceAlias, AddressFamily, ServerAddresses -AutoSize
