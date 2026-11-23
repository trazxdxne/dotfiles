param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PatcherArgs
)
& "$PSScriptRoot\agypatch.ps1" @PatcherArgs
