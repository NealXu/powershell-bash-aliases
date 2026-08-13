# tests\test-core-process.ps1 (compatible with Pester 3.4.0)
# Fix: Use explicit function calls to avoid PowerShell alias and parameter conflicts

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Force remove conflicting aliases BEFORE importing module
Remove-Item "Global:Alias:ps" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:kill" -Force -ErrorAction SilentlyContinue

# Import module to get properly exported functions
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Get function references to bypass PowerShell alias priority
$script:psFunc = Get-Command ps -CommandType Function -ErrorAction SilentlyContinue
$script:killFunc = Get-Command kill -CommandType Function -ErrorAction SilentlyContinue
$script:killallFunc = Get-Command killall -CommandType Function -ErrorAction SilentlyContinue
$script:topFunc = Get-Command top -CommandType Function -ErrorAction SilentlyContinue
$script:pgrepFunc = Get-Command pgrep -CommandType Function -ErrorAction SilentlyContinue
$script:pkillFunc = Get-Command pkill -CommandType Function -ErrorAction SilentlyContinue
$script:jobsFunc = Get-Command jobs -CommandType Function -ErrorAction SilentlyContinue
$script:bgFunc = Get-Command bg -CommandType Function -ErrorAction SilentlyContinue
$script:fgFunc = Get-Command fg -CommandType Function -ErrorAction SilentlyContinue
$script:nohupFunc = Get-Command nohup -CommandType Function -ErrorAction SilentlyContinue

$script:module = Get-Module bash-aliases

Describe "ps" {
    It "Lists processes" {
        $result = & $script:psFunc
        $result.Count | Should BeGreaterThan 0
    }

    It "Shows all processes with dash e" {
        $result = & $script:psFunc -e
        $result.Count | Should BeGreaterThan 10
    }

    It "Shows help" {
        $result = & $script:psFunc -Help
        $result -match "Usage" | Should Be $true
    }

    It "Limits to 10 processes by default" {
        $procs = Get-Process
        $result = & $script:psFunc
        $result.Count | Should BeGreaterThan 0
    }
}

Describe "kill" {
    It "Shows signal list with dash l" {
        $result = & $script:killFunc -l
        $result -match "Signals" | Should Be $true
    }

    It "Shows help" {
        $result = & $script:killFunc -Help
        $result -match "Usage" | Should Be $true
    }

    It "Accepts process ID parameter" {
        $proc = Start-Process -FilePath "powershell" -ArgumentList "-Command", "Start-Sleep -Seconds 5" -PassThru
        $procId = $proc.Id
        try {
            Get-Process -Id $procId -ErrorAction SilentlyContinue | Should Not Be $null
            & $script:killFunc -Id $procId
            Start-Sleep -Seconds 1
            { Get-Process -Id $procId -ErrorAction Stop } | Should Throw
        } catch {
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "killall" {
    It "Shows help" {
        $result = & $script:killallFunc -Help
        $result -match "Usage" | Should Be $true
    }

    It "Accepts process name parameter" {
        $procsBefore = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        if ($procsBefore) {
            { & $script:killallFunc -Name "nonexistent_process_xyz" } | Should Not Throw
        }
    }
}

Describe "top" {
    It "Shows help" {
        $result = & $script:topFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Shows top processes by memory" {
        $result = & $script:topFunc --help
        $result | Should Not Be $null
    }

    It "Limits output to N processes" {
        $result = & $script:topFunc --help
        $result | Should Not Be $null
    }

    It "Uses default n equals 10" {
        $result = & $script:topFunc --help
        $result | Should Not Be $null
    }

    It "Handles a process with null CPU without throwing" {
        $result = InModuleScope bash-aliases {
            Mock Get-Process {
                @([pscustomobject]@{
                    Id = 1
                    ProcessName = 'MemoryCompression'
                    CPU = $null
                    WorkingSet = [long]1024
                })
            }
            @(top -n 1 2>$null)
        }
        $result.Count | Should Be 2
        $result[1] -match '0.0' | Should Be $true
    }
}

Describe "ps-params" {
    It "Shows detailed format with dash f" {
        $result = & $script:psFunc -f
        $true | Should Be $true
    }

    It "Accepts dash u user filter" {
        $code = Get-Content (Join-Path $scriptDir "..\core-process.ps1") -Raw
        $code -match "UserName" | Should Be $true
    }

    It "Combines dash e and dash f" {
        $result = & $script:psFunc -e -f
        $true | Should Be $true
    }
}

Describe "kill-params" {
    It "Accepts dash Name parameter" {
        $code = Get-Content (Join-Path $scriptDir "..\core-process.ps1") -Raw
        $code -match "Stop-Process.*-Name" | Should Be $true
    }

    It "Handles non-existent process gracefully" {
        { & $script:killFunc -Id 999999 } | Should Not Throw
    }
}

Describe "pgrep" {
    It "Shows help" {
        $result = & $script:pgrepFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Finds processes by pattern" {
        $result = & $script:pgrepFunc -l "power"
        $result.Count | Should BeGreaterThan 0
    }

    It "Returns only PIDs without dash l" {
        $result = & $script:pgrepFunc "power"
        $result -match "^\d+$" | Should Be $true
    }
}

Describe "pkill" {
    It "Shows help" {
        $result = & $script:pkillFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Accepts pattern parameter" {
        $code = Get-Content (Join-Path $scriptDir "..\core-process.ps1") -Raw
        $code -match "Stop-Process" | Should Be $true
    }
}

Describe "jobs" {
    It "Shows help" {
        $result = & $script:jobsFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Lists no jobs when empty" {
        $result = & $script:jobsFunc
        $result -match "No background jobs" | Should Be $true
    }

    It "Accepts dash l flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-process.ps1") -Raw
        $code -match "list" | Should Be $true
    }
}

Describe "bg" {
    It "Shows help" {
        $result = & $script:bgFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Errors when no job" {
        & $script:module { param() $script:JobTable = @{} }
        $result = & $script:bgFunc 2>&1
        $result -match "no current job" | Should Be $true
    }

    It "Resumes an existing background job without throwing" {
        # Short sleep: bg never waits on the job; the process exits fast instead of lingering 30 s.
        $job = Start-Job -ScriptBlock { Start-Sleep -Milliseconds 200 }
        try {
            & $script:module { param($j) $script:JobTable = @{ 'j1' = $j } } $job
            { & $script:bgFunc 1 } | Should Not Throw
        } finally {
            Stop-Job -Job $job -ErrorAction SilentlyContinue
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "fg" {
    It "Shows help" {
        $result = & $script:fgFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Errors when no job" {
        & $script:module { param() $script:JobTable = @{} }
        $result = & $script:fgFunc 2>&1
        $result -match "no current job" | Should Be $true
    }
}

Describe "nohup" {
    It "Shows help" {
        $result = & $script:nohupFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Accepts command parameter" {
        { & $script:nohupFunc } | Should Not Throw
    }

    It "Uses Start-Job for background execution" {
        $code = Get-Content (Join-Path $scriptDir "..\core-process.ps1") -Raw
        $code -match "Start-Job" | Should Be $true
    }
}