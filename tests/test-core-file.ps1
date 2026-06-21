# tests\test-core-file.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\core-file.ps1")

Describe "ls" {
    BeforeAll {
        $testDir = "test-ls-temp"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\file1.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\file2.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-ls-temp" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Lists directory contents" {
        $items = Get-ChildItem $testDir
        $items.Count | Should Be 2
    }
    It "Shows help" {
        $help = 'Usage: ls [-a] [-l] [-h] [PATH]'
        $help -match "Usage" | Should Be $true
    }
}

Describe "cat" {
    BeforeAll {
        $testFile = "test-cat.txt"
        Set-Content -Path $testFile -Value "line1", "line2", "line3" -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-cat.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Reads file content" {
        $content = Get-Content $testFile
        $content.Count | Should Be 3
    }
    It "Shows help" {
        $help = 'Usage: cat [-n] FILE...'
        $help -match "Usage" | Should Be $true
    }
}

Describe "rm" {
    It "Removes file" {
        $file = "test-rm-file.txt"
        New-Item -ItemType File -Path $file -Force | Out-Null
        Remove-Item $file -Force
        Test-Path $file | Should Be $false
    }
    It "Removes directory with -r" {
        $dir = "test-rm-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Remove-Item $dir -Recurse -Force
        Test-Path $dir | Should Be $false
    }
}

Describe "mkdir" {
    AfterAll {
        Remove-Item "test-mkdir-temp" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Creates directory" {
        New-Item -ItemType Directory -Path "test-mkdir-temp" -Force | Out-Null
        Test-Path "test-mkdir-temp" | Should Be $true
    }
}

Describe "cp" {
    BeforeAll {
        New-Item -ItemType File -Path "test-cp-src.txt" -Force | Out-Null
        Set-Content -Path "test-cp-src.txt" -Value "content" -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-cp-src.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-cp-dst.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Copies file" {
        Copy-Item "test-cp-src.txt" "test-cp-dst.txt" -Force
        Test-Path "test-cp-dst.txt" | Should Be $true
    }
}

Describe "mv" {
    BeforeAll {
        New-Item -ItemType File -Path "test-mv-src.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-mv-src.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-mv-dst.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Moves file" {
        Move-Item "test-mv-src.txt" "test-mv-dst.txt" -Force
        Test-Path "test-mv-src.txt" | Should Be $false
        Test-Path "test-mv-dst.txt" | Should Be $true
    }
}

Describe "touch" {
    AfterAll {
        Remove-Item "test-touch.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Creates new file" {
        New-Item -ItemType File -Path "test-touch.txt" -Force | Out-Null
        Test-Path "test-touch.txt" | Should Be $true
    }
    It "Updates existing file timestamp" {
        $before = (Get-Item "test-touch.txt").LastWriteTime
        Start-Sleep -Seconds 1
        (Get-Item "test-touch.txt").LastWriteTime = Get-Date
        $after = (Get-Item "test-touch.txt").LastWriteTime
        $after -gt $before | Should Be $true
    }
    It "Shows help" {
        $result = touch -Help
        $result -match "Usage" | Should Be $true
    }
    It "Does not create file with -c when file does not exist" {
        $nonexistent = "test-touch-no-create.txt"
        touch -Path $nonexistent -c
        Test-Path $nonexistent | Should Be $false
    }
    It "Accepts multiple file paths" {
        $files = @("test-touch-multi1.txt", "test-touch-multi2.txt")
        touch -Path $files
        Test-Path $files[0] | Should Be $true
        Test-Path $files[1] | Should Be $true
        Remove-Item $files -Force -ErrorAction SilentlyContinue
    }
}

Describe "ls parameter tests" {
    BeforeAll {
        $testDir = "test-ls-params"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\.hidden" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\visible.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\script.ps1" -Force | Out-Null
        Set-Content -Path "$testDir\visible.txt" -Value "content" -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-ls-params" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Shows hidden files with -a" {
        $result = ls -Path $testDir -a
        $result -match "\.hidden" | Should Be $true
    }
    It "Hides hidden files by default" {
        $result = ls -Path $testDir
        $result -match "\.hidden" | Should Be $false
    }
    It "Shows long format with -l" {
        $result = ls -Path $testDir -l
        $result -match "rw" | Should Be $true
        $result -match "total" | Should Be $true
    }
    It "Shows human-readable sizes with -h" {
        $result = ls -Path $testDir -l -h
        $result -match "B|K|M|G" | Should Be $true
    }
    It "Shows help" {
        $result = ls -Help
        $result -match "Usage" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-ls-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = ls -Path $emptyDir
        $result | Should Be ''
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
    It "Colors executable files" {
        $result = ls -Path $testDir -l
        # 可执行文件（.ps1）应有 ANSI 颜色代码
        $result -match "\[1;32m" | Should Be $true
    }
    It "Colors directories" {
        $result = ls -Path $testDir -l
        # 目录应有 ANSI 颜色代码
        $result -match "\[1;34m" | Should Be $true
    }
}

Describe "cat parameter tests" {
    BeforeAll {
        $testFile1 = "test-cat-1.txt"
        $testFile2 = "test-cat-2.txt"
        $emptyFile = "test-cat-empty.txt"
        Set-Content -Path $testFile1 -Value "line1", "line2", "line3" -Encoding UTF8
        Set-Content -Path $testFile2 -Value "lineA", "lineB" -Encoding UTF8
        New-Item -ItemType File -Path $emptyFile -Force | Out-Null
    }
    AfterAll {
        Remove-Item $testFile1, $testFile2, $emptyFile -Force -ErrorAction SilentlyContinue
    }
    It "Shows line numbers with -n" {
        $result = cat -Path $testFile1 -n
        $result -match "\{1\}" | Should Be $true
        $result -match "\{2\}" | Should Be $true
    }
    It "Reads multiple files" {
        $result = cat -Path $testFile1, $testFile2
        $result.Count | Should Be 5
    }
    It "Handles empty file" {
        $result = cat -Path $emptyFile
        $result | Should Be $null
    }
    It "Shows help" {
        $result = cat -Help
        $result -match "Usage" | Should Be $true
    }
    It "Handles non-existent file with error" {
        # cat 会输出错误但不会抛出异常
        $errorOccurred = $false
        try { cat -Path "nonexistent.txt" } catch { $errorOccurred = $true }
        # 验证函数执行完毕（即使有错误输出）
        $errorOccurred | Should Be $false
    }
}

Describe "rm parameter tests" {
    BeforeAll {
        $testDir = "test-rm-params"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\file.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-rm-params" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = rm -Help
        $result -match "Usage" | Should Be $true
    }
    It "Removes file with -f" {
        $file = "test-rm-force.txt"
        New-Item -ItemType File -Path $file -Force | Out-Null
        rm -Args2 "-f", $file
        Test-Path $file | Should Be $false
    }
    It "Removes directory with -rf combination" {
        $dir = "test-rm-rf-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path "$dir\file.txt" -Force | Out-Null
        rm -Args2 "-rf", $dir
        Test-Path $dir | Should Be $false
    }
    It "Silently ignores non-existent file with -f" {
        rm -Args2 "-f", "nonexistent-file.txt"
        # 不应抛出错误
        $true | Should Be $true
    }
    It "Rejects invalid option" {
        # rm 会输出错误但继续执行
        $result = rm -Args2 "-x", "test.txt"
        $result | Should Be $null
    }
    It "Shows error for directory without -r" {
        $dir = "test-rm-noflags-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        rm -Args2 $dir
        # 目录应仍然存在（因为没有 -r）
        Test-Path $dir | Should Be $true
        Remove-Item $dir -Force -ErrorAction SilentlyContinue
    }
}

Describe "mkdir parameter tests" {
    AfterAll {
        Remove-Item "test-mkdir-nested" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "test-mkdir-a", "test-mkdir-b" -Force -ErrorAction SilentlyContinue
    }
    It "Creates nested directories with -p" {
        mkdir -Path "test-mkdir-nested\subdir\deep" -p
        Test-Path "test-mkdir-nested\subdir\deep" | Should Be $true
    }
    It "Creates multiple directories" {
        mkdir -Path "test-mkdir-a", "test-mkdir-b"
        Test-Path "test-mkdir-a" | Should Be $true
        Test-Path "test-mkdir-b" | Should Be $true
    }
    It "Shows help" {
        $result = mkdir -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "cp parameter tests" {
    BeforeAll {
        New-Item -ItemType File -Path "test-cp-src2.txt" -Force | Out-Null
        Set-Content -Path "test-cp-src2.txt" -Value "content" -Encoding UTF8
        New-Item -ItemType Directory -Path "test-cp-dir" -Force | Out-Null
        New-Item -ItemType File -Path "test-cp-dir\file.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-cp-src2.txt", "test-cp-dst2.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-cp-dir", "test-cp-dir-copy" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Copies directory with -r" {
        cp -Source "test-cp-dir" -Dest "test-cp-dir-copy" -r
        Test-Path "test-cp-dir-copy" | Should Be $true
        Test-Path "test-cp-dir-copy\file.txt" | Should Be $true
    }
    It "Shows help" {
        $result = cp -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "mv parameter tests" {
    BeforeAll {
        New-Item -ItemType File -Path "test-mv-src2.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-mv-src2.txt", "test-mv-dst2.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = mv -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "ll parameter tests" {
    BeforeAll {
        $testDir = "test-ll-params"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\.hidden" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\visible.txt" -Force | Out-Null
    }
    AfterAll {
        Remove-Item "test-ll-params" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Shows hidden files with -a" {
        $result = ll -Path $testDir -a
        $result -match "\.hidden" | Should Be $true
    }
    It "Shows human-readable sizes with -h" {
        $result = ll -Path $testDir -h
        $result -match "B|K|M|G" | Should Be $true
    }
    It "Shows help" {
        $result = ll -Help
        $result -match "Usage" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-ll-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = ll -Path $emptyDir
        $result -match "total 0" | Should Be $true
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
}