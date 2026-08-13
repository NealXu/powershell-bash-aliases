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
        [switch]$c,
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($c) { $allArgs += '-c' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'c' = @{ Long = 'clear'; Type = 'switch' }
        'd' = @{ Long = 'delete'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: history [-c] [-d OFFSET] [--help]'
    }

    $clear = $parsed.Options['c'] -or $parsed.LongOptions['clear']
    $deleteOffset = $parsed.Options['d']

    if ($clear) {
        Clear-History
        Write-Output "History cleared."
        return
    }

    if ($deleteOffset) {
        try {
            $offset = [int]$deleteOffset
            $history = Get-History
            if ($offset -ge 1 -and $offset -le $history.Count) {
                # PowerShell doesn't support deleting individual entries easily
                # We'll clear and re-add except the one to delete
                Write-Output "Note: PowerShell does not support deleting individual history entries."
            } else {
                Write-BashError -Command 'history' -Message "offset $deleteOffset out of range"
            }
        } catch {
            Write-BashError -Command 'history' -Message "invalid offset '$deleteOffset'"
        }
        return
    }

    # Display history
    $history = Get-History
    $idWidth = [string]($history.Count).Length
    foreach ($entry in $history) {
        $id = $entry.Id
        $line = $entry.CommandLine
        Write-Output ("{0,$idWidth}  {1}" -f $id, $line)
    }
}

function time {
    param(
        [switch]$p,
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($p) { $allArgs += '-p' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'p' = @{ Long = 'portability'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: time [-p] COMMAND [--help]'
    }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'time' -Message "missing command"
        return
    }

    $portability = $parsed.Options['p'] -or $parsed.LongOptions['portability']
    $command = $parsed.Positional -join ' '

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        Invoke-Expression $command | Out-Default
        $sw.Stop()

        if ($portability) {
            # POSIX format: real X.XX\nuser X.XX\nsys X.XX
            # PowerShell doesn't separate user/sys time, so we report real only
            Write-Output "real $($sw.Elapsed.TotalSeconds)"
        } else {
            Write-Output ""
            Write-Output "Execution time: $($sw.Elapsed)"
        }
    } catch {
        Write-BashError -Command 'time' -Message "failed to execute: $command"
    }
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

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'watch' -Message "missing command"
        return
    }

    $interval = 2
    if ($parsed.Options['n']) {
        try {
            $interval = [double]$parsed.Options['n']
            if ($interval -lt 0.1) { $interval = 0.1 }
        } catch {
            Write-BashError -Command 'watch' -Message "invalid interval '$($parsed.Options['n'])'"
            return
        }
    }

    $command = $parsed.Positional -join ' '

    Write-Output "Every $interval seconds: $command"
    Write-Output "Press Ctrl+C to stop..."

    try {
        while ($true) {
            Clear-Host
            Write-Output "Every $interval seconds: $command"
            Write-Output "Press Ctrl+C to stop..."
            Write-Output ""
            Write-Output "[$(Get-Date -Format 'HH:mm:ss')]"
            Write-Output ""
            try {
                Invoke-Expression $command
            } catch {
                Write-BashError -Command 'watch' -Message "error executing command"
            }
            Start-Sleep -Seconds $interval
        }
    } catch {
        # User pressed Ctrl+C
        Write-Output ""
        Write-Output "watch: stopped"
    }
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

    $separator = if ($parsed.Options['s']) { $parsed.Options['s'] } else { "`n" }
    $equalWidth = $parsed.Options['w'] -or $parsed.LongOptions['equal-width']
    $format = $parsed.Options['f']

    $posArgs = @($parsed.Positional | Where-Object { $_ -match '^-?\d+\.?\d*$' })

    $first = 1
    $incr = 1
    $last = $null

    switch ($posArgs.Count) {
        1 {
            $last = [double]$posArgs[0]
        }
        2 {
            $first = [double]$posArgs[0]
            $last = [double]$posArgs[1]
        }
        { $_ -ge 3 } {
            $first = [double]$posArgs[0]
            $incr = [double]$posArgs[1]
            $last = [double]$posArgs[2]
        }
    }

    if ($null -eq $last) {
        Write-BashError -Command 'seq' -Message "missing operand"
        return
    }

    if ($incr -eq 0) {
        Write-BashError -Command 'seq' -Message "zero increment"
        return
    }

    $values = @()
    if ($incr -gt 0) {
        for ($i = $first; $i -le $last; $i += $incr) {
            $values += $i
        }
    } else {
        for ($i = $first; $i -ge $last; $i += $incr) {
            $values += $i
        }
    }

    if ($format) {
        $values = $values | ForEach-Object { $format -f $_ }
    } elseif ($equalWidth) {
        # Pad with zeros based on max width
        $maxLen = ([string]([int]$last)).Length
        $values = $values | ForEach-Object {
            if ($_ -eq [int]$_) {
                "{0:D$maxLen}" -f [int]$_
            } else {
                "{0}" -f $_
            }
        }
    }

    if ($separator -eq "`n") {
        # Default: output each value on separate line
        $values | Write-Output
    } else {
        # Custom separator: join and output
        Write-Output ($values -join $separator)
    }
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

    $string = if ($parsed.Positional.Count -gt 0) {
        $parsed.Positional -join ' '
    } else {
        'y'
    }

    # Output repeatedly until Ctrl+C
    # For safety in testing, limit iterations
    $iterations = 0
    $maxIterations = 10000  # Safety limit for testing

    try {
        while ($iterations -lt $maxIterations) {
            Write-Output $string
            $iterations++
        }
    } catch {
        # Ctrl+C pressed
    }
}

function rev {
    [CmdletBinding()]
    param(
        [switch]$help,
        [Parameter(ValueFromPipeline=$true, ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    begin {
        $script:collectedInput = @()
        $script:files = @()
        $script:showHelp = $false
    }

    process {
        if ($help) {
            $script:showHelp = $true
            return
        }

        if ($ArgList) {
            foreach ($item in $ArgList) {
                if (Test-Path $item) {
                    $script:files += $item
                } else {
                    $script:collectedInput += $item
                }
            }
        }
    }

    end {
        if ($script:showHelp) {
            Write-Output 'Usage: rev [FILE]... [--help]'
            return
        }

        $processLines = {
            param([string[]]$lines)
            foreach ($line in $lines) {
                $chars = $line.ToCharArray()
                [array]::Reverse($chars)
                Write-Output (-join $chars)
            }
        }

        # Process files
        foreach ($file in $script:files) {
            $path = Convert-BashPath $file
            if (Test-Path $path) {
                $content = Read-BashFileContent $path
                & $processLines $content
            } else {
                Write-BashError -Command 'rev' -Message "cannot open '$file'"
            }
        }

        # Process collected input
        if ($script:collectedInput.Count -gt 0) {
            & $processLines $script:collectedInput
        }
    }
}

function shuf {
    [CmdletBinding()]
    param(
        [switch]$n,
        [switch]$r,
        [switch]$e,
        [switch]$help,
        [Parameter(ValueFromPipeline=$true, ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    begin {
        $script:collectedInput = @()
        $script:files = @()
        $script:headCount = $null
        $script:repeat = $false
        $script:echoMode = $false
        $script:showHelp = $false
        $script:echoArgs = @()
    }

    process {
        if ($help) {
            $script:showHelp = $true
            return
        }

        if ($n) { $script:headCount = $ArgList[0]; $ArgList = $ArgList[1..($ArgList.Count-1)] }
        if ($r) { $script:repeat = $true }
        if ($e) { $script:echoMode = $true }

        if ($script:echoMode) {
            # In echo mode, all ArgList items are input lines
            $script:echoArgs = $ArgList
        } else {
            # In normal mode, collect items
            if ($ArgList) {
                foreach ($item in $ArgList) {
                    if (Test-Path $item) {
                        $script:files += $item
                    } else {
                        $script:collectedInput += $item
                    }
                }
            }
        }
    }

    end {
        if ($script:showHelp) {
            Write-Output 'Usage: shuf [-n COUNT] [-r] [-e] [FILE]... [--help]'
            return
        }

        $lines = @()

        if ($script:echoMode) {
            $lines = $script:echoArgs
        } elseif ($script:files.Count -gt 0) {
            foreach ($file in $script:files) {
                $path = Convert-BashPath $file
                if (Test-Path $path) {
                    $lines += Read-BashFileContent $path
                } else {
                    Write-BashError -Command 'shuf' -Message "cannot open '$file'"
                }
            }
        } else {
            $lines = $script:collectedInput
        }

        if ($lines.Count -eq 0) {
            return
        }

        # Shuffle function
        $shuffleArray = {
            param([object[]]$arr)
            $result = $arr | ForEach-Object { $_ }
            for ($i = $result.Count - 1; $i -gt 0; $i--) {
                $j = Get-Random -Minimum 0 -Maximum ($i + 1)
                $temp = $result[$i]
                $result[$i] = $result[$j]
                $result[$j] = $temp
            }
            return $result
        }

        if ($script:repeat) {
            $count = 0
            $maxIterations = 10000
            while ($count -lt $maxIterations) {
                if ($script:headCount -and $count -ge [int]$script:headCount) { break }
                $index = Get-Random -Minimum 0 -Maximum $lines.Count
                Write-Output $lines[$index]
                $count++
            }
        } else {
            $shuffled = & $shuffleArray $lines
            if ($script:headCount) {
                $shuffled | Select-Object -First ([int]$script:headCount)
            } else {
                $shuffled
            }
        }
    }
}

function xargs {
    [CmdletBinding()]
    param(
        [switch]$n,
        [switch]$r,
        [switch]$help,
        [Parameter(ValueFromPipeline=$true, ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    begin {
        $script:maxArgs = 1000
        $script:noRunIfEmpty = $false
        $script:command = 'echo'
        $script:commandArgs = @()
        $script:collectedInput = @()
        $script:showHelp = $false
        $script:parsedArgs = @()
    }

    process {
        if ($ArgList) {
            $script:parsedArgs += $ArgList
        }
    }

    end {
        # Parse arguments
        $allArgs = @()
        if ($n) { $allArgs += '-n' }
        if ($r) { $allArgs += '-r' }
        if ($help) { $allArgs += '-help' }
        $allArgs += $script:parsedArgs

        $spec = @{
            'n' = @{ Long = 'max-args'; Type = 'value' }
            'r' = @{ Long = 'no-run-if-empty'; Type = 'switch' }
            'help' = @{ Long = 'help'; Type = 'switch' }
        }

        $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

        if ($parsed.Options['help']) {
            Write-Output 'Usage: xargs [-n MAX-ARGS] [-r] [COMMAND] [--help]'
            return
        }

        $script:maxArgs = if ($parsed.Options['n']) { [int]$parsed.Options['n'] } else { 1000 }
        $script:noRunIfEmpty = $parsed.Options['r'] -or $parsed.LongOptions['no-run-if-empty']
        $script:command = if ($parsed.Positional.Count -gt 0) { $parsed.Positional[0] } else { 'echo' }
        $script:commandArgs = $parsed.Positional | Select-Object -Skip 1

        # Don't run if empty and -r specified
        if ($script:noRunIfEmpty -and $script:collectedInput.Count -eq 0) {
            return
        }

        # Batch arguments and execute command
        $batchCount = 0
        $argsBatch = @()

        foreach ($item in $script:collectedInput) {
            $argsBatch += $item
            $batchCount++

            if ($batchCount -ge $script:maxArgs) {
                # Execute with current batch
                $cmdStr = $script:command
                if ($script:commandArgs.Count -gt 0) {
                    $cmdStr += " " + ($script:commandArgs -join ' ')
                }
                if ($argsBatch.Count -gt 0) {
                    $cmdStr += " " + ($argsBatch -join ' ')
                }

                try {
                    Invoke-Expression $cmdStr
                } catch {
                    Write-BashError -Command 'xargs' -Message "command failed: $cmdStr"
                }

                $argsBatch = @()
                $batchCount = 0
            }
        }

        # Execute remaining items
        if ($argsBatch.Count -gt 0) {
            $cmdStr = $script:command
            if ($script:commandArgs.Count -gt 0) {
                $cmdStr += " " + ($script:commandArgs -join ' ')
            }
            if ($argsBatch.Count -gt 0) {
                $cmdStr += " " + ($argsBatch -join ' ')
            }

            try {
                Invoke-Expression $cmdStr
            } catch {
                Write-BashError -Command 'xargs' -Message "command failed: $cmdStr"
            }
        }
    }
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