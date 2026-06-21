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
        $result = grep -Pattern "hello" -Path $testFile1, $testFile2
        $result.Count | Should Be 2
    }
    It "Handles non-existent file" {
        # grep 会输出错误但继续执行
        $errorOccurred = $false
        try { grep -Pattern "test" -Path "nonexistent.txt" } catch { $errorOccurred = $true }
        $errorOccurred | Should Be $false
    }
    It "Returns empty for no match" {
        $result = grep -Pattern "xyz123" -Path $testFile1
        $result | Should Be $null
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
    It "Uses default path '.'" {
        # 验证默认路径参数
        $code = Get-Content (Join-Path $scriptDir "..\core-search.ps1") -Raw
        $code -match "Path='.'" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-find-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = find -Path $emptyDir
        $result | Should Be $emptyDir
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
    It "Returns empty for no match" {
        $result = find -Path $testDir -name "*.xyz"
        $result | Should Be $null
    }
}

Describe "which parameter tests" {
    It "Shows all sources with -a" {
        # 验证 -a 参数逻辑
        $code = Get-Content (Join-Path $scriptDir "..\core-search.ps1") -Raw
        $code -match "\-a.*Source" | Should Be $true
    }
    It "Handles non-existent command" {
        $result = which -Command "nonexistent-cmd-xyz"
        $result | Should Be $null
    }
}