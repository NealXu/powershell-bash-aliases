function curl {
    param(
        [switch]$O, [switch]$out, [switch]$I, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($O) { $allArgs += '-O' }
    if ($o) { $allArgs += '-o' }
    if ($I) { $allArgs += '-I' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'remote_name' = @{ Long = 'remote-name'; Short = 'O'; Type = 'switch' }
        'output' = @{ Long = 'output'; Short = 'o'; Type = 'value' }
        'I' = @{ Long = 'head'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: curl [-O] [-o FILE] [-I] [--help] URL'
    }

    $saveRemoteName = $parsed.Options['remote_name'] -or $parsed.LongOptions['remote-name']
    $outputFile = if ($parsed.Options['output']) { $parsed.Options['output'] } else { $parsed.LongOptions['output'] }
    $headOnly = $parsed.Options['I'] -or $parsed.LongOptions['head']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'curl' -Message 'missing URL'
        return
    }

    $url = $parsed.Positional[0]

    if ($headOnly) {
        Invoke-WebRequest $url -Method Head | Select-Object -ExpandProperty Headers
    }
    elseif ($saveRemoteName) {
        Invoke-WebRequest $url -OutFile (Split-Path $url -Leaf)
    }
    elseif ($outputFile) {
        Invoke-WebRequest $url -OutFile $outputFile
    }
    else {
        Invoke-WebRequest $url | Select-Object -ExpandProperty Content
    }
}
function ping {
    param(
        [switch]$c, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($c) { $allArgs += '-c' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'c' = @{ Long = 'count'; Type = 'value'; DefaultValue = 4 }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: ping [-c N] [--help] HOST'
    }

    $count = $parsed.Options['c']
    if (-not $count) { $count = 4 }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'ping' -Message 'missing host'
        return
    }

    $host = $parsed.Positional[0]
    Test-Connection $host -Count ([int]$count) | ForEach-Object {
        Write-Output "Reply from $($_.Address): time=$($_.ResponseTime)ms"
    }
}
function netstat {
    param(
        [switch]$t, [switch]$u, [switch]$n, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($t) { $allArgs += '-t' }
    if ($u) { $allArgs += '-u' }
    if ($n) { $allArgs += '-n' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        't' = @{ Long = 'tcp'; Type = 'switch' }
        'u' = @{ Long = 'udp'; Type = 'switch' }
        'n' = @{ Long = 'numeric'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: netstat [-t] [-u] [-n] [--help]'
    }

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
    param(
        [switch]$O, [switch]$q, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($O) { $allArgs += '-O' }
    if ($q) { $allArgs += '-q' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'O' = @{ Long = 'output-document'; Type = 'value' }
        'q' = @{ Long = 'quiet'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: wget [-O FILE] [-q] [--help] URL'
    }

    $outputFile = $parsed.Options['O']
    $quiet = $parsed.Options['q'] -or $parsed.LongOptions['quiet']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'wget' -Message 'missing URL'
        return
    }

    $url = $parsed.Positional[0]
    $outFile = if ($outputFile) { $outputFile } else { Split-Path $url -Leaf }

    if (-not $quiet) { Write-Output "Downloading $url to $outFile..." }
    try {
        Invoke-WebRequest $url -OutFile $outFile -ErrorAction Stop
        if (-not $quiet) { Write-Output "Done." }
    } catch {
        Write-BashError -Command 'wget' -Message "failed to download $url"
    }
}
