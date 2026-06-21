function grep {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args2)

    $spec = @{
        'i' = @{ Long = 'ignore-case'; Type = 'switch' }
        'v' = @{ Long = 'invert-match'; Type = 'switch' }
        'n' = @{ Long = 'line-number'; Type = 'switch' }
        'c' = @{ Long = 'count'; Type = 'switch' }
        'l' = @{ Long = 'files-with-matches'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args2 -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: grep [-i] [-v] [-n] [-c] [-l] [--help] PATTERN [FILE]...'
    }

    $ignoreCase = $parsed.Options['i'] -or $parsed.LongOptions['ignore-case']
    $invertMatch = $parsed.Options['v'] -or $parsed.LongOptions['invert-match']
    $showLineNumber = $parsed.Options['n'] -or $parsed.LongOptions['line-number']
    $onlyCount = $parsed.Options['c'] -or $parsed.LongOptions['count']
    $onlyFiles = $parsed.Options['l'] -or $parsed.LongOptions['files-with-matches']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'grep' -Message 'missing pattern'
        return
    }

    $pattern = $parsed.Positional[0]
    $files = $parsed.Positional[1..($parsed.Positional.Count - 1)]

    foreach ($p in $files) {
        $fp = Convert-BashPath $p
        if (-not (Test-Path $fp)) {
            Write-BashError -Command 'grep' -Message "cannot access '$p'"
            continue
        }

        $content = Get-Content $fp
        $foundMatches = @()
        $lineNum = 1

        foreach ($line in $content) {
            $isMatch = if ($ignoreCase) { $line -imatch $pattern } else { $line -match $pattern }
            if ($isMatch -and -not $invertMatch) { $foundMatches += @{ Line = $line; Num = $lineNum } }
            elseif (-not $isMatch -and $invertMatch) { $foundMatches += @{ Line = $line; Num = $lineNum } }
            $lineNum++
        }

        if ($onlyCount) { Write-Output "${fp}: $($foundMatches.Count)" }
        elseif ($onlyFiles) { if ($foundMatches.Count -gt 0) { Write-Output $fp } }
        else {
            foreach ($m in $foundMatches) {
                if ($showLineNumber) { Write-Output "${fp}:$($m.Num):$($m.Line)" }
                else { Write-Output "${fp}:$($m.Line)" }
            }
        }
    }
}
function find {
    param($Path='.', [string]$name, [string]$type, [switch]$Help)
    if ($Help) { return 'Usage: find PATH -name PATTERN -type f|d' }
    $p = Convert-BashPath $Path
    $items = Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue
    if ($name) { $items = $items | Where { $_.Name -like $name } }
    if ($type -eq 'f') { $items = $items | Where { $_ -is [System.IO.FileInfo] } }
    if ($type -eq 'd') { $items = $items | Where { $_ -is [System.IO.DirectoryInfo] } }
    $items.FullName
}
function which {
    param([string]$Command, [switch]$a, [switch]$Help)
    if ($Help) { return 'Usage: which [-a] COMMAND' }
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        if ($a) { $cmd.Source }
        else { $cmd.Source | Select -First 1 }
    }
}
