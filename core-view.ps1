function less {
    param(
        [switch]$Help
    )

    $ArgList = @($args)

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
        $content = Read-BashFileContent (Convert-BashPath $paths[0])
    }
    Show-PagedOutput $content
}

function more {
    param(
        [switch]$d, [switch]$f, [switch]$help
    )

    $ArgList = @($args)

    $allArgs = @()
    if ($d) { $allArgs += '-d' }
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'd' = @{ Long = 'silent'; Type = 'switch' }
        'f' = @{ Long = 'logical'; Type = 'switch' }
        'p' = @{ Long = 'pattern'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: more [-d] [-f] [-p PATTERN] [FILE]... [--help]'
    }

    $silent = $parsed.Options['d'] -or $parsed.LongOptions['silent']
    $logical = $parsed.Options['f'] -or $parsed.LongOptions['logical']
    $pattern = $parsed.Options['p']

    # Get content from files or pipeline
    $content = @()
    if ($parsed.Positional.Count -gt 0) {
        foreach ($file in $parsed.Positional) {
            $filePath = Convert-BashPath $file
            if (Test-Path $filePath) {
                $content += Read-BashFileContent $filePath
            } else {
                Write-BashError -Command 'more' -Message "cannot access '$filePath'"
            }
        }
    } else {
        $content = @($input)
    }

    if ($content.Count -eq 0) {
        return
    }

    # Filter by pattern if specified
    if ($pattern) {
        $content = $content | Where-Object { $_ -match $pattern }
    }

    # Interactive pager with arrow-key scrolling (see Show-PagedOutput)
    Show-PagedOutput $content
}
