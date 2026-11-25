param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$SyncArgs
)
& python "$PSScriptRoot\reposync" @SyncArgs
