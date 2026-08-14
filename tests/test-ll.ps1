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

Describe "ll -t / -r / -rt sort options" {
    BeforeAll {
        $sortDir = "test-ll-sort-temp"
        New-Item -ItemType Directory -Path $sortDir -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\a.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\b.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\c.txt" -Force | Out-Null
        (Get-Item "$sortDir\a.txt").LastWriteTime = Get-Date '2020-01-01'
        (Get-Item "$sortDir\c.txt").LastWriteTime = Get-Date '2021-01-01'
        (Get-Item "$sortDir\b.txt").LastWriteTime = Get-Date '2023-01-01'
    }
    AfterAll {
        Remove-Item $sortDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "-t sorts by time, newest first" {
        $out = @(& $script:llFunc -t $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'b.txt,c.txt,a.txt'
    }
    It "-rt sorts by time reverse, oldest first" {
        $out = @(& $script:llFunc -rt $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,c.txt,b.txt'
    }
    It "-r reverses name order" {
        $out = @(& $script:llFunc -r $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'c.txt,b.txt,a.txt'
    }
}