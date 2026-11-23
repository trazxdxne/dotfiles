param(
    [ValidateSet("comss", "cloudflare", "quad9", "reset", "status")]
    [string]$Preset = "comss",
    [string]$InterfaceAlias
)

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin -and $Preset -ne "status") {
    Start-Process powershell.exe -ArgumentList ("-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`" -Preset $Preset") -Verb RunAs
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

if ($Preset -eq "status") {
    Write-Host "`n:: Active Network Interface: $InterfaceAlias" -ForegroundColor Cyan
    Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | Format-Table -AutoSize
    Write-Host ":: Registered DoH Server Addresses:" -ForegroundColor Cyan
    Get-DnsClientDohServerAddress | Format-Table -AutoSize
    exit
}

if ($Preset -eq "reset") {
    Write-Host ":: Resetting DNS on $InterfaceAlias to automatic (DHCP)..." -ForegroundColor Cyan
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ResetServerAddresses
    Clear-DnsClientCache
    Write-Host "[OK] Reset complete. DNS assigned by router/DHCP." -ForegroundColor Green
    exit
}

$DnsConfigs = @{
    "comss" = @{
        Servers = @("93.115.24.204", "93.115.24.205")
        Template = "https://dns.comss.one/dns-query"
        Name = "Comss DoH (AI & Geo-Bypass)"
    }
    "cloudflare" = @{
        Servers = @("1.1.1.1", "1.0.0.1")
        Template = "https://cloudflare-dns.com/dns-query"
        Name = "Cloudflare DoH (1.1.1.1)"
    }
    "quad9" = @{
        Servers = @("9.9.9.9", "149.112.112.112")
        Template = "https://dns.quad9.net/dns-query"
        Name = "Quad9 DoH (9.9.9.9)"
    }
}

$cfg = $DnsConfigs[$Preset]
Write-Host ":: Applying $($cfg.Name) to interface $InterfaceAlias..." -ForegroundColor Cyan

foreach ($srv in $cfg.Servers) {
    try {
        Add-DnsClientDohServerAddress -ServerAddress $srv -DohTemplate $cfg.Template -AllowFallbackToUdp $true -AutoUpgrade $true -ErrorAction SilentlyContinue
    } catch {}
}

Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $cfg.Servers
Clear-DnsClientCache

Write-Host "[OK] $($cfg.Name) successfully applied to $InterfaceAlias." -ForegroundColor Green
Write-Host ":: DNS cache cleared. Current configuration:" -ForegroundColor Cyan
Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | Format-Table -AutoSize
