function head {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

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
    param(
        [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value' }
        'f' = @{ Long = 'follow'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

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
    param(
        [switch]$l, [switch]$w, [switch]$c, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($l) { $allArgs += '-l' }
    if ($w) { $allArgs += '-w' }
    if ($c) { $allArgs += '-c' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'l' = @{ Long = 'lines'; Type = 'switch' }
        'w' = @{ Long = 'words'; Type = 'switch' }
        'c' = @{ Long = 'bytes'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

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
        $wordCount = ($content | ForEach-Object { $_.Split(' ') } | Measure-Object).Count
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
    param(
        [switch]$n, [switch]$r, [switch]$u, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($r) { $allArgs += '-r' }
    if ($u) { $allArgs += '-u' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'numeric'; Type = 'switch' }
        'r' = @{ Long = 'reverse'; Type = 'switch' }
        'u' = @{ Long = 'unique'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

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
    param(
        [switch]$c, [switch]$d, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($c) { $allArgs += '-c' }
    if ($d) { $allArgs += '-d' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'c' = @{ Long = 'count'; Type = 'switch' }
        'd' = @{ Long = 'repeated'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: uniq [-c] [-d] [--help]'
    }

    $showCount = $parsed.Options['c'] -or $parsed.LongOptions['count']
    $onlyRepeats = $parsed.Options['d'] -or $parsed.LongOptions['repeated']

    $input = $input | Sort-Object
    if ($onlyRepeats) {
        $input | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
    }
    elseif ($showCount) {
        $input | Group-Object | ForEach-Object { Write-Output "$($_.Count) $($_.Name)" }
    }
    else {
        $input | Get-Unique
    }
}
function cut {
    param(
        [switch]$d, [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $spec = @{
        'd' = @{ Long = 'delimiter'; Type = 'value'; DefaultValue = ' ' }
        'f' = @{ Long = 'fields'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    # Pair value switches with values from ArgList
    $remaining = @($ArgList)
    $allArgs = @()
    if ($d) { $allArgs += '-d'; if ($remaining.Count -gt 0) { $allArgs += $remaining[0]; $remaining = $remaining[1..($remaining.Count-1)] } }
    if ($f) { $allArgs += '-f'; if ($remaining.Count -gt 0) { $allArgs += $remaining[0]; $remaining = $remaining[1..($remaining.Count-1)] } }
    if ($help) { $allArgs += '-help' }
    $allArgs += $remaining

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: cut -d DELIM -f FIELDS [--help] FILE'
    }

    $delimiter = $parsed.Options['d']
    if (-not $delimiter) { $delimiter = ' ' }
    $fields = $parsed.Options['f']
    if (-not $fields) {
        Write-BashError -Command 'cut' -Message 'missing field specification'
        return
    }

    $fieldList = $fields.Split(',')

    if ($parsed.Positional.Count -gt 0) {
        $content = Get-Content (Convert-BashPath $parsed.Positional[0])
    } else {
        $content = $input
    }

    foreach ($line in $content) {
        $parts = $line.Split($delimiter)
        $out = ''
        foreach ($fld in $fieldList) {
            $idx = [int]$fld - 1
            if ($idx -ge 0 -and $idx -lt $parts.Count) { $out += $parts[$idx] + $delimiter }
        }
        Write-Output $out.TrimEnd($delimiter)
    }
}
function tr {
    param(
        [switch]$d, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($d) { $allArgs += '-d' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'd' = @{ Long = 'delete'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: tr SET1 SET2 | tr -d SET1 [--help]'
    }

    $deleteMode = $parsed.Options['d'] -or $parsed.LongOptions['delete']

    if ($deleteMode) {
        if ($parsed.Positional.Count -eq 0) {
            Write-BashError -Command 'tr' -Message 'missing SET1'
            return
        }
        $SET1 = $parsed.Positional[0]
        $content = $input
        foreach ($c in $SET1.ToCharArray()) {
            $content = $content -replace $c, ''
        }
        Write-Output $content
    } else {
        if ($parsed.Positional.Count -lt 2) {
            Write-BashError -Command 'tr' -Message 'missing SET2'
            return
        }
        $SET1 = $parsed.Positional[0]
        $SET2 = $parsed.Positional[1]
        $content = $input
        for ($i = 0; $i -lt [Math]::Min($SET1.Length, $SET2.Length); $i++) {
            $content = $content -replace $SET1[$i], $SET2[$i]
        }
        Write-Output $content
    }
}
