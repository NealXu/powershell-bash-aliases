function curl {
    param([string]$Url, [switch]$O, [string]$OutputFile, [switch]$I, [switch]$Help)
    if ($Help) { return 'Usage: curl [-O] [-o FILE] [-I] URL' }
    if ($I) { Invoke-WebRequest $Url -Method Head | Select -Expand Headers }
    elseif ($O) { Invoke-WebRequest $Url -OutFile (Split-Path $Url -Leaf) }
    elseif ($OutputFile) { Invoke-WebRequest $Url -OutFile $OutputFile }
    else { Invoke-WebRequest $Url | Select -Expand Content }
}
function ping {
    param([string]$Host, [int]$c=4, [switch]$Help)
    if ($Help) { return 'Usage: ping [-c N] HOST' }
    Test-Connection $Host -Count $c | ForEach { Write-Output ('Reply from ' + $_.Address + ': time=' + $_.ResponseTime + 'ms') }
}
function netstat {
    param([switch]$t, [switch]$u, [switch]$n, [switch]$Help)
    if ($Help) { return 'Usage: netstat [-t] [-u] [-n]' }
    $conns = Get-NetTCPConnection -ErrorAction SilentlyContinue
    if (-not $conns) {
        netstat.exe
        return
    }
    foreach ($c in $conns) {
        $proto = 'tcp'
        $local = "$($c.LocalAddress):$($c.LocalPort)"
        $remote = if ($c.RemoteAddress) { "$($c.RemoteAddress):$($c.RemotePort)" } else { '*:*' }
        $state = $c.State
        Write-Output "$proto  $local  $remote  $state"
    }
}
function wget {
    param([string]$Url, [string]$O, [switch]$q, [switch]$Help)
    if ($Help) { return 'Usage: wget [-o FILE] [-q] URL' }
    $outFile = if ($O) { $O } else { Split-Path $Url -Leaf }
    if (-not $q) { Write-Output "Downloading $Url to $outFile..." }
    try {
        Invoke-WebRequest $Url -OutFile $outFile -ErrorAction Stop
        if (-not $q) { Write-Output "Done." }
    } catch {
        Write-Error "wget: failed to download $Url"
    }
}
