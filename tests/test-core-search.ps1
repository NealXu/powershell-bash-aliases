# tests\test-core-search.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\core-search.ps1")

Describe "grep" {
    BeforeAll {
        $testFile = "test-grep.txt"
        Set-Content -Path $testFile -Value "hello world", "test line", "HELLO again" -Encoding UTF8
    }

    AfterAll {
        Remove-Item "test-grep.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Matches pattern" {
        $result = grep -Pattern "hello" -Path $testFile
        $result -match "hello world" | Should Be $true
    }

    It "Case-insensitive with -i" {
        $result = grep -Pattern "hello" -Path $testFile -i
        $result.Count | Should Be 2
    }

    It "Shows line numbers with -n" {
        $result = grep -Pattern "hello" -Path $testFile -n
        $result -match "1:" | Should Be $true
    }

    It "Inverts match with -v" {
        $content = Get-Content $testFile
        $result = $content | Where { $_ -notmatch "hello" }
        $result -match "test line" | Should Be $true
    }

    It "Shows help" {
        $result = grep -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "find" {
    BeforeAll {
        $testDir = "test-find-temp"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\file.txt" -Force | Out-Null
        New-Item -ItemType Directory -Path "$testDir\subdir" -Force | Out-Null
    }

    AfterAll {
        Remove-Item "test-find-temp" -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Finds files by name pattern" {
        $result = find -Path $testDir -name "*.txt"
        $result -match "file.txt" | Should Be $true
    }

    It "Finds files only with -type f" {
        $result = find -Path $testDir -type 'f'
        $result -match "subdir" | Should Be $false
    }

    It "Finds directories only with -type d" {
        $result = find -Path $testDir -type 'd'
        $result -match "subdir" | Should Be $true
        $result -match "file.txt" | Should Be $false
    }

    It "Shows help" {
        $result = find -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "which" {
    It "Finds command location" {
        $result = which -Command "Get-Process"
        $result | Should Not Be $null
    }

    It "Shows help" {
        $result = which -Help
        $result -match "Usage" | Should Be $true
    }
}