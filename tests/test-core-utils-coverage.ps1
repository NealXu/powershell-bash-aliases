# tests/test-core-utils-coverage.ps1
# Additional coverage for core-utils.ps1: watch, xargs, seq, shuf, env,
# history, date, rev, tee, time. Pester 3.4.0, Windows PowerShell 5.1.
# This file is ASCII-only (no non-ASCII literals).

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Remove conflicting aliases before importing the module
foreach ($a in @('ls','cat','rm','cp','mv','ps','kill','sort','ping','wget','echo','tee','env','date','diff')) {
    Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue
}
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

$script:watchFunc   = Get-Command watch   -CommandType Function
$script:xargsFunc   = Get-Command xargs   -CommandType Function
$script:seqFunc     = Get-Command seq     -CommandType Function
$script:shufFunc    = Get-Command shuf    -CommandType Function
$script:envFunc     = Get-Command env     -CommandType Function
$script:historyFunc = Get-Command history -CommandType Function
$script:dateFunc    = Get-Command date    -CommandType Function
$script:revFunc     = Get-Command rev     -CommandType Function
$script:teeFunc     = Get-Command tee     -CommandType Function
$script:timeFunc    = Get-Command time    -CommandType Function

Describe "watch" {
    It "shows help" {
        $result = @(& $script:watchFunc --help)
        @($result)[0] | Should Match "Usage: watch"
    }

    It "reports missing command when no command is given" {
        $out = @(& $script:watchFunc -n abc 2>&1)
        ($out -join ' ') | Should Match "missing command"
    }

    It "reports an invalid interval" {
        $out = @(& $script:watchFunc -n abc cmd 2>&1)
        ($out -join ' ') | Should Match "invalid interval"
    }
}

Describe "xargs" {
    It "shows help" {
        $result = @(& $script:xargsFunc --help)
        @($result)[0] | Should Match "Usage: xargs"
    }

    It "does not run the command when input is empty and dash r is set" {
        $result = @() | & $script:xargsFunc -r echo
        $result | Should Be $null
    }

    It "parses a custom command even without piped input" {
        $result = & $script:xargsFunc echo hi
        $result | Should Be $null
    }

    It "accepts piped input without throwing" {
        { @('a','b') | & $script:xargsFunc | Out-Null } | Should Not Throw
    }
}

Describe "seq" {
    It "generates a simple range 1..N" {
        $result = @(& $script:seqFunc 5)
        ($result -join ',') | Should Be '1,2,3,4,5'
    }

    It "generates a range with a first value" {
        $result = @(& $script:seqFunc 3 5)
        ($result -join ',') | Should Be '3,4,5'
    }

    It "generates a range with an increment" {
        $result = @(& $script:seqFunc 1 2 10)
        ($result -join ',') | Should Be '1,3,5,7,9'
    }

    It "uses a custom separator with dash s" {
        $result = @(& $script:seqFunc -s ' ' 3 5)
        @($result)[0] | Should Be '3 4 5'
    }

    It "pads to equal width with dash w" {
        $result = @(& $script:seqFunc -w 8 10)
        ($result -join ',') | Should Be '08,09,10'
    }

    It "formats output with dash f" {
        $result = @(& $script:seqFunc -f '{0:00}' 3 5)
        ($result -join ',') | Should Be '03,04,05'
    }

    It "reports a missing operand" {
        $out = @(& $script:seqFunc 2>&1)
        ($out -join ' ') | Should Match "missing operand"
    }

    It "reports a zero increment" {
        $out = @(& $script:seqFunc 1 0 5 2>&1)
        ($out -join ' ') | Should Match "zero increment"
    }
}

Describe "shuf" {
    BeforeAll {
        $script:shufFile = Join-Path $env:TEMP ("shuf-cov-{0}.txt" -f (Get-Random))
        Set-Content -Path $script:shufFile -Value @('l1','l2','l3','l4') -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:shufFile -Force -ErrorAction SilentlyContinue
    }

    It "shuffles piped lines preserving the set" {
        $result = @('alpha','beta','gamma') | & $script:shufFunc
        @($result).Count | Should Be 3
        (@($result) | Sort-Object) -join ',' | Should Be 'alpha,beta,gamma'
    }

    It "shuffles echo-mode arguments" {
        $result = @(& $script:shufFunc -e 'x' 'y' 'z')
        @($result).Count | Should Be 3
        (@($result) | Sort-Object) -join ',' | Should Be 'x,y,z'
    }

    It "limits output with dash n in echo mode" {
        $result = @(& $script:shufFunc -e -n 2 'x' 'y' 'z')
        @($result).Count | Should Be 2
    }

    It "repeats with dash r in echo mode" {
        $result = @(& $script:shufFunc -e -r -n 4 'x' 'y' 'z')
        @($result).Count | Should Be 4
    }

    It "shuffles lines from a file" {
        $result = @(& $script:shufFunc $script:shufFile)
        @($result).Count | Should Be 4
    }

    It "limits output from a file with dash n" {
        $result = @(& $script:shufFunc -n 2 $script:shufFile)
        @($result).Count | Should Be 2
    }
}

Describe "env" {
    It "prints all environment variables" {
        $result = @(& $script:envFunc -ArgList @())
        @($result).Count | Should BeGreaterThan 10
        (@($result) -match '^PATH=').Count | Should BeGreaterThan 0
    }

    It "prints a modified environment from NAME=VALUE" {
        $result = @(& $script:envFunc FOO=bar)
        @($result) -contains 'FOO=bar' | Should Be $true
    }

    It "runs a command with a NAME=VALUE set" {
        $result = @(& $script:envFunc FOO=bar Write-Output '$env:FOO')
        @($result)[0] | Should Be 'bar'
    }

    It "unsets a variable with dash u" {
        Set-Item Env:FOO 'bar'
        try {
            $result = @(& $script:envFunc '-u' FOO)
            (@($result) -match '^FOO=bar$').Count | Should Be 0
        } finally {
            Remove-Item Env:FOO -ErrorAction SilentlyContinue
        }
    }

    It "ignores the environment with dash i" {
        $result = @(& $script:envFunc '-i' FOO=bar)
        ($result -join ',') | Should Be 'FOO=bar'
    }
}

Describe "history" {
    It "clears history with dash c" {
        $result = @(& $script:historyFunc -c)
        @($result)[0] | Should Be 'History cleared.'
    }

    It "reports an out-of-range delete offset" {
        $out = @(& $script:historyFunc '-d' 999999 2>&1)
        ($out -join ' ') | Should Match "out of range"
    }

    It "reports an invalid delete offset" {
        $out = @(& $script:historyFunc '-d' abc 2>&1)
        ($out -join ' ') | Should Match "invalid offset"
    }

    It "displays history without throwing" {
        { & $script:historyFunc | Out-Null } | Should Not Throw
    }
}

Describe "date" {
    It "shows the current date" {
        $result = @(& $script:dateFunc)
        ($result -join ' ') | Should Match '\d{4}'
    }

    It "shows help" {
        $result = @(& $script:dateFunc --help)
        @($result)[0] | Should Match "Usage: date"
    }

    It "formats a custom date with a format string" {
        $result = @(& $script:dateFunc '-d' '2023-01-01' '+yyyy-MM-dd')
        @($result)[0] | Should Be '2023-01-01'
    }

    It "parses a custom date with dash d" {
        $result = @(& $script:dateFunc '-d' '2023-01-01')
        ($result -join ' ') | Should Match '2023'
    }

    It "formats as RFC 2822 with dash R" {
        $result = @(& $script:dateFunc '-R')
        ($result -join ' ') | Should Match '\d{4}'
    }

    It "formats as ISO 8601 with dash I" {
        $result = @(& $script:dateFunc '-I')
        @($result)[0] | Should Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$'
    }

    It "outputs UTC with dash u" {
        $result = @(& $script:dateFunc '-u')
        ($result -join ' ') | Should Match '\d{4}'
    }

    It "reports an invalid date" {
        $out = @(& $script:dateFunc '-d' 'not-a-date' 2>&1)
        ($out -join ' ') | Should Match "invalid date"
    }
}

Describe "rev" {
    BeforeAll {
        $script:revFile = Join-Path $env:TEMP ("rev-cov-{0}.txt" -f (Get-Random))
        Set-Content -Path $script:revFile -Value @('abc','def') -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:revFile -Force -ErrorAction SilentlyContinue
    }

    It "reverses each line of a file" {
        $result = @(& $script:revFunc $script:revFile)
        ($result -join ',') | Should Be 'cba,fed'
    }

    It "reverses multiple piped lines" {
        $result = @('abc','def') | & $script:revFunc
        ($result -join ',') | Should Be 'cba,fed'
    }

    It "shows help" {
        $result = @(& $script:revFunc -help)
        @($result)[0] | Should Match "Usage: rev"
    }
}

Describe "tee" {
    It "shows help" {
        $result = @(& $script:teeFunc --help)
        @($result)[0] | Should Match "Usage: tee"
    }

    It "returns silently when there is no pipeline input" {
        $f = Join-Path $env:TEMP ("tee-cov-{0}.txt" -f (Get-Random))
        try {
            $result = & $script:teeFunc $f
            $result | Should Be $null
        } finally {
            Remove-Item $f -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "time" {
    It "shows help" {
        $result = @(& $script:timeFunc --help)
        @($result)[0] | Should Match "Usage: time"
    }

    It "times a command with the portability flag" {
        $result = @(& $script:timeFunc -p echo hello)
        @($result)[-1] | Should Match '^real '
    }

    It "times a command with the default output" {
        $result = @(& $script:timeFunc echo hello)
        ($result -join "`n") | Should Match 'Execution time:'
    }

    It "reports a failed command" {
        $out = @(& $script:timeFunc 'definitely-not-a-command-xyz' 2>&1)
        ($out -join ' ') | Should Match "failed to execute"
    }
}
