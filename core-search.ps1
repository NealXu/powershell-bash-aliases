function grep {
    param($Pattern, [string[]]$Path, [switch]$i, [switch]$v, [switch]$n, [switch]$Help)
    if ($Help) { return 'Usage: grep [-i] [-v] [-n] PATTERN FILE...' }
    foreach ($p in $Path) {
        $fp = Convert-BashPath $p
        if (-not (Test-Path $fp)) { Write-Error "grep: cannot access '$p'"; continue }
        $c = Get-Content $fp
        $lineNum = 1
        foreach ($line in $c) {
            $match = if ($i) { $line -imatch $Pattern } else { $line -match $Pattern }
            if ($match -and -not $v) {
                if ($n) { Write-Output ($fp + ':' + $lineNum + ':' + $line) } else { Write-Output ($fp + ':' + $line) }
            }
            $lineNum++
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
