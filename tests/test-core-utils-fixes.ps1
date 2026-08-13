# tests/test-core-utils-fixes.ps1
# TDD regression tests for production bug fixes in core-utils.ps1.
# Pester 3.4.0, Windows PowerShell 5.1. ASCII-only (no non-ASCII literals).

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

foreach ($a in @('echo', 'tee', 'env', 'date', 'diff')) {
    Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue
}
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

$script:teeFunc   = Get-Command tee   -CommandType Function
$script:xargsFunc = Get-Command xargs -CommandType Function
$script:seqFunc   = Get-Command seq   -CommandType Function
$script:revFunc   = Get-Command rev   -CommandType Function

Describe "tee pipeline" {
    It "writes piped input to the file" {
        $f = Join-Path $env:TEMP ("tee-fix-{0}.txt" -f (Get-Random))
        try {
            $null = "hello tee" | & $script:teeFunc $f
            Test-Path $f | Should Be $true
            $content = Get-Content $f -Raw
            ($content -replace "`r?`n$", '') | Should Be "hello tee"
        } finally {
            Remove-Item $f -Force -ErrorAction SilentlyContinue
        }
    }

    It "passes piped input through to stdout" {
        $f = Join-Path $env:TEMP ("tee-fix2-{0}.txt" -f (Get-Random))
        try {
            $out = "passthrough" | & $script:teeFunc $f
            $out | Should Be "passthrough"
        } finally {
            Remove-Item $f -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "xargs pipeline" {
    It "executes the command with piped input" {
        $result = @("a b c" | & $script:xargsFunc -n 2 Write-Output)
        @($result).Count | Should BeGreaterThan 0
    }

    It "batches piped input with dash n" {
        $result = @('a', 'b', 'c') | & $script:xargsFunc -n 2 cmd /c echo
        ($result -join '|') | Should Be 'a b|c'
    }
}

Describe "seq negative increment" {
    It "generates a descending sequence with a negative increment" {
        $result = @(& $script:seqFunc 5 -1 1)
        ($result -join ',') | Should Be '5,4,3,2,1'
    }

    It "still generates an ascending sequence" {
        $result = @(& $script:seqFunc 1 1 3)
        ($result -join ',') | Should Be '1,2,3'
    }
}

Describe "rev help binding" {
    It "shows usage with dash dash help" {
        $result = @(& $script:revFunc --help)
        @($result)[0] | Should Match "Usage: rev"
    }

    It "shows usage with dash help" {
        $result = @(& $script:revFunc -help)
        @($result)[0] | Should Match "Usage: rev"
    }

    It "still reverses lines from the pipeline" {
        $result = @('hello') | & $script:revFunc
        @($result)[0] | Should Be 'olleh'
    }
}
