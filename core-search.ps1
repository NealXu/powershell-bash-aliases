function grep {
    param(
        [switch]$i, [switch]$v, [switch]$n, [switch]$c, [switch]$l, [switch]$help
    )

    begin {
        $pipelineLines = [System.Collections.ArrayList]@()
        $allArgs = @()
        if ($i) { $allArgs += '-i' }
        if ($v) { $allArgs += '-v' }
        if ($n) { $allArgs += '-n' }
        if ($c) { $allArgs += '-c' }
        if ($l) { $allArgs += '-l' }
        if ($help) { $allArgs += '-help' }
        $allArgs += $args

        $spec = @{
            'i' = @{ Long = 'ignore-case'; Type = 'switch' }
            'v' = @{ Long = 'invert-match'; Type = 'switch' }
            'n' = @{ Long = 'line-number'; Type = 'switch' }
            'c' = @{ Long = 'count'; Type = 'switch' }
            'l' = @{ Long = 'files-with-matches'; Type = 'switch' }
            'help' = @{ Long = 'help'; Type = 'switch' }
        }

        $script:grepParsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec
        $script:grepIgnoreCase = $script:grepParsed.Options['i'] -or $script:grepParsed.LongOptions['ignore-case']
        $script:grepInvertMatch = $script:grepParsed.Options['v'] -or $script:grepParsed.LongOptions['invert-match']
        $script:grepShowLineNumber = $script:grepParsed.Options['n'] -or $script:grepParsed.LongOptions['line-number']
        $script:grepOnlyCount = $script:grepParsed.Options['c'] -or $script:grepParsed.LongOptions['count']
        $script:grepOnlyFiles = $script:grepParsed.Options['l'] -or $script:grepParsed.LongOptions['files-with-matches']
        $script:grepPattern = if ($script:grepParsed.Positional.Count -gt 0) { $script:grepParsed.Positional[0] } else { $null }
        $script:grepFiles = @()
        if ($script:grepParsed.Positional.Count -gt 1) {
            $script:grepFiles = @($script:grepParsed.Positional[1..($script:grepParsed.Positional.Count - 1)])
        }
    }

    process {
        if ($null -ne $_) {
            [void]$pipelineLines.Add("$_")
        }
    }

    end {
        if ($script:grepParsed.Options['help']) {
            return 'Usage: grep [-i] [-v] [-n] [-c] [-l] [--help] PATTERN [FILE]...'
        }

        if ($null -eq $script:grepPattern) {
            Write-BashError -Command 'grep' -Message 'missing pattern'
            return
        }

        if ($script:grepFiles.Count -gt 0) {
            foreach ($p in $script:grepFiles) {
                $fp = Convert-BashPath $p
                if (-not (Test-Path $fp)) {
                    Write-BashError -Command 'grep' -Message "cannot access '$p'"
                    continue
                }

                $content = Read-BashFileContent $fp
                $foundMatches = @()
                $lineNum = 1

                foreach ($line in $content) {
                    $isMatch = if ($script:grepIgnoreCase) { $line -imatch $script:grepPattern } else { $line -cmatch $script:grepPattern }
                    if ($isMatch -and -not $script:grepInvertMatch) { $foundMatches += @{ Line = $line; Num = $lineNum } }
                    elseif (-not $isMatch -and $script:grepInvertMatch) { $foundMatches += @{ Line = $line; Num = $lineNum } }
                    $lineNum++
                }

                if ($script:grepOnlyCount) { Write-Output "${fp}: $($foundMatches.Count)" }
                elseif ($script:grepOnlyFiles) { if ($foundMatches.Count -gt 0) { Write-Output $fp } }
                else {
                    foreach ($m in $foundMatches) {
                        if ($script:grepShowLineNumber) { Write-Output "${fp}:$($m.Num):$($m.Line)" }
                        else { Write-Output "${fp}:$($m.Line)" }
                    }
                }
            }
        }
        elseif ($pipelineLines.Count -gt 0) {
            $foundMatches = @()
            $lineNum = 1

            foreach ($line in $pipelineLines) {
                $isMatch = if ($script:grepIgnoreCase) { $line -imatch $script:grepPattern } else { $line -cmatch $script:grepPattern }
                if ($isMatch -and -not $script:grepInvertMatch) { $foundMatches += @{ Line = $line; Num = $lineNum } }
                elseif (-not $isMatch -and $script:grepInvertMatch) { $foundMatches += @{ Line = $line; Num = $lineNum } }
                $lineNum++
            }

            if ($script:grepOnlyCount) { Write-Output "$($foundMatches.Count)" }
            elseif ($script:grepOnlyFiles) { if ($foundMatches.Count -gt 0) { Write-Output "stdin" } }
            else {
                foreach ($m in $foundMatches) {
                    if ($script:grepShowLineNumber) { Write-Output "$($m.Num):$($m.Line)" }
                    else { Write-Output $m.Line }
                }
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
