# core-utils.ps1
# Utility commands module

function echo {
    param(
        [switch]$n,
        [switch]$e,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($e) { $allArgs += '-e' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'no-newline'; Type = 'switch' }
        'e' = @{ Long = 'enable-escape'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: echo [-n] [-e] [STRING]...'
    }

    $noNewline = $parsed.Options['n'] -or $parsed.LongOptions['no-newline']
    $enableEscape = $parsed.Options['e'] -or $parsed.LongOptions['enable-escape']

    $output = $parsed.Positional -join ' '

    if ($enableEscape) {
        $output = $output -replace '\\n', "`n" `
                          -replace '\\t', "`t" `
                          -replace '\\\\', '\'
    }

    if ($noNewline) {
        Write-Host $output -NoNewline
    } else {
        Write-Output $output
    }
}

function tee {
    [CmdletBinding()]
    param(
        [switch]$a,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    begin {
        $allArgs = @()
        if ($a) { $allArgs += '-a' }
        $allArgs += $ArgList

        $spec = @{
            'a' = @{ Long = 'append'; Type = 'switch' }
            'help' = @{ Long = 'help'; Type = 'switch' }
        }

        $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

        if ($parsed.Options['help']) {
            return 'Usage: tee [-a] [FILE]...'
        }

        $script:appendMode = $parsed.Options['a'] -or $parsed.LongOptions['append']
        $script:files = $parsed.Positional | ForEach-Object { Convert-BashPath $_ }
        $script:output = @()
    }

    process {
        # Collect all input
        $script:output += $Input
    }

    end {
        if ($script:output.Count -eq 0) {
            return
        }

        # Write to each file
        foreach ($file in $script:files) {
            if ($script:appendMode) {
                $script:output | Add-Content -Path $file -Encoding UTF8
            } else {
                $script:output | Set-Content -Path $file -Encoding UTF8
            }
        }

        # Output to stdout
        $script:output | Write-Output
    }
}

function history {
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
        return 'Usage: history [--help]'
    }

    # Placeholder - will be implemented in later task
    Write-Output "history: placeholder"
}

function time {
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
        return 'Usage: time [--help] COMMAND'
    }

    # Placeholder - will be implemented in later task
    Write-Output "time: placeholder"
}

function watch {
    param(
        [switch]$n,
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'interval'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: watch [-n SECONDS] COMMAND [--help]'
    }

    # Placeholder - will be implemented in later task
    Write-Output "watch: placeholder"
}

function seq {
    param(
        [switch]$s,
        [switch]$w,
        [switch]$f,
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($s) { $allArgs += '-s' }
    if ($w) { $allArgs += '-w' }
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        's' = @{ Long = 'separator'; Type = 'value' }
        'w' = @{ Long = 'equal-width'; Type = 'switch' }
        'f' = @{ Long = 'format'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: seq [-s SEP] [-w] [-f FORMAT] [FIRST [INCR]] LAST [--help]'
    }

    # Placeholder - will be implemented in later task
    Write-Output "seq: placeholder"
}

function yes {
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
        return 'Usage: yes [STRING] [--help]'
    }

    # Placeholder - will be implemented in later task
    Write-Output "yes: placeholder"
}

function rev {
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
        return 'Usage: rev [FILE]... [--help]'
    }

    # Placeholder - will be implemented in later task
    Write-Output "rev: placeholder"
}

function shuf {
    param(
        [switch]$n,
        [switch]$r,
        [switch]$e,
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($r) { $allArgs += '-r' }
    if ($e) { $allArgs += '-e' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'head-count'; Type = 'value' }
        'r' = @{ Long = 'repeat'; Type = 'switch' }
        'e' = @{ Long = 'echo'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: shuf [-n COUNT] [-r] [-e] [FILE]... [--help]'
    }

    # Placeholder - will be implemented in later task
    Write-Output "shuf: placeholder"
}

function xargs {
    param(
        [switch]$n,
        [switch]$r,
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($r) { $allArgs += '-r' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'max-args'; Type = 'value' }
        'r' = @{ Long = 'no-run-if-empty'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: xargs [-n MAX-ARGS] [-r] [COMMAND] [--help]'
    }

    # Placeholder - will be implemented in later task
    Write-Output "xargs: placeholder"
}

function date {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'd' = @{ Long = 'date'; Type = 'value' }
        'u' = @{ Long = 'utc'; Type = 'switch' }
        'R' = @{ Long = 'rfc-2822'; Type = 'switch' }
        'I' = @{ Long = 'iso-8601'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: date [-d DATE] [-u] [-R] [-I] [--help] [+FORMAT]'
    }

    $dateStr = $parsed.Options['d']
    $utc = $parsed.Options['u'] -or $parsed.LongOptions['utc']
    $rfc2822 = $parsed.Options['R'] -or $parsed.LongOptions['rfc-2822']
    $iso8601 = $parsed.Options['I'] -or $parsed.LongOptions['iso-8601']

    # Get date object
    $dateObj = if ($dateStr) {
        try {
            [DateTime]::Parse($dateStr)
        } catch {
            Write-BashError -Command 'date' -Message "invalid date '$dateStr'"
            return
        }
    } else {
        Get-Date
    }

    # Adjust for UTC
    if ($utc) {
        $dateObj = $dateObj.ToUniversalTime()
    }

    # Check for format string
    $format = $parsed.Positional | Where-Object { $_ -match '^\+' } | Select-Object -First 1
    if ($format) {
        $formatStr = $format.Substring(1)
        # Convert bash date format to PowerShell format
        $output = $dateObj.ToString($formatStr)
        Write-Output $output
    } elseif ($rfc2822) {
        # RFC 2822 format: Wed, 02 Oct 2002 13:00:00 -0700
        Write-Output $dateObj.ToString('ddd, dd MMM yyyy HH:mm:ss zzz')
    } elseif ($iso8601) {
        # ISO 8601 format: 2002-10-02T15:00:00Z
        Write-Output $dateObj.ToString('yyyy-MM-ddTHH:mm:ssZ')
    } else {
        # Default format
        Write-Output $dateObj.ToString('ddd MMM dd HH:mm:ss yyyy')
    }
}

function env {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'i' = @{ Long = 'ignore-environment'; Type = 'switch' }
        'u' = @{ Long = 'unset'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: env [-i] [-u NAME] [--help] [NAME=VALUE...] [COMMAND]'
    }

    $ignoreEnv = $parsed.Options['i'] -or $parsed.LongOptions['ignore-environment']
    $unsetVar = $parsed.Options['u']

    # If no arguments, just print environment variables
    if ($parsed.Positional.Count -eq 0 -and -not $ignoreEnv -and -not $unsetVar) {
        # Print all environment variables
        $vars = Get-ChildItem Env: | Sort-Object Name
        foreach ($var in $vars) {
            Write-Output "$($var.Key)=$($var.Value)"
        }
        return
    }

    # Handle environment modifications
    $newEnv = @{}
    if (-not $ignoreEnv) {
        # Copy current environment
        Get-ChildItem Env: | ForEach-Object {
            $newEnv[$_.Key] = $_.Value
        }
    }

    # Unset specified variable
    if ($unsetVar) {
        $newEnv.Remove($unsetVar)
    }

    # Process NAME=VALUE assignments
    $commandIndex = -1
    for ($i = 0; $i -lt $parsed.Positional.Count; $i++) {
        $arg = $parsed.Positional[$i]
        if ($arg -match '^([^=]+)=(.*)$') {
            $name = $matches[1]
            $value = $matches[2]
            $newEnv[$name] = $value
        } else {
            $commandIndex = $i
            break
        }
    }

    # If there's a command to run, run it with the new environment
    if ($commandIndex -ge 0) {
        $command = $parsed.Positional[$commandIndex]
        $commandArgs = $parsed.Positional[($commandIndex + 1)..($parsed.Positional.Count - 1)]

        # Set environment temporarily
        $originalEnv = @{}
        foreach ($key in $newEnv.Keys) {
            $originalEnv[$key] = Get-Item "Env:$key" -ErrorAction SilentlyContinue
            Set-Item "Env:$key" $newEnv[$key]
        }

        try {
            # Use Invoke-Expression to run the command
            $commandStr = $command
            if ($commandArgs.Count -gt 0) {
                $commandStr += " " + ($commandArgs -join " ")
            }
            Invoke-Expression $commandStr
        } finally {
            # Restore original environment
            foreach ($key in $newEnv.Keys) {
                if ($originalEnv[$key]) {
                    Set-Item "Env:$key" $originalEnv[$key].Value
                } else {
                    Remove-Item "Env:$key" -ErrorAction SilentlyContinue
                }
            }
        }
    } else {
        # Just print the modified environment
        $newEnv.GetEnumerator() | Sort-Object Name | ForEach-Object {
            Write-Output "$($_.Key)=$($_.Value)"
        }
    }
}