function head {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: head [-n N] [--help] FILE'
    }

    $lines = $parsed.Options['n']
    if (-not $lines) { $lines = 10 }

    if ($parsed.Positional.Count -gt 0) {
        $path = Convert-BashPath $parsed.Positional[0]
        Get-Content $path | Select-Object -First ([int]$lines)
    }
}
function tail {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value' }
        'f' = @{ Long = 'follow'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: tail [-n N] [-f] [--help] FILE'
    }

    $lines = $parsed.Options['n']
    if (-not $lines) { $lines = 10 }
    $follow = $parsed.Options['f'] -or $parsed.LongOptions['follow']

    if ($parsed.Positional.Count -gt 0) {
        $path = Convert-BashPath $parsed.Positional[0]
        if ($follow) { Get-Content $path -Wait }
        else { Get-Content $path | Select-Object -Last ([int]$lines) }
    }
}
function wc {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'l' = @{ Long = 'lines'; Type = 'switch' }
        'w' = @{ Long = 'words'; Type = 'switch' }
        'c' = @{ Long = 'bytes'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: wc [-l] [-w] [-c] [--help] FILE...'
    }

    $showLines = $parsed.Options['l'] -or $parsed.LongOptions['lines']
    $showWords = $parsed.Options['w'] -or $parsed.LongOptions['words']
    $showBytes = $parsed.Options['c'] -or $parsed.LongOptions['bytes']

    foreach ($f in $parsed.Positional) {
        $fp = Convert-BashPath $f
        $content = Get-Content $fp
        $lineCount = $content.Count
        $wordCount = ($content | ForEach { $_.Split(' ') } | Measure-Object).Count
        $byteCount = ($content | Measure-Object -Property Length -Sum).Sum

        if (-not $showLines -and -not $showWords -and -not $showBytes) {
            Write-Output "$lineCount $wordCount $byteCount $f"
        } else {
            $out = ''
            if ($showLines) { $out += "$lineCount " }
            if ($showWords) { $out += "$wordCount " }
            if ($showBytes) { $out += "$byteCount " }
            Write-Output "$out$f"
        }
    }
}
function sort {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'n' = @{ Long = 'numeric'; Type = 'switch' }
        'r' = @{ Long = 'reverse'; Type = 'switch' }
        'u' = @{ Long = 'unique'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: sort [-n] [-r] [-u] [--help] [FILE]'
    }

    $numeric = $parsed.Options['n'] -or $parsed.LongOptions['numeric']
    $reverse = $parsed.Options['r'] -or $parsed.LongOptions['reverse']
    $unique = $parsed.Options['u'] -or $parsed.LongOptions['unique']

    if ($parsed.Positional.Count -gt 0) {
        $content = Get-Content (Convert-BashPath $parsed.Positional[0])
    } else {
        $content = $input
    }

    $sorted = if ($numeric) { $content | Sort-Object {[double]$_} } else { $content | Sort-Object }
    if ($reverse) { $sorted = $sorted | Sort-Object -Descending }
    if ($unique) { $sorted = $sorted | Get-Unique }
    $sorted
}
function uniq {
    param([switch]$c, [switch]$d, [switch]$Help)
    if ($Help) { return 'Usage: uniq [-c] [-d]' }
    $input = $input | Sort
    if ($d) { $input | Get-Unique }
    elseif ($c) { $input | Group | ForEach { Write-Output "{$($_.Count)} $($_.Name)" } }
    else { $input | Get-Unique }
}
function cut {
    param([string]$d=' ', [string]$f, [string[]]$Path, [switch]$Help)
    if ($Help) { return 'Usage: cut -d DELIM -f FIELDS FILE' }
    $content = if ($Path) { Get-Content (Convert-BashPath $Path[0]) } else { $input }
    $fields = $f.Split(',')
    foreach ($line in $content) {
        $parts = $line.Split($d)
        $out = ''
        foreach ($fld in $fields) {
            $idx = [int]$fld - 1
            if ($idx -ge 0 -and $idx -lt $parts.Count) { $out += $parts[$idx] + $d }
        }
        Write-Output $out.TrimEnd($d)
    }
}
function tr {
    param([string]$SET1, [string]$SET2, [switch]$d, [switch]$Help)
    if ($Help) { return 'Usage: tr SET1 SET2 | tr -d SET1' }
    $content = $input
    if ($d) {
        foreach ($c in $SET1.ToCharArray()) {
            $content = $content -replace $c, ''
        }
        Write-Output $content
    } else {
        for ($i = 0; $i -lt [Math]::Min($SET1.Length, $SET2.Length); $i++) {
            $content = $content -replace $SET1[$i], $SET2[$i]
        }
        Write-Output $content
    }
}
