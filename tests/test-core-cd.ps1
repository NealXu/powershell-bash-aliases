# tests/test-core-cd.ps1
# TDD tests for bash-style cd (cd -, cd ~, cd PATH, cd with spaces, cd errors).
# Pester 3.4.0, Windows PowerShell 5.1. ASCII-only (no non-ASCII literals).

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# Remove conflicting aliases at GLOBAL scope (as install.ps1's profile preamble
# does). A module cannot remove global built-in aliases from module scope during
# import, so the authoritative removal is the profile line; tests mirror that.
foreach ($a in @('cd','ls','cat','rm','cp','mv','sort')) { Remove-Item "Alias:$a" -Force -ErrorAction SilentlyContinue }
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force
$script:cdFunc = Get-Command cd -CommandType Function

Describe "cd" {
    It "cd - returns to the previous directory" {
        $orig = Get-Location
        $t1 = Join-Path $env:TEMP ("cd-test1-" + [guid]::NewGuid().ToString("N"))
        $t2 = Join-Path $env:TEMP ("cd-test2-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $t1, $t2 -Force | Out-Null
        try {
            Set-Location $t1
            & $script:cdFunc $t2
            & $script:cdFunc '-'
            (Get-Location).Path | Should Be $t1
        } finally {
            Set-Location $orig
            Remove-Item $t1, $t2 -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "cd with no args goes home" {
        $orig = Get-Location
        try {
            & $script:cdFunc
            (Get-Location).Path | Should Be $HOME
        } finally {
            Set-Location $orig
        }
    }

    It "cd tilde goes home" {
        $orig = Get-Location
        try {
            & $script:cdFunc '~'
            (Get-Location).Path | Should Be $HOME
        } finally {
            Set-Location $orig
        }
    }

    It "cd path changes to that directory" {
        $orig = Get-Location
        $t = Join-Path $env:TEMP ("cd-test4-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        try {
            & $script:cdFunc $t
            (Get-Location).Path | Should Be $t
        } finally {
            Set-Location $orig
            Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "cd to a path containing a space" {
        $orig = Get-Location
        $t = Join-Path $env:TEMP ("cd space test-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $t -Force | Out-Null
        try {
            & $script:cdFunc $t
            (Get-Location).Path | Should Be $t
        } finally {
            Set-Location $orig
            Remove-Item $t -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "cd to a nonexistent path leaves location unchanged and writes an error" {
        $orig = Get-Location
        $missing = Join-Path $env:TEMP ("cd-missing-" + [guid]::NewGuid().ToString("N"))
        try {
            $output = & $script:cdFunc $missing 2>&1
            ($output -join ' ') | Should Match 'cd:'
            (Get-Location).Path | Should Be $orig.Path
        } finally {
            Set-Location $orig
        }
    }

    It "cd - with no previous directory writes 'no previous directory'" {
        # Re-import the module to reset module-scope $script:PrevDir.
        Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force
        $script:cdFunc = Get-Command cd -CommandType Function
        $orig = Get-Location
        $output = & $script:cdFunc '-' 2>&1
        ($output -join ' ') | Should Match 'no previous directory'
        (Get-Location).Path | Should Be $orig.Path
    }
}
