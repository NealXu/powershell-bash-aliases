function ps {
    param(
        [switch]$e, [switch]$f, [switch]$u, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($e) { $allArgs += '-e' }
    if ($f) { $allArgs += '-f' }
    if ($u) { $allArgs += '-u' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'e' = @{ Long = 'everyone'; Type = 'switch' }
        'f' = @{ Long = 'full'; Type = 'switch' }
        'u' = @{ Long = 'user'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: ps [-e] [-f] [-u USER] [--help]'
    }

    $showAll = $parsed.Options['e'] -or $parsed.LongOptions['everyone']
    $fullFormat = $parsed.Options['f'] -or $parsed.LongOptions['full']
    $userFilter = $parsed.Options['u']

    $procs = Get-Process
    if ($userFilter) { $procs = $procs | Where-Object { $_.UserName -like "*$userFilter*" } }

    if ($showAll) { $procs }
    else { $procs | Select-Object -First 10 }

    if ($fullFormat) {
        $procs | Format-Table Id, ProcessName, CPU, WorkingSet -AutoSize
    } else {
        $procs | Select-Object Id, ProcessName
    }
}
function kill {
    param(
        [switch]$l, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($l) { $allArgs += '-l' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'l' = @{ Long = 'list'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: kill [-l] [--help] PID|NAME'
    }

    $listSignals = $parsed.Options['l'] -or $parsed.LongOptions['list']

    if ($listSignals) {
        Write-Output 'Signals: 9=Kill, 15=Term'
        return
    }

    foreach ($target in $parsed.Positional) {
        if ($target -match '^\d+$') {
            Stop-Process -Id ([int]$target) -Force
        } else {
            Stop-Process -Name $target -Force
        }
    }
}
function killall {
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
        return 'Usage: killall [--help] NAME'
    }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'killall' -Message 'missing process name'
        return
    }

    $name = $parsed.Positional[0]
    Stop-Process -Name $name -Force -ErrorAction SilentlyContinue
}
function top {
    param(
        [switch]$n, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value'; DefaultValue = 10 }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: top [-n N] [--help]'
    }

    $lines = $parsed.Options['n']
    if (-not $lines) { $lines = 10 }

    $procs = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First ([int]$lines)
    Write-Output "PID    ProcessName       CPU    Memory"
    foreach ($p in $procs) {
        $mem = Format-FileSize $p.WorkingSet -HumanReadable
        $cpu = if ($p.CPU) { $p.CPU.ToString('N1') } else { '0.0' }
        Write-Output "$($p.Id.ToString().PadLeft(6)) $($p.ProcessName.PadRight(16)) $($cpu.PadLeft(6))  $mem"
    }
}

# Global job tracking
$script:JobTable = @{}

function jobs {
    param(
        [switch]$l, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($l) { $allArgs += '-l' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'l' = @{ Long = 'list'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: jobs [-l] [--help]'
    }

    $listPids = $parsed.Options['l'] -or $parsed.LongOptions['list']

    # Clean up completed jobs
    $activeJobs = @{}
    foreach ($key in $script:JobTable.Keys) {
        $job = $script:JobTable[$key]
        if ($job.PSObject.Properties['State'] -and $job.State -eq 'Completed') {
            # Job completed, remove from table
            continue
        }
        $activeJobs[$key] = $job
    }
    $script:JobTable = $activeJobs

    if ($script:JobTable.Count -eq 0) {
        Write-Output 'No background jobs'
        return
    }

    $idx = 1
    foreach ($key in $script:JobTable.Keys) {
        $job = $script:JobTable[$key]
        $status = if ($job.State) { $job.State } else { 'Running' }
        $command = if ($job.Command) { $job.Command } elseif ($job.Name) { $job.Name } else { 'Unknown' }

        if ($listPids) {
            $pid = if ($job.Id) { $job.Id } else { 'N/A' }
            Write-Output "[$idx]  PID $pid  $status  $command"
        } else {
            Write-Output "[$idx]  $status  $command"
        }
        $idx++
    }
}

function bg {
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
        return 'Usage: bg [JOB_ID] [--help]'
    }

    # PowerShell jobs don't have true background/foreground like Unix
    # This is a simplified implementation

    if ($parsed.Positional.Count -eq 0) {
        # Resume most recent stopped job
        if ($script:JobTable.Count -eq 0) {
            Write-BashError -Command 'bg' -Message 'no current job'
            return
        }
        $jobKey = $script:JobTable.Keys | Select-Object -Last 1
        $job = $script:JobTable[$jobKey]
    } else {
        $jobId = $parsed.Positional[0]
        if ($jobId -match '^\d+$') {
            $idx = [int]$jobId
            $keys = @($script:JobTable.Keys)
            if ($idx -lt 1 -or $idx -gt $keys.Count) {
                Write-BashError -Command 'bg' -Message "job $jobId not found"
                return
            }
            $jobKey = $keys[$idx - 1]
            $job = $script:JobTable[$jobKey]
        } else {
            Write-BashError -Command 'bg' -Message "invalid job ID: $jobId"
            return
        }
    }

    # Resume job in background
    if ($job -and $job.PSObject.Properties['State']) {
        Receive-Job -Job $job -ErrorAction SilentlyContinue
        Write-Output "Background job resumed"
    } else {
        Write-BashError -Command 'bg' -Message 'job not found'
    }
}

function fg {
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
        return 'Usage: fg [JOB_ID] [--help]'
    }

    if ($parsed.Positional.Count -eq 0) {
        # Bring most recent job to foreground
        if ($script:JobTable.Count -eq 0) {
            Write-BashError -Command 'fg' -Message 'no current job'
            return
        }
        $jobKey = $script:JobTable.Keys | Select-Object -Last 1
        $job = $script:JobTable[$jobKey]
    } else {
        $jobId = $parsed.Positional[0]
        if ($jobId -match '^\d+$') {
            $idx = [int]$jobId
            $keys = @($script:JobTable.Keys)
            if ($idx -lt 1 -or $idx -gt $keys.Count) {
                Write-BashError -Command 'fg' -Message "job $jobId not found"
                return
            }
            $jobKey = $keys[$idx - 1]
            $job = $script:JobTable[$jobKey]
        } else {
            Write-BashError -Command 'fg' -Message "invalid job ID: $jobId"
            return
        }
    }

    # Bring job to foreground and wait for it
    if ($job -and $job.PSObject.Properties['State']) {
        Write-Output "Bringing job to foreground..."
        Wait-Job -Job $job -Timeout -1 -ErrorAction SilentlyContinue
        Receive-Job -Job $job -ErrorAction SilentlyContinue
        Remove-Job -Job $job -ErrorAction SilentlyContinue
        $script:JobTable.Remove($jobKey)
    } else {
        Write-BashError -Command 'fg' -Message 'job not found'
    }
}

function nohup {
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
        return 'Usage: nohup COMMAND [ARGS]... [--help]'
    }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'nohup' -Message 'missing command'
        return
    }

    $command = $parsed.Positional[0]
    $arguments = $parsed.Positional[1..($parsed.Positional.Count - 1)]

    # Create output file (path captured at call time; the child writes to it
    # directly, so it is immune to a later cd).
    $nohupOut = Join-Path $PWD 'nohup.out'

    # Start the command as a PowerShell background job. The child redirects ALL of
    # its output straight into nohup.out (*>>) so nothing is left waiting in the
    # job's output buffer. NOTE: the scriptblock parameters must not be named
    # $args -- declaring a parameter named $args shadows the automatic variable
    # and wedges the job in 'Blocked', from which Receive-Job cannot recover.
    $scriptBlock = {
        param($cmd, $arguments, $outFile)
        & $cmd @arguments *>> $outFile
    }

    try {
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $command, $arguments, $nohupOut

        # Track job in our table
        $jobInfo = @{
            Job = $job
            Command = "$command $arguments"
            StartTime = Get-Date
        }
        $script:JobTable[$job.Id] = $jobInfo

        Write-Output "Started background job: $command"
        Write-Output "Job ID: $($job.Id)"
        Write-Output "Output appended to: $nohupOut"

        # Clean up the job and its table entry once it reaches a terminal state.
        Register-ObjectEvent -InputObject $job -EventName StateChanged -MessageData @{ Job = $job; Table = $script:JobTable } -Action {
            $data = $Event.MessageData
            $job = $data.Job
            if ($job.State -in @('Completed', 'Failed', 'Stopped')) {
                Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
                $data.Table.Remove($job.Id)
            }
        } | Out-Null

    } catch {
        Write-BashError -Command 'nohup' -Message $_.Exception.Message
    }
}

function pgrep {
    param(
        [switch]$l, [switch]$u, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($l) { $allArgs += '-l' }
    if ($u) { $allArgs += '-u' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'l' = @{ Long = 'list-name'; Type = 'switch' }
        'u' = @{ Long = 'user'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: pgrep [-l] [-u USER] PATTERN [--help]'
    }

    $showName = $parsed.Options['l'] -or $parsed.LongOptions['list-name']
    $userFilter = $parsed.Options['u']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'pgrep' -Message 'missing pattern'
        return
    }

    $pattern = $parsed.Positional[0]

    $procs = Get-Process | Where-Object { $_.ProcessName -like "*$pattern*" }

    if ($userFilter) {
        $procs = $procs | Where-Object { $_.UserName -like "*$userFilter*" }
    }

    foreach ($proc in $procs) {
        if ($showName) {
            Write-Output "$($proc.Id) $($proc.ProcessName)"
        } else {
            Write-Output $proc.Id
        }
    }
}

function pkill {
    param(
        [switch]$u, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($u) { $allArgs += '-u' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'u' = @{ Long = 'user'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: pkill [-u USER] PATTERN [--help]'
    }

    $userFilter = $parsed.Options['u']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'pkill' -Message 'missing pattern'
        return
    }

    $pattern = $parsed.Positional[0]

    $procs = Get-Process | Where-Object { $_.ProcessName -like "*$pattern*" }

    if ($userFilter) {
        $procs = $procs | Where-Object { $_.UserName -like "*$userFilter*" }
    }

    foreach ($proc in $procs) {
        try {
            Stop-Process -Id $proc.Id -Force
        } catch {
            Write-BashError -Command 'pkill' -Message "cannot kill process $($proc.Id)"
        }
    }
}
