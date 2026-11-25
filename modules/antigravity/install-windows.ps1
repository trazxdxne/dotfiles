param(
    [switch]$Status,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$SourceUser = Join-Path $RepoRoot "modules\antigravity\user"
$HomeDir = $env:USERPROFILE

$BinSrc = Join-Path $SourceUser ".local\bin"
$BinDst = Join-Path $HomeDir ".local\bin"
$GeminiSrc = Join-Path $SourceUser ".gemini\config"
$GeminiDst = Join-Path $HomeDir ".gemini\config"
$AgentsSrc = Join-Path $SourceUser ".agents"
$AgentsDst = Join-Path $HomeDir ".agents"

if ($Status) {
    Write-Host ":: Antigravity Windows Sync Status" -ForegroundColor Cyan
    Write-Host "   Repo Source : $SourceUser"
    Write-Host "   Local Bin   : $BinDst (exists: $(Test-Path $BinDst))"
    Write-Host "   Gemini Conf : $GeminiDst (exists: $(Test-Path $GeminiDst))"
    Write-Host "   Agents Dir  : $AgentsDst (exists: $(Test-Path $AgentsDst))"
    $eccMcp = Join-Path $GeminiDst "plugins\ecc\mcp_config.json"
    if (Test-Path $eccMcp) {
        $hasWinPath = (Get-Content $eccMcp -Raw) -match [regex]::Escape(($HomeDir -replace '\\', '/'))
        Write-Host "   ECC MCP Path: $(if ($hasWinPath) { 'Windows path ok' } else { 'Needs sync' })"
    }
    exit 0
}

function Test-HasReparseParent {
    param([string]$TargetPath, [string]$StopAt)
    $cur = Split-Path $TargetPath -Parent
    while ($cur -and ($cur.Length -ge $StopAt.Length)) {
        if ((Test-Path $cur) -and ((Get-Item $cur).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            return $true
        }
        if ($cur -eq $StopAt) { break }
        $cur = Split-Path $cur -Parent
    }
    return $false
}

function Sync-Tree {
    param([string]$From, [string]$To)
    if (-not (Test-Path $From)) { return }
    New-Item -ItemType Directory -Path $To -Force | Out-Null
    Get-ChildItem -Path $From -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($From.Length).TrimStart('\', '/')
        $destFile = Join-Path $To $rel
        if ((-not $Force) -and (Test-HasReparseParent -TargetPath $destFile -StopAt $To)) {
            return
        }
        $destParent = Split-Path $destFile -Parent
        if (-not (Test-Path $destParent)) {
            New-Item -ItemType Directory -Path $destParent -Force | Out-Null
        }
        if ((Test-Path $destFile) -and ((Get-Item $destFile).Attributes -band [IO.FileAttributes]::ReparsePoint) -and -not $Force) {
            return
        }
        Copy-Item -Path $_.FullName -Destination $destFile -Force
    }
}

Write-Host ":: Installing Antigravity Windows user configs..." -ForegroundColor Cyan
Sync-Tree -From $BinSrc -To $BinDst
Sync-Tree -From $GeminiSrc -To $GeminiDst
Sync-Tree -From $AgentsSrc -To $AgentsDst

foreach ($sub in @("plugins\ecc\agents", "plugins\ecc\skills", "plugins\ecc\rules")) {
    $srcSub = Join-Path $GeminiSrc $sub
    $dstSub = Join-Path $GeminiDst $sub
    if ((Test-Path $srcSub) -and (Test-Path $dstSub)) {
        $srcRel = @(Get-ChildItem -Path $srcSub -Recurse -File | ForEach-Object { $_.FullName.Substring($srcSub.Length).TrimStart('\', '/') })
        Get-ChildItem -Path $dstSub -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($dstSub.Length).TrimStart('\', '/')
            if ($rel -notin $srcRel) {
                Remove-Item -Path $_.FullName -Force
            }
        }
        Get-ChildItem -Path $dstSub -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
            if (-not (Get-ChildItem -Path $_.FullName -Force)) {
                Remove-Item -Path $_.FullName -Force
            }
        }
    }
}

$TargetEccMcp = Join-Path $GeminiDst "plugins\ecc\mcp_config.json"
if (Test-Path $TargetEccMcp) {
    $winPosixHome = "/" + (($HomeDir -replace '\\', '/') -replace ':', '').ToLower().Substring(0,1) + ($HomeDir -replace '\\', '/').Substring(2)
    $raw = Get-Content $TargetEccMcp -Raw
    $patched = $raw -replace '/home/trazxdxne', $winPosixHome
    if ($patched -ne $raw) {
        Set-Content -Path $TargetEccMcp -Value $patched -NoNewline -Encoding UTF8
    }
}

$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($UserPath -notlike "*$BinDst*") {
    [Environment]::SetEnvironmentVariable("Path", "$BinDst;$UserPath", "User")
    Write-Host ":: Added $BinDst to User PATH (restart shell to take effect)." -ForegroundColor Yellow
}

Write-Host "[+] Antigravity Windows sync complete." -ForegroundColor Green
