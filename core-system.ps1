function df {
    param(
        [switch]$h, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($h) { $allArgs += '-h' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'h' = @{ Long = 'human-readable'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: df [-h] [--help]'
    }

    $humanReadable = $parsed.Options['h'] -or $parsed.LongOptions['human-readable']

    $drives = Get-PSDrive -PSProvider FileSystem
    foreach ($d in $drives) {
        $used = $d.Used
        $free = $d.Free
        $total = $used + $free
        $pct = if ($total -gt 0) { [Math]::Round($used / $total * 100) } else { 0 }
        if ($humanReadable) {
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
    param(
        [switch]$h, [switch]$s, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($h) { $allArgs += '-h' }
    if ($s) { $allArgs += '-s' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'h' = @{ Long = 'human-readable'; Type = 'switch' }
        's' = @{ Long = 'summarize'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: du [-h] [-s] [PATH] [--help]'
    }

    $humanReadable = $parsed.Options['h'] -or $parsed.LongOptions['human-readable']

    $paths = $parsed.Positional
    if ($paths.Count -eq 0) { $paths = @('.') }

    foreach ($Path in $paths) {
        $p = Convert-BashPath $Path
        $item = Get-Item $p
        if ($item -is [System.IO.DirectoryInfo]) {
            $size = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure -Property Length -Sum).Sum
        } else {
            $size = $item.Length
        }
        if ($humanReadable) { Write-Output "$(Format-FileSize $size -HumanReadable)  $Path" }
        else { Write-Output "$size  $Path" }
    }
}

function uptime {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: uptime [--help]'
    }

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
    param(
        [switch]$a, [switch]$r, [switch]$n, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($a) { $allArgs += '-a' }
    if ($r) { $allArgs += '-r' }
    if ($n) { $allArgs += '-n' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'a' = @{ Long = 'all'; Type = 'switch' }
        'r' = @{ Long = 'kernel-release'; Type = 'switch' }
        'n' = @{ Long = 'nodename'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: uname [-a] [-r] [-n] [--help]'
    }

    $showAll = $parsed.Options['a'] -or $parsed.LongOptions['all']
    $showRelease = $parsed.Options['r'] -or $parsed.LongOptions['kernel-release']
    $showNode = $parsed.Options['n'] -or $parsed.LongOptions['nodename']

    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor
    if ($showAll) {
        Write-Output "Windows $($os.Caption) $($os.Version) $($os.BuildNumber) $($cpu.Name)"
    } elseif ($showRelease) {
        Write-Output $os.Version
    } elseif ($showNode) {
        Write-Output $env:COMPUTERNAME
    } else {
        Write-Output "Windows"
    }
}

function hostname {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: hostname [--help]'
    }

    Write-Output $env:COMPUTERNAME
}

function yolo { codex --yolo @args }
function yoloc { codex --yolo resume --last @args }
