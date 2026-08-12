# tests\test-ll.ps1
# Fix: Use explicit function calls

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import module to get ll function
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Get ll function reference
$script:llFunc = Get-Command ll -CommandType Function -ErrorAction SilentlyContinue

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
        $result = & $script:llFunc $testDir
        $result -match "file1.txt" | Should Be $true
    }

    It "ll outputs long format" {
        $result = & $script:llFunc $testDir
        $result -match "rw" | Should Be $true
    }
}