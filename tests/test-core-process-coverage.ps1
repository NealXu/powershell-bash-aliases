# tests\test-core-process-coverage.ps1
# Pester 3.4.0, Windows PowerShell 5.1
# Exercises uncovered branches in core-process.ps1:
#   jobs, bg, fg, pkill, top, nohup, pgrep
# ASCII-only: no non-ASCII literals (Chinese text via codepoints is not used).

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Force remove conflicting aliases BEFORE importing the module
Remove-Item "Global:Alias:ps" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:kill" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:top" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:pgrep" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:pkill" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:jobs" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:bg" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:fg" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:nohup" -Force -ErrorAction SilentlyContinue

Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Function references to bypass PowerShell alias priority
$script:jobsFunc = Get-Command jobs -CommandType Function -ErrorAction SilentlyContinue
$script:bgFunc = Get-Command bg -CommandType Function -ErrorAction SilentlyContinue
$script:fgFunc = Get-Command fg -CommandType Function -ErrorAction SilentlyContinue
$script:pkillFunc = Get-Command pkill -CommandType Function -ErrorAction SilentlyContinue
$script:topFunc = Get-Command top -CommandType Function -ErrorAction SilentlyContinue
$script:nohupFunc = Get-Command nohup -CommandType Function -ErrorAction SilentlyContinue
$script:pgrepFunc = Get-Command pgrep -CommandType Function -ErrorAction SilentlyContinue

$script:module = Get-Module bash-aliases

# Helper: replace the module-scoped job table with the given table
function Set-JobTable {
    param([hashtable]$Table)
    & $script:module { param($t) $script:JobTable = $t } $Table
}

# Helper: empty the module-scoped job table
function Reset-JobTable {
    & $script:module { $script:JobTable = @{} }
}

Describe "jobs" {
    BeforeEach { Reset-JobTable }

    It "Shows help usage" {
        $result = & $script:jobsFunc --help
        @($result)[0] -match 'Usage: jobs' | Should Be $true
    }

    It "Reports no background jobs when the table is empty" {
        $result = @(& $script:jobsFunc)
        ($result -join "`n") -match 'No background jobs' | Should Be $true
    }

    It "Lists a running job with its command" {
        Set-JobTable @{ 'j1' = @{ State = 'Running'; Command = 'sleep 30'; Id = 100 } }
        $result = @(& $script:jobsFunc)
        ($result -join "`n") -match 'Running  sleep 30' | Should Be $true
    }

    It "Lists the PID with dash l" {
        Set-JobTable @{ 'j1' = @{ State = 'Running'; Command = 'sleep 30'; Id = 100 } }
        $result = @(& $script:jobsFunc -l)
        ($result -join "`n") -match 'PID 100  Running  sleep 30' | Should Be $true
    }

    It "Falls back to Running status when State is missing" {
        Set-JobTable @{ 'j1' = @{ Command = 'foo'; Id = 1 } }
        $result = @(& $script:jobsFunc)
        ($result -join "`n") -match 'Running  foo' | Should Be $true
    }

    It "Falls back to the job Name when Command is missing" {
        Set-JobTable @{ 'j1' = @{ State = 'Stopped'; Name = 'myname'; Id = 2 } }
        $result = @(& $script:jobsFunc)
        ($result -join "`n") -match 'Stopped  myname' | Should Be $true
    }

    It "Uses Unknown when neither Command nor Name is present" {
        Set-JobTable @{ 'j1' = @{ State = 'Running'; Id = 3 } }
        $result = @(& $script:jobsFunc)
        ($result -join "`n") -match 'Running  Unknown' | Should Be $true
    }

    It "Shows N/A when the job has no Id" {
        Set-JobTable @{ 'j1' = @{ State = 'Running'; Command = 'foo' } }
        $result = @(& $script:jobsFunc -l)
        ($result -join "`n") -match 'PID N/A  Running  foo' | Should Be $true
    }

    It "Removes completed jobs from the table" {
        $job = Start-Job -ScriptBlock { 'done' }
        Wait-Job -Job $job -Timeout 5 | Out-Null
        Set-JobTable @{ 'x' = $job }
        $result = @(& $script:jobsFunc)
        ($result -join "`n") -match 'No background jobs' | Should Be $true
        (& $script:module { $script:JobTable.Count }) | Should Be 0
    }
}

Describe "bg" {
    BeforeEach { Reset-JobTable }

    It "Shows help usage" {
        $result = & $script:bgFunc --help
        @($result)[0] -match 'Usage: bg' | Should Be $true
    }

    It "Errors when there is no current job" {
        $result = @(& $script:bgFunc -ArgList @() 2>&1)
        $result[0].ToString() -match 'no current job' | Should Be $true
    }

    It "Errors when the job id is out of range" {
        $result = @(& $script:bgFunc 5 2>&1)
        $result[0].ToString() -match 'job 5 not found' | Should Be $true
    }

    It "Errors when the job id is zero" {
        $result = @(& $script:bgFunc 0 2>&1)
        $result[0].ToString() -match 'job 0 not found' | Should Be $true
    }

    It "Errors on a non-numeric job id" {
        $result = @(& $script:bgFunc abc 2>&1)
        $result[0].ToString() -match 'invalid job ID: abc' | Should Be $true
    }

    It "Resumes an existing job without throwing" {
        $job = Start-Job -ScriptBlock { Start-Sleep -Seconds 30 }
        Set-JobTable @{ 'j1' = $job }
        # bg must not throw. Receive-Job without -Wait on a running job returns
        # the output available so far (none) and does not error.
        { & $script:bgFunc 1 } | Should Not Throw
        (& $script:module { $script:JobTable.Count }) | Should Be 1
    }

    It "Resumes the most recent job when no id is given" {
        $job = Start-Job -ScriptBlock { Start-Sleep -Seconds 30 }
        Set-JobTable @{ 'j1' = $job }
        # -ArgList @() is required: invoking a Get-Command function reference with
        # no arguments on PowerShell 5.1 binds a phantom empty string into the
        # ValueFromRemainingArguments param, which would hit the "invalid job ID"
        # branch instead of the most-recent-job path.
        { & $script:bgFunc -ArgList @() } | Should Not Throw
        (& $script:module { $script:JobTable.Count }) | Should Be 1
    }

    It "Reports job not found when the job has no State property" {
        Set-JobTable @{ 'j1' = @{ Id = 99 } }
        $result = @(& $script:bgFunc 1 2>&1)
        $result[0].ToString() -match 'job not found' | Should Be $true
    }
}

Describe "fg" {
    BeforeEach { Reset-JobTable }

    It "Shows help usage" {
        $result = & $script:fgFunc --help
        @($result)[0] -match 'Usage: fg' | Should Be $true
    }

    It "Errors when there is no current job" {
        $result = @(& $script:fgFunc -ArgList @() 2>&1)
        $result[0].ToString() -match 'no current job' | Should Be $true
    }

    It "Errors when the job id is out of range" {
        $result = @(& $script:fgFunc 5 2>&1)
        $result[0].ToString() -match 'job 5 not found' | Should Be $true
    }

    It "Errors on a non-numeric job id" {
        $result = @(& $script:fgFunc xyz 2>&1)
        $result[0].ToString() -match 'invalid job ID: xyz' | Should Be $true
    }

    It "Brings a job to the foreground and removes it" {
        $job = Start-Job -ScriptBlock { Start-Sleep -Milliseconds 300; Write-Output 'fg-done' }
        Set-JobTable @{ 'j1' = $job }
        $result = @(& $script:fgFunc 1 2>&1)
        ($result -join "`n") -match 'Bringing job to foreground' | Should Be $true
        (& $script:module { $script:JobTable.Count }) | Should Be 0
    }

    It "Brings the most recent job to the foreground when no id is given" {
        $job = Start-Job -ScriptBlock { Start-Sleep -Milliseconds 300; Write-Output 'fg-done' }
        Set-JobTable @{ 'j1' = $job }
        # -ArgList @() required: see the bg "most recent job" test for the
        # PowerShell 5.1 phantom empty-argument quirk explanation.
        $result = @(& $script:fgFunc -ArgList @() 2>&1)
        ($result -join "`n") -match 'Bringing job to foreground' | Should Be $true
        (& $script:module { $script:JobTable.Count }) | Should Be 0
    }

    It "Reports job not found when the job has no State property" {
        Set-JobTable @{ 'j1' = @{ Id = 99 } }
        $result = @(& $script:fgFunc 1 2>&1)
        $result[0].ToString() -match 'job not found' | Should Be $true
    }
}

Describe "top" {
    It "Shows help usage" {
        $result = & $script:topFunc --help
        @($result)[0] -match 'Usage: top' | Should Be $true
    }

    It "Limits output to N process lines with dash n" {
        $result = InModuleScope bash-aliases {
            Mock Get-Process {
                $procs = @()
                for ($i = 1; $i -le 12; $i++) {
                    $procs += New-Object PSCustomObject -Property @{
                        Id = $i * 100
                        ProcessName = "proc$i"
                        CPU = [double]($i * 1.5)
                        WorkingSet = [long]($i * 1024)
                    }
                }
                return $procs
            }
            @(top -n 3 2>$null)
        }
        $result.Count | Should Be 4
        $result[0] -match '^PID' | Should Be $true
        ($result -join "`n") -match 'proc12' | Should Be $true
    }

    It "Uses the default of 10 lines" {
        $result = InModuleScope bash-aliases {
            Mock Get-Process {
                $procs = @()
                for ($i = 1; $i -le 12; $i++) {
                    $procs += New-Object PSCustomObject -Property @{
                        Id = $i * 100
                        ProcessName = "proc$i"
                        CPU = [double]($i * 1.5)
                        WorkingSet = [long]($i * 1024)
                    }
                }
                return $procs
            }
            @(top 2>$null)
        }
        $result.Count | Should Be 11
        $result[0] -match '^PID' | Should Be $true
    }

    It "Honors dash n smaller than the default" {
        $result = InModuleScope bash-aliases {
            Mock Get-Process {
                $procs = @()
                for ($i = 1; $i -le 12; $i++) {
                    $procs += New-Object PSCustomObject -Property @{
                        Id = $i * 100
                        ProcessName = "proc$i"
                        CPU = [double]($i * 1.5)
                        WorkingSet = [long]($i * 1024)
                    }
                }
                return $procs
            }
            @(top -n 5 2>$null)
        }
        $result.Count | Should Be 6
    }

    It "Handles a process with null CPU without throwing" {
        # Some processes (e.g. Memory Compression) report a $null CPU; top must
        # not crash calling .ToString('N1') on it and should render 0.0 instead.
        $result = InModuleScope bash-aliases {
            Mock Get-Process {
                @([pscustomobject]@{
                    Id = 999
                    ProcessName = 'MemoryCompression'
                    CPU = $null
                    WorkingSet = [long]1024
                })
            }
            @(top -n 1 2>$null)
        }
        $result.Count | Should Be 2
        $result[0] -match '^PID' | Should Be $true
        ($result -join "`n") -match 'MemoryCompression' | Should Be $true
        $result[1] -match '0.0' | Should Be $true
    }
}

Describe "nohup" {
    It "Shows help usage" {
        $result = & $script:nohupFunc --help
        @($result)[0] -match 'Usage: nohup' | Should Be $true
    }

    It "Errors when no command is given" {
        $result = @(& $script:nohupFunc -ArgList @() 2>&1)
        $result[0].ToString() -match 'missing command' | Should Be $true
    }

    It "Launches a command as a background job" {
        $tmp = Join-Path $env:TEMP ('nohup-cov-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Push-Location $tmp
        try {
            $result = @(& $script:nohupFunc Start-Sleep -Seconds 30 2>&1)
            ($result -join "`n") -match 'Started background job: Start-Sleep' | Should Be $true
            ($result -join "`n") -match 'Job ID:' | Should Be $true
            ($result -join "`n") -match 'Output appended to:.*nohup.out' | Should Be $true
            (& $script:module { $script:JobTable.Count }) | Should BeGreaterThan 0
        } finally {
            Pop-Location
            Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
        }
    }

    It "Starts a background job and appends its output to nohup.out" {
        Reset-JobTable
        $tmp = Join-Path $env:TEMP ('nohup-flush-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        Push-Location $tmp
        try {
            $nohupOut = Join-Path $tmp 'nohup.out'
            $r = @(& $script:nohupFunc Write-Output 'hello-nohup' 2>&1)
            ($r -join "`n") -match 'Started background job' | Should Be $true
            # The event action runs async: poll for nohup.out to be flushed.
            $deadline = (Get-Date).AddSeconds(15)
            while (-not (Test-Path $nohupOut) -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 250
            }
            Test-Path $nohupOut | Should Be $true
            (Get-Content $nohupOut -Raw) -match 'hello-nohup' | Should Be $true
        } finally {
            Pop-Location
            Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
            # Clean up event subscriptions and any jobs the function left behind
            Get-EventSubscriber -ErrorAction SilentlyContinue | Unregister-Event -Force -ErrorAction SilentlyContinue
            Get-Job | Stop-Job -ErrorAction SilentlyContinue
            Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
            Reset-JobTable
        }
    }
}

Describe "pgrep" {
    It "Shows help usage" {
        $result = & $script:pgrepFunc --help
        @($result)[0] -match 'Usage: pgrep' | Should Be $true
    }

    It "Errors when no pattern is given" {
        $result = @(& $script:pgrepFunc -ArgList @() 2>&1)
        $result[0].ToString() -match 'missing pattern' | Should Be $true
    }

    It "Returns PIDs for matching process names" {
        $result = @(& $script:pgrepFunc powershell)
        $result.Count | Should BeGreaterThan 0
        @($result)[0] -match '^\d+$' | Should Be $true
    }

    It "Returns PID and name with dash l" {
        $result = @(& $script:pgrepFunc -l powershell)
        $result.Count | Should BeGreaterThan 0
        @($result)[0] -match '^\d+ \S+' | Should Be $true
    }

    It "Returns no output when nothing matches" {
        $result = @(& $script:pgrepFunc nonexistentprocssxyz)
        $result.Count | Should Be 0
    }

    It "Applies the user filter" {
        $result = @(& $script:pgrepFunc -u $env:USERNAME nonexistentprocssxyz)
        $result.Count | Should Be 0
    }
}

Describe "pkill" {
    It "Shows help usage" {
        $result = & $script:pkillFunc --help
        @($result)[0] -match 'Usage: pkill' | Should Be $true
    }

    It "Errors when no pattern is given" {
        $result = @(& $script:pkillFunc -ArgList @() 2>&1)
        $result[0].ToString() -match 'missing pattern' | Should Be $true
    }

    It "Does nothing when no process matches" {
        { & $script:pkillFunc nonexistentprocssxyz 2>$null } | Should Not Throw
    }

    It "Applies the user filter" {
        { & $script:pkillFunc -u $env:USERNAME nonexistentprocssxyz 2>$null } | Should Not Throw
    }

    It "Kills processes matching the pattern" {
        $proc = Start-Process -FilePath 'cmd.exe' -PassThru -WindowStyle Hidden
        try {
            Start-Sleep -Milliseconds 300
            $proc.HasExited | Should Be $false
            & $script:pkillFunc cmd 2>$null
            Start-Sleep -Milliseconds 500
            $proc.Refresh()
            $proc.HasExited | Should Be $true
        } finally {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
        }
    }

    AfterAll {
        # Stop and remove any background jobs spawned by the tests
        Get-Job | Stop-Job -ErrorAction SilentlyContinue
        Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
        & $script:module {
            foreach ($key in @($script:JobTable.Keys)) {
                $entry = $script:JobTable[$key]
                $j = $entry.Job
                if ($j) {
                    Stop-Job -Job $j -ErrorAction SilentlyContinue
                    Remove-Job -Job $j -Force -ErrorAction SilentlyContinue
                }
            }
            $script:JobTable = @{}
        }
        Get-EventSubscriber | Unregister-Event -Force -ErrorAction SilentlyContinue
    }
}
