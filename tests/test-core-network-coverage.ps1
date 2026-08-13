# tests\test-core-network-coverage.ps1
# Exercises uncovered branches in core-network.ps1 (curl, ping, netstat, wget).
# Compatible with Pester 3.4.0 on Windows PowerShell 5.1. ASCII-only.
#
# Strategy:
#   - The module functions shell out to real network cmdlets. They are stubbed
#     out with Pester Mock -ModuleName so no real network I/O occurs.
#   - Write-BashError is a non-exported module helper (args-parser.ps1) that
#     Pester cannot mock, so the error branches are asserted by capturing the
#     non-terminating error output with 2>&1.
#   - Note: calling these functions with no arguments at all leaves $ArgList at
#     $null, and Parse-BashArgs coerces that to a phantom empty positional, so
#     the "missing URL/host" branches are reached with flag-only calls instead.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Remove-Item Alias:curl -Force -ErrorAction SilentlyContinue
Remove-Item Alias:wget -Force -ErrorAction SilentlyContinue
Remove-Item Alias:ping -Force -ErrorAction SilentlyContinue
Remove-Item Alias:netstat -Force -ErrorAction SilentlyContinue

Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

$script:curlFunc = Get-Command curl -CommandType Function
$script:pingFunc = Get-Command ping -CommandType Function
$script:netstatFunc = Get-Command netstat -CommandType Function
$script:wgetFunc = Get-Command wget -CommandType Function

Describe "curl branch coverage" {
    It "curl fetches body for a plain URL" {
        Mock Invoke-WebRequest { return [pscustomobject]@{ Content = 'MOCKED_BODY' } } -ModuleName bash-aliases
        $result = & $script:curlFunc 'http://example.com/page'
        @($result)[0] | Should Be 'MOCKED_BODY'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { -not $OutFile }
    }

    It "curl -I requests headers only" {
        Mock Invoke-WebRequest { param($Url, $Method) return [pscustomobject]@{ Headers = @{ 'X-Mock' = 'header-value' } } } -ModuleName bash-aliases
        $result = @(& $script:curlFunc -I 'http://example.com/page')
        $result[0]['X-Mock'] | Should Be 'header-value'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $Method -eq 'Head' }
    }

    It "curl --head requests headers only (long form)" {
        Mock Invoke-WebRequest { param($Url, $Method) return [pscustomobject]@{ Headers = @{ 'X-Mock' = 'header-value' } } } -ModuleName bash-aliases
        $result = @(& $script:curlFunc --head 'http://example.com/page')
        $result[0]['X-Mock'] | Should Be 'header-value'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $Method -eq 'Head' }
    }

    It "curl --remote-name downloads to the URL filename" {
        Mock Invoke-WebRequest { param($Url, $OutFile) return [pscustomobject]@{ Content = "saved:$OutFile" } } -ModuleName bash-aliases
        $null = & $script:curlFunc --remote-name 'http://example.com/file.txt'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile -eq 'file.txt' }
    }

    It "curl --output downloads to a custom file" {
        Mock Invoke-WebRequest { param($Url, $OutFile) return [pscustomobject]@{ Content = "saved:$OutFile" } } -ModuleName bash-aliases
        $null = & $script:curlFunc --output 'out.txt' 'http://example.com/file.txt'
        # The fixed code resolves $outputFile to the string 'out.txt', not a boolean.
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile -is [string] -and $OutFile -eq 'out.txt' }
    }

    It "curl -o FILE passes the string path as OutFile" {
        Mock Invoke-WebRequest { param($Url, $OutFile) return [pscustomobject]@{ Content = "saved:$OutFile" } } -ModuleName bash-aliases
        $null = & $script:curlFunc -o 'out.txt' 'http://example.com/file.txt'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile -is [string] -and $OutFile -eq 'out.txt' }
    }

    It "curl --output=FILE (equals syntax) downloads to a custom file" {
        Mock Invoke-WebRequest { param($Url, $OutFile) return [pscustomobject]@{ Content = "saved:$OutFile" } } -ModuleName bash-aliases
        $null = & $script:curlFunc --output=out.txt 'http://example.com/file.txt'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile }
    }

    It "curl with -o FILE but no URL reports missing URL" {
        $result = & $script:curlFunc -o out.txt 2>&1
        { & $script:curlFunc -o out.txt } | Should Not Throw
        (($result -join ' ') -match 'missing URL') | Should Be $true
    }
}

Describe "ping branch coverage" {
    It "ping -c N probes N times" {
        Mock Test-Connection { param($ComputerName, $Count) 1..$Count | ForEach-Object { [pscustomobject]@{ Address = '127.0.0.1'; ResponseTime = 1 } } } -ModuleName bash-aliases
        $result = @(& $script:pingFunc -c 2 'localhost')
        $result.Count | Should Be 2
        (($result -join ' ') -match 'Reply from 127.0.0.1') | Should Be $true
        Assert-MockCalled Test-Connection -ModuleName bash-aliases -Times 1 -ParameterFilter { $Count -eq 2 }
    }

    It "ping --count N probes N times (long form)" {
        Mock Test-Connection { param($ComputerName, $Count) 1..$Count | ForEach-Object { [pscustomobject]@{ Address = '127.0.0.1'; ResponseTime = 1 } } } -ModuleName bash-aliases
        $result = @(& $script:pingFunc --count 3 'localhost')
        $result.Count | Should Be 3
        Assert-MockCalled Test-Connection -ModuleName bash-aliases -Times 1 -ParameterFilter { $Count -eq 3 }
    }

    It "ping defaults to 4 probes" {
        Mock Test-Connection { param($ComputerName, $Count) 1..$Count | ForEach-Object { [pscustomobject]@{ Address = '127.0.0.1'; ResponseTime = 1 } } } -ModuleName bash-aliases
        $null = & $script:pingFunc 'localhost'
        Assert-MockCalled Test-Connection -ModuleName bash-aliases -Times 1 -ParameterFilter { $Count -eq 4 }
    }

    It "ping with -c N but no host reports missing host" {
        $result = & $script:pingFunc -c 2 2>&1
        { & $script:pingFunc -c 2 } | Should Not Throw
        (($result -join ' ') -match 'missing host') | Should Be $true
    }

    It "ping --help prints usage" {
        $result = & $script:pingFunc --help
        @($result)[0] -match 'Usage' | Should Be $true
    }
}

Describe "netstat branch coverage" {
    It "netstat prints TCP connection lines" {
        Mock Get-NetTCPConnection { @([pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 1234; RemoteAddress = '192.168.1.5'; RemotePort = 80; State = 'Established' }, [pscustomobject]@{ LocalAddress = '0.0.0.0'; LocalPort = 445; RemoteAddress = $null; RemotePort = 0; State = 'Listen' }) } -ModuleName bash-aliases
        $result = @(& $script:netstatFunc)
        $result.Count | Should Be 2
        (($result -join ' ') -match 'Established') | Should Be $true
        (($result -join ' ') -match '\*:\*') | Should Be $true
    }

    It "netstat -t -u -n parses short flags" {
        Mock Get-NetTCPConnection { @([pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 1234; RemoteAddress = '192.168.1.5'; RemotePort = 80; State = 'Established' }) } -ModuleName bash-aliases
        $result = @(& $script:netstatFunc -t -u -n)
        $result.Count | Should Be 1
        Assert-MockCalled Get-NetTCPConnection -ModuleName bash-aliases -Times 1
    }

    It "netstat --tcp --udp --numeric parses long flags" {
        Mock Get-NetTCPConnection { @([pscustomobject]@{ LocalAddress = '127.0.0.1'; LocalPort = 1234; RemoteAddress = '192.168.1.5'; RemotePort = 80; State = 'Established' }) } -ModuleName bash-aliases
        $result = @(& $script:netstatFunc --tcp --udp --numeric)
        $result.Count | Should Be 1
        Assert-MockCalled Get-NetTCPConnection -ModuleName bash-aliases -Times 1
    }

    It "netstat falls back to netstat.exe when Get-NetTCPConnection returns nothing" {
        Mock Get-NetTCPConnection { $null } -ModuleName bash-aliases
        Mock netstat.exe { 'MOCK_NETSTAT_EXE_OUTPUT' } -ModuleName bash-aliases
        $result = & $script:netstatFunc
        @($result)[0] | Should Be 'MOCK_NETSTAT_EXE_OUTPUT'
        Assert-MockCalled netstat.exe -ModuleName bash-aliases -Times 1
    }

    It "netstat --help prints usage" {
        $result = & $script:netstatFunc --help
        @($result)[0] -match 'Usage' | Should Be $true
    }
}

Describe "wget branch coverage" {
    It "wget downloads to the URL filename by default" {
        Mock Invoke-WebRequest { param($Url, $OutFile) } -ModuleName bash-aliases
        $result = & $script:wgetFunc 'http://example.com/file.txt'
        (($result -join ' ') -match 'Downloading') | Should Be $true
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile -eq 'file.txt' }
    }

    It "wget -O FILE downloads to a custom file" {
        Mock Invoke-WebRequest { param($Url, $OutFile) } -ModuleName bash-aliases
        $null = & $script:wgetFunc -O 'out.txt' 'http://example.com/file.txt'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile -eq 'out.txt' }
    }

    It "wget -q suppresses progress messages" {
        Mock Invoke-WebRequest { param($Url, $OutFile) } -ModuleName bash-aliases
        $result = @(& $script:wgetFunc -q 'http://example.com/file.txt')
        $result.Count | Should Be 0
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile -eq 'file.txt' }
    }

    It "wget reports download failure without throwing" {
        Mock Invoke-WebRequest { throw 'mock network failure' } -ModuleName bash-aliases
        { & $script:wgetFunc 'http://example.com/fail.txt' } | Should Not Throw
        $result = & $script:wgetFunc 'http://example.com/fail.txt' 2>&1
        (($result -join ' ') -match 'failed to download') | Should Be $true
    }

    It "wget with -O FILE but no URL reports missing URL" {
        $result = & $script:wgetFunc -O out.txt 2>&1
        { & $script:wgetFunc -O out.txt } | Should Not Throw
        (($result -join ' ') -match 'missing URL') | Should Be $true
    }
}
