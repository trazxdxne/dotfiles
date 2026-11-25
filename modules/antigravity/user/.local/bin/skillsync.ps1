param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$SkillArgs
)
& python "$PSScriptRoot\skillsync" @SkillArgs
