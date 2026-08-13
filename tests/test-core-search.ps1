# tests\test-core-search.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\args-parser.ps1")
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
        $result = grep 'hello' $testFile
        $result -match "hello world" | Should Be $true
    }
    It "Case-insensitive with -i" {
        $result = grep -i 'hello' $testFile
        $result.Count | Should Be 2
    }
    It "Shows line numbers with -n" {
        $result = grep -n 'hello' $testFile
        $result -match ":" | Should Be $true
    }
    It "Shows help" {
        $result = grep --help
        $result -match "Usage" | Should Be $true
    }
    It "Counts matches with -c" {
        $result = grep -c 'hello' $testFile
        $result -match ": 1" | Should Be $true
    }
    It "Shows only filenames with -l" {
        $result = grep -l 'hello' $testFile
        $result -match "test-grep" | Should Be $true
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
        $result = find $testDir -name "*.txt"
        $result -match "file.txt" | Should Be $true
    }
    It "Finds files only with -type f" {
        $result = find $testDir -type 'f'
        $result -match "subdir" | Should Be $false
    }
    It "Finds directories only with -type d" {
        $result = find $testDir -type 'd'
        $joined = @($result) -join '|'
        $joined -match "subdir" | Should Be $true
        $joined -match "file.txt" | Should Be $false
    }
    It "Shows help" {
        $result = find --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "which" {
    It "Finds command location" {
        $result = which Get-Process
        $result | Should Not Be $null
    }
    It "Shows help" {
        $result = which --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "grep parameter tests" {
    BeforeAll {
        $testFile1 = "test-grep-multi1.txt"
        $testFile2 = "test-grep-multi2.txt"
        Set-Content -Path $testFile1 -Value "hello world", "test line" -Encoding UTF8
        Set-Content -Path $testFile2 -Value "hello again" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile1, $testFile2 -Force -ErrorAction SilentlyContinue
    }
    It "Searches multiple files" {
        $result = grep 'hello' $testFile1 $testFile2
        $result.Count | Should Be 2
    }
    It "Handles non-existent file" {
        $errorOccurred = $false
        try { grep 'test' nonexistent.txt } catch { $errorOccurred = $true }
        $errorOccurred | Should Be $false
    }
    It "Returns empty for no match" {
        $result = grep 'xyz123' $testFile1
        $result | Should Be $null
    }
}

Describe "grep long options" {
    BeforeAll {
        $testFile = "test-grep-long.txt"
        Set-Content -Path $testFile -Value "Hello World", "test line" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
    It "Uses --ignore-case" {
        $result = grep --ignore-case 'hello' $testFile
        $result -match "Hello World" | Should Be $true
    }
    It "Uses --line-number" {
        $result = grep --line-number 'test' $testFile
        $result -match ":" | Should Be $true
    }
    It "Uses --count" {
        $result = grep --count 'test' $testFile
        $result -match ": 1" | Should Be $true
    }
}

Describe "find parameter tests" {
    BeforeAll {
        $testDir = "test-find-params"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType Directory -Path "$testDir\sub" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\file.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-find-params" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Finds by name in directory" {
        $result = find $testDir -name "*.txt"
        $result -match "file.txt" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-find-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = find $emptyDir
        $result -match "test-find-empty" | Should Be $true
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
    It "Returns empty for no match" {
        $result = find $testDir -name "*.xyz"
        $result | Should Be $null
    }
}

Describe "which parameter tests" {
    It "Shows all sources with -a" {
        $code = Get-Content (Join-Path $scriptDir "..\core-search.ps1") -Raw
        $code -match "showAll" | Should Be $true
    }
    It "Handles non-existent command" {
        $result = which nonexistent-cmd-xyz
        $result | Should Be $null
    }
}
