# tests/test-ls-bare.ps1
# Regression: bare `ls` (no arguments) must list the current directory.
# Root cause: `@() + $null` yields `@($null)` in PS 5.1; with a [string[]] coercion the
# $null becomes an empty string positional, which ls silently skipped (IsNullOrWhiteSpace),
# producing zero output.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force
$script:lsFunc = Get-Command ls -CommandType Function -ErrorAction SilentlyContinue

Describe "ls (bare, no arguments)" {
    BeforeAll {
        $testDir = Join-Path $env:TEMP "ls-bare-test"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $testDir 'alpha.txt') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $testDir 'sub') -Force | Out-Null
        Push-Location $testDir
    }
    AfterAll {
        Pop-Location
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "bare ls lists the current directory (no args)" {
        $out = @(& $script:lsFunc)
        $out | Should Not BeNullOrEmpty
        ($out -join ' ') | Should Match 'alpha.txt'
        ($out -join ' ') | Should Match 'sub'
    }

    It "bare ls -l lists the current directory" {
        $out = @(& $script:lsFunc -l)
        $out | Should Not BeNullOrEmpty
        ($out -join ' ') | Should Match 'alpha.txt'
    }
}
