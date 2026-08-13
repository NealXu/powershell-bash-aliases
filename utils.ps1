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
function Read-BashFileContent {
    param([string]$Path)
    # BOM-aware file reader. Uses .NET File.ReadAllLines, which detects a
    # UTF-8/UTF-16 BOM and defaults to UTF-8 when there is no BOM. This avoids
    # Get-Content's behavior on Windows PowerShell 5.1, which decodes BOM-less
    # files as ANSI (GBK on Chinese systems) and garbles UTF-8 text.
    if (-not (Test-Path $Path)) { return $null }
    # Resolve relative paths against PowerShell's location, NOT the .NET
    # process CWD: File.ReadAllLines resolves relative paths against the
    # process working directory (fixed at process start), which diverges from
    # the PowerShell location after Set-Location/cd.
    $fullPath = (Resolve-Path $Path -ErrorAction SilentlyContinue).ProviderPath
    if (-not $fullPath) { $fullPath = $Path }
    return [System.IO.File]::ReadAllLines($fullPath)
}
function Step-PageTop {
    param([int]$Top, [int]$Total, [int]$PageSize, [string]$Key)
    # Pure key -> next scroll position. Kept free of console I/O so it can be
    # unit-tested; Show-PagedOutput drives it with live keystrokes.
    switch ($Key) {
        'UpArrow'   { return [Math]::Max(0, $Top - 1) }
        'DownArrow' { return [Math]::Min($Total - 1, $Top + 1) }
        'Spacebar'  { return [Math]::Min([Math]::Max(0, $Total - $PageSize), $Top + $PageSize) }
        'PageDown'  { return [Math]::Min([Math]::Max(0, $Total - $PageSize), $Top + $PageSize) }
        'PageUp'    { return [Math]::Max(0, $Top - $PageSize) }
        'Home'      { return 0 }
        'End'       { return [Math]::Max(0, $Total - $PageSize) }
        default     { return $Top }
    }
}
function Show-PagedOutput {
    param([string[]]$Content)
    # Interactive pager replacing Out-Host -Paging, which hard-codes
    # <SPACE>/<CR>/Q and cannot bind arrow keys. Scrolls with Up/Down
    # (line), PageUp/PageDown/Space (page), Home/End (start/end), Q (quit).
    $lines = @($Content)
    if ($lines.Count -eq 0) { return }

    $pageSize = 24
    try { $pageSize = [Math]::Max(1, $Host.UI.RawUI.WindowSize.Height - 2) } catch { }

    $total = $lines.Count
    if ($total -le $pageSize) {
        foreach ($line in $lines) { Write-Host $line }
        return
    }

    $top = 0
    while ($true) {
        [Console]::Clear()
        $end = [Math]::Min($top + $pageSize - 1, $total - 1)
        for ($i = $top; $i -le $end; $i++) { Write-Host $lines[$i] }
        Write-Host ("-- ({0}-{1}/{2}) Up/Down:line  Space/PgDn:next  PgUp:prev  Home/End:top/bottom  Q:quit --" -f ($top + 1), ($end + 1), $total) -ForegroundColor DarkGray

        $key = [Console]::ReadKey($true).Key.ToString()
        if ($key -eq 'Q') { break }
        $top = Step-PageTop -Top $top -Total $total -PageSize $pageSize -Key $key
    }
    Write-Host ''
}
