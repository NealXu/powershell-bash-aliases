function less {
    param(
        [switch]$Help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($Help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: less FILE'
    }

    $paths = $parsed.Positional
    if ($paths.Count -eq 0) {
        $content = $input
    } else {
        $content = Get-Content (Convert-BashPath $paths[0])
    }
    $content | Out-Host -Paging
}
