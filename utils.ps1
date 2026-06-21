function Format-FileSize {
    param([long]$Bytes, [switch]$HumanReadable)
    if (-not $HumanReadable) { return $Bytes.ToString() }
    $units = @('B','K','M','G','T','P')
    $size = [double]$Bytes; $i = 0
    while ($size -ge 1024 -and $i -lt 5) { $size /= 1024; $i++ }
    return '{0:N1}{1}' -f $size, $units[$i]
}
function Format-FileTime {
    param([DateTime]$Time)
    $ci = [CultureInfo]::InvariantCulture
    $month = $Time.ToString('MMM', $ci)
    $day = '{0,2}' -f $Time.Day
    if ($Time -gt (Get-Date).AddDays(-180)) { return "$month $day $($Time.ToString('HH:mm'))" }
    return "$month $day  $($Time.Year)"
}
function Format-UnixMode {
    param($Item)
    if ($Item -is [System.IO.DirectoryInfo]) { return 'drwxr-xr-x' }
    return '-rw-r--r--'
}
function Format-Columns {
    param([string[]]$Items, [int]$MaxWidth = 80)
    if ($Items.Count -eq 0) { return '' }
    $maxW = ($Items | ForEach { $_.Length } | Measure -Max).Maximum
    $cols = [Math]::Max(1, [Math]::Floor($MaxWidth / ($maxW + 2)))
    $rows = [Math]::Ceiling($Items.Count / $cols)
    $out = @()
    for ($r=0; $r -lt $rows; $r++) {
        $line = ''
        for ($c=0; $c -lt $cols; $c++) {
            $idx = $r + $c * $rows
            if ($idx -lt $Items.Count) { $line += $Items[$idx].PadRight($maxW) + '  ' }
        }
        $out += $line.TrimEnd()
    }
    return ($out -join [char]10).TrimEnd()
}
function Convert-BashPath {
    param([string]$Path)
    if ($Path -eq '.' -or $Path -eq '..') { return $Path }
    if ($Path.StartsWith('~')) { return $HOME + $Path.Substring(1) }
    return $Path
}
