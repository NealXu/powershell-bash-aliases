function ps {
    param([switch]$e, [switch]$f, [string]$u, [switch]$Help)
    if ($Help) { return 'Usage: ps [-e] [-f] [-u USER]' }
    $procs = Get-Process
    if ($u) { $procs = $procs | Where { $_.UserName -like "*$u*" } }
    if ($e) { $procs }
    else { $procs | Select -First 10 }
    if ($f) { $procs | Format-Table Id, ProcessName, CPU, WorkingSet -AutoSize }
    else { $procs | Select Id, ProcessName }
}
function kill {
    param([int[]]$Id, [string]$Name, [switch]$l, [switch]$Help)
    if ($Help) { return 'Usage: kill [-l] PID|NAME' }
    if ($l) { Write-Output 'Signals: 9=Kill, 15=Term'; return }
    if ($Id) { Stop-Process -Id $Id -Force }
    if ($Name) { Stop-Process -Name $Name -Force }
}
function killall {
    param([string]$Name, [switch]$Help)
    if ($Help) { return 'Usage: killall NAME' }
    if ($Name) { Stop-Process -Name $Name -Force -ErrorAction SilentlyContinue }
}
function top {
    param([int]$n=10, [switch]$Help)
    if ($Help) { return 'Usage: top [-n N]' }
    $procs = Get-Process | Sort WorkingSet -Descending | Select -First $n
    Write-Output "PID    ProcessName       CPU    Memory"
    foreach ($p in $procs) {
        $mem = Format-FileSize $p.WorkingSet -HumanReadable
        Write-Output "$($p.Id.ToString().PadLeft(6)) $($p.ProcessName.PadRight(16)) $($p.CPU.ToString('N1').PadLeft(6))  $mem"
    }
}
