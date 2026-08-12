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

function free {
    param(
        [switch]$h, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($h) { $allArgs += '-h' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'h' = @{ Long = 'human'; Type = 'switch' }
        'b' = @{ Long = 'bytes'; Type = 'switch' }
        'k' = @{ Long = 'kilo'; Type = 'switch' }
        'm' = @{ Long = 'mega'; Type = 'switch' }
        'g' = @{ Long = 'giga'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: free [-h] [-b|-k|-m|-g] [--help]'
    }

    $humanReadable = $parsed.Options['h'] -or $parsed.LongOptions['human']

    # Get memory information from Windows
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem

    $totalMem = $cs.TotalPhysicalMemory
    $freeMem = $os.FreePhysicalMemory * 1KB  # Convert from KB
    $usedMem = $totalMem - $freeMem

    # Calculate percentages
    $usedPct = [Math]::Round(($usedMem / $totalMem) * 100)
    $freePct = [Math]::Round(($freeMem / $totalMem) * 100)

    # Swap memory (page file)
    $pageFile = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
    $swapTotal = if ($pageFile) { ($pageFile | Measure-Object -Property AllocatedBaseSize -Sum).Sum * 1MB } else { 0 }
    $swapUsed = if ($pageFile) { ($pageFile | Measure-Object -Property CurrentUsage -Sum).Sum * 1MB } else { 0 }
    $swapFree = $swapTotal - $swapUsed

    if ($humanReadable) {
        $totalMem = Format-FileSize $totalMem -HumanReadable
        $usedMem = Format-FileSize $usedMem -HumanReadable
        $freeMem = Format-FileSize $freeMem -HumanReadable
        $swapTotal = Format-FileSize $swapTotal -HumanReadable
        $swapUsed = Format-FileSize $swapUsed -HumanReadable
        $swapFree = Format-FileSize $swapFree -HumanReadable
    }

    # Output in free command format
    Write-Output "              total        used        free      shared  buff/cache   available"
    Write-Output "Mem:      $totalMem  $usedMem  $freeMem      0B           0B  $freeMem"
    Write-Output "Swap:     $swapTotal  $swapUsed  $swapFree"
}

function whoami {
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
        return 'Usage: whoami [--help]'
    }

    # Get current user
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    Write-Output $currentUser.Name
}

function yolo { codex --yolo @args }
function yoloc { codex --yolo resume --last @args }
