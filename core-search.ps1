function grep {
    param(
        [switch]$i, [switch]$v, [switch]$n, [switch]$c, [switch]$l, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($i) { $allArgs += '-i' }
    if ($v) { $allArgs += '-v' }
    if ($n) { $allArgs += '-n' }
    if ($c) { $allArgs += '-c' }
    if ($l) { $allArgs += '-l' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'i' = @{ Long = 'ignore-case'; Type = 'switch' }
        'v' = @{ Long = 'invert-match'; Type = 'switch' }
        'n' = @{ Long = 'line-number'; Type = 'switch' }
        'c' = @{ Long = 'count'; Type = 'switch' }
        'l' = @{ Long = 'files-with-matches'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

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
            $isMatch = if ($ignoreCase) { $line -imatch $pattern } else { $line -cmatch $pattern }
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
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'name' = @{ Long = 'name'; Type = 'value' }
        'type' = @{ Long = 'type'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: find PATH -name PATTERN -type f|d [--help]'
    }

    $namePattern = $parsed.Options['name']
    $typeFilter = $parsed.Options['type']

    $path = if ($parsed.Positional.Count -gt 0) { $parsed.Positional[0] } else { '.' }
    $p = Convert-BashPath $path

    $rootItem = Get-Item $p -ErrorAction SilentlyContinue
    $items = @()
    if ($rootItem) { $items = @($rootItem) }
    $items += @(Get-ChildItem $p -Recurse -ErrorAction SilentlyContinue)
    if ($namePattern) { $items = $items | Where-Object { $_.Name -like $namePattern } }
    if ($typeFilter -eq 'f') { $items = $items | Where-Object { $_ -is [System.IO.FileInfo] } }
    if ($typeFilter -eq 'd') { $items = $items | Where-Object { $_ -is [System.IO.DirectoryInfo] } }
    $items.FullName
}
function which {
    param(
        [switch]$a, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($a) { $allArgs += '-a' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'a' = @{ Long = 'all'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: which [-a] [--help] COMMAND'
    }

    $showAll = $parsed.Options['a'] -or $parsed.LongOptions['all']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'which' -Message 'missing command name'
        return
    }

    $Command = $parsed.Positional[0]
    $cmd = Get-Command $Command -ErrorAction SilentlyContinue
    if ($cmd) {
        if ($showAll) { $cmd.Source }
        else { $cmd.Source | Select-Object -First 1 }
    }
}
