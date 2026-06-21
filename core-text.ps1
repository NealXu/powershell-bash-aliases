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
    param([string[]]$Path, [switch]$l, [switch]$w, [switch]$c, [switch]$Help)
    if ($Help) { return 'Usage: wc [-l] [-w] [-c] FILE...' }
    foreach ($f in $Path) {
        $fp = Convert-BashPath $f
        $content = Get-Content $fp
        $lines = $content.Count
        $words = ($content | ForEach { $_.Split(' ') } | Measure).Count
        $chars = ($content | Measure -Property Length -Sum).Sum
        if (-not $l -and -not $w -and -not $c) { Write-Output "$lines $words $chars $f" }
        else {
            $out = ''
            if ($l) { $out += "$lines " }
            if ($w) { $out += "$words " }
            if ($c) { $out += "$chars " }
            Write-Output "$out$f" 
        }
    }
}
function sort {
    param([string[]]$Path, [switch]$n, [switch]$r, [switch]$u, [switch]$Help)
    if ($Help) { return 'Usage: sort [-n] [-r] [-u] FILE' }
    $content = if ($Path) { Get-Content (Convert-BashPath $Path[0]) } else { $input }
    $sorted = if ($n) { $content | Sort {[double]$_} } else { $content | Sort }
    if ($r) { $sorted = $sorted | Sort -Descending }
    if ($u) { $sorted = $sorted | Get-Unique }
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
