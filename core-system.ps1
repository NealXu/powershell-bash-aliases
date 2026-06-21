function df {
    param([switch]$h, [switch]$Help)
    if ($Help) { return 'Usage: df [-h]' }
    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($d in $drives) {
        $used = $d.Used
        $free = $d.Free
        $total = $used + $free
        $pct = if ($total -gt 0) { [Math]::Round($used / $total * 100) } else { 0 }
        if ($h) {
            $usedH = Format-FileSize $used -HumanReadable
            $freeH = Format-FileSize $free -HumanReadable
            $totalH = Format-FileSize $total -HumanReadable
            Write-Output "$($d.Name)  $totalH  $usedH  $freeH  $pct%  $($d.Root)"
        } else {
            Write-Output "$($d.Name)  $total  $used  $free  $pct%  $($d.Root)"
        }
    }
}
function du {
    param($Path='.', [switch]$h, [switch]$s, [switch]$Help)
    if ($Help) { return 'Usage: du [-h] [-s] [PATH]' }
    $p = Convert-BashPath $Path
    $item = Get-Item $p
    if ($item -is [System.IO.DirectoryInfo]) {
        $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure -Property Length -Sum).Sum
    } else {
        $size = $item.Length
    }
    if ($h) { Write-Output "$(Format-FileSize $size -HumanReadable)  $Path" }
    else { Write-Output "$size  $Path" }
}
function uptime {
    param([switch]$Help)
    if ($Help) { return 'Usage: uptime' }
    $os = Get-CimInstance Win32_OperatingSystem
    $lastBoot = $os.LastBootUpTime
    $now = Get-Date
    $diff = $now - $lastBoot
    $days = $diff.Days
    $hours = $diff.Hours
    $mins = $diff.Minutes
    $load = (Get-CimInstance Win32_Processor | Measure -Property LoadPercentage -Average).Average
    Write-Output " up $days days, ${hours}:${mins}, load average: ${load}%"
}
function uname {
    param([switch]$a, [switch]$r, [switch]$n, [switch]$Help)
    if ($Help) { return 'Usage: uname [-a] [-r] [-n]' }
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    if ($a) {
        Write-Output "Windows $($os.Caption) $($os.Version) $($os.BuildNumber) $($cpu.Name)"
    } elseif ($r) {
        Write-Output $os.Version
    } elseif ($n) {
        Write-Output $env:COMPUTERNAME
    } else {
        Write-Output "Windows"
    }
}
function hostname {
    param([switch]$Help)
    if ($Help) { return 'Usage: hostname' }
    Write-Output $env:COMPUTERNAME
}
function yolo { codex --yolo @args }
function yoloc { codex --yolo resume --last @args }