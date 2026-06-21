# tests\test-ll.ps1

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\core-file.ps1")

Describe "ll" {
    BeforeAll {
        $testDir = "test-ll-temp"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\file1.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-ll-temp" -Recurse -Force -EA SilentlyContinue
    }

    It "ll command exists" {
        $result = ll $testDir
        $result -match "file1.txt" | Should Be $true
    }

    It "ll outputs long format" {
        $result = ll $testDir
        $result -match "rw" | Should Be $true
    }
}