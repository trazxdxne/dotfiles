param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PatcherArgs
)

$Candidates = @(
    "C:\WINDOWS\system32\eligibility-antigravity-patcher\manager.py",
    "$env:USERPROFILE\.local\share\eligibility-antigravity-patcher\manager.py",
    "$env:USERPROFILE\eligibility-antigravity-patcher\manager.py"
)

$PatcherScript = $null
foreach ($path in $Candidates) {
    if (Test-Path $path) {
        $PatcherScript = $path
        break
    }
}

if (-not $PatcherScript) {
    $targetDir = "$env:USERPROFILE\.local\share\eligibility-antigravity-patcher"
    Write-Host ":: Cloning eligibility-antigravity-patcher into $targetDir..." -ForegroundColor Cyan
    git clone https://github.com/QNIX-Dev/eligibility-antigravity-patcher $targetDir
    $PatcherScript = "$targetDir\manager.py"
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Host "error: python is not found in PATH." -ForegroundColor Red
    exit 1
}

if (-not $PatcherArgs -or $PatcherArgs.Count -eq 0) {
    python $PatcherScript patch
} else {
    python $PatcherScript @PatcherArgs
}
