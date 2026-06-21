function ps {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'e' = @{ Long = 'everyone'; Type = 'switch' }
        'f' = @{ Long = 'full'; Type = 'switch' }
        'u' = @{ Long = 'user'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

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
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'l' = @{ Long = 'list'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

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
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

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
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value'; DefaultValue = 10 }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: top [-n N] [--help]'
    }

    $lines = $parsed.Options['n']
    if (-not $lines) { $lines = 10 }

    $procs = Get-Process | Sort-Object WorkingSet -Descending | Select-Object -First ([int]$lines)
    Write-Output "PID    ProcessName       CPU    Memory"
    foreach ($p in $procs) {
        $mem = Format-FileSize $p.WorkingSet -HumanReadable
        Write-Output "$($p.Id.ToString().PadLeft(6)) $($p.ProcessName.PadRight(16)) $($p.CPU.ToString('N1').PadLeft(6))  $mem"
    }
}
