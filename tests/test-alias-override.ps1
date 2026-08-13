# tests/test-alias-override.ps1
# TDD tests: importing via the module MANIFEST must override PowerShell's
# built-in AllScope aliases (ls, cd, cat, ...) so the module's functions win
# over alias precedence. The manifest's ScriptsToProcess (alias-cleanup.ps1)
# removes the built-in aliases in the caller's global scope before the module
# loads.
# Pester 3.4.0, Windows PowerShell 5.1. ASCII-only.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import via the MANIFEST (not the bare psm1) so ScriptsToProcess runs and
# removes the built-in aliases at global scope before the module is loaded.
Import-Module (Join-Path $scriptDir '..\bash-aliases.psd1') -Force

Describe "built-in alias override" {
    $targets = @('ls','cd','cat','rm','cp','mv','echo','diff')
    foreach ($a in $targets) {
        It "$a resolves to the module function" {
            (Get-Command $a).CommandType | Should Be Function
        }
    }
}

Describe "cd -" {
    It "cd - returns to the previous directory" {
        $script:cdFunc = Get-Command cd -CommandType Function
        $orig = Get-Location
        $t1 = Join-Path $env:TEMP ("alias-cd-test1-" + [guid]::NewGuid().ToString("N"))
        $t2 = Join-Path $env:TEMP ("alias-cd-test2-" + [guid]::NewGuid().ToString("N"))
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
}
