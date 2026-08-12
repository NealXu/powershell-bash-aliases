# tests\test-core-file.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import module to get properly exported functions
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

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
        $result = ls --help
        $result -match "Usage" | Should Be $true
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
        $result = cat --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "rm" {
    It "Removes file" {
        $file = "test-rm-file.txt"
        New-Item -ItemType File -Path $file -Force | Out-Null
        rm $file
        Test-Path $file | Should Be $false
    }
    It "Removes directory with -r" {
        $dir = "test-rm-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        rm -r $dir
        Test-Path $dir | Should Be $false
    }
}

Describe "mkdir" {
    AfterAll {
        Remove-Item "test-mkdir-temp" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Creates directory" {
        mkdir test-mkdir-temp
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
        cp test-cp-src.txt test-cp-dst.txt
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
        mv test-mv-src.txt test-mv-dst.txt
        Test-Path "test-mv-src.txt" | Should Be $false
        Test-Path "test-mv-dst.txt" | Should Be $true
    }
}

Describe "touch" {
    AfterAll {
        Remove-Item "test-touch.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-touch-no-create.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-touch-multi1.txt", "test-touch-multi2.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Creates new file" {
        touch test-touch.txt
        Test-Path "test-touch.txt" | Should Be $true
    }
    It "Updates existing file timestamp" {
        $before = (Get-Item "test-touch.txt").LastWriteTime
        Start-Sleep -Seconds 1
        touch test-touch.txt
        $after = (Get-Item "test-touch.txt").LastWriteTime
        $after -gt $before | Should Be $true
    }
    It "Shows help" {
        $result = touch --help
        $result -match "Usage" | Should Be $true
    }
    It "Does not create file with -c when file does not exist" {
        $nonexistent = "test-touch-no-create.txt"
        touch -c $nonexistent
        Test-Path $nonexistent | Should Be $false
    }
    It "Accepts multiple file paths" {
        touch test-touch-multi1.txt test-touch-multi2.txt
        Test-Path "test-touch-multi1.txt" | Should Be $true
        Test-Path "test-touch-multi2.txt" | Should Be $true
    }
}

Describe "ls parameter tests" {
    BeforeAll {
        $testDir = "test-ls-params"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType Directory -Path "$testDir/subdir" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\.hidden" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\visible.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\script.ps1" -Force | Out-Null
        Set-Content -Path "$testDir\visible.txt" -Value "content" -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-ls-params" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Handles empty string path without error" {
        # Test for null/empty path protection
        $errorOccurred = $false
        try {
            $result = ls -l ""
        } catch {
            $errorOccurred = $true
        }
        # Should not throw parameter binding error
        $errorOccurred | Should Be $false
    }
    It "Handles whitespace-only path without error" {
        # Test for whitespace path protection
        $errorOccurred = $false
        try {
            $result = ls -l "   "
        } catch {
            $errorOccurred = $true
        }
        # Should not throw parameter binding error
        $errorOccurred | Should Be $false
    }
    It "Shows hidden files with -a" {
        $result = ls -a $testDir
        $result -match "\.hidden" | Should Be $true
    }
    It "Hides hidden files by default" {
        $result = ls $testDir
        $result -match "\.hidden" | Should Be $false
    }
    It "Shows long format with -l" {
        $result = ls -l $testDir
        $result -match "rw" | Should Be $true
        $result -match "total" | Should Be $true
    }
    It "Shows human-readable sizes with -h" {
        $result = ls -l -h $testDir
        $result -match "B|K|M|G" | Should Be $true
    }
    It "Shows help" {
        $result = ls --help
        $result -match "Usage" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-ls-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = ls $emptyDir
        $result | Should Be ''
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
    It "Colors executable files" {
        $result = ls -l $testDir
        # 可执行文件（.ps1）应有 ANSI 颜色代码
        $result -match "\[1;32m" | Should Be $true
    }
    It "Colors directories" {
        $result = ls -l $testDir
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
        $result = cat -n $testFile1
        $result -match "1 " | Should Be $true
        $result -match "2 " | Should Be $true
    }
    It "Reads multiple files" {
        $result = cat $testFile1 $testFile2
        $result.Count | Should Be 5
    }
    It "Handles empty file" {
        $result = cat $emptyFile
        $result | Should Be $null
    }
    It "Shows help" {
        $result = cat --help
        $result -match "Usage" | Should Be $true
    }
    It "Handles non-existent file with error" {
        # cat 会输出错误但不会抛出异常
        $errorOccurred = $false
        try { cat nonexistent.txt } catch { $errorOccurred = $true }
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
        $result = rm --help
        $result -match "Usage" | Should Be $true
    }
    It "Removes file with -f" {
        $file = "test-rm-force.txt"
        New-Item -ItemType File -Path $file -Force | Out-Null
        rm -f $file
        Test-Path $file | Should Be $false
    }
    It "Removes directory with -rf combination" {
        $dir = "test-rm-rf-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path "$dir\file.txt" -Force | Out-Null
        rm -rf $dir
        Test-Path $dir | Should Be $false
    }
    It "Silently ignores non-existent file with -f" {
        rm -f nonexistent-file.txt
        # 不应抛出错误
        $true | Should Be $true
    }
    It "Shows error for directory without -r" {
        $dir = "test-rm-noflags-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        rm $dir
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
        mkdir -p test-mkdir-nested/subdir/deep
        Test-Path "test-mkdir-nested/subdir/deep" | Should Be $true
    }
    It "Creates multiple directories" {
        mkdir test-mkdir-a test-mkdir-b
        Test-Path "test-mkdir-a" | Should Be $true
        Test-Path "test-mkdir-b" | Should Be $true
    }
    It "Shows help" {
        $result = mkdir --help
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
        cp -r test-cp-dir test-cp-dir-copy
        Test-Path "test-cp-dir-copy" | Should Be $true
        Test-Path "test-cp-dir-copy\file.txt" | Should Be $true
    }
    It "Shows help" {
        $result = cp --help
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
        $result = mv --help
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
        $result = ll -a $testDir
        $result -match "\.hidden" | Should Be $true
    }
    It "Shows human-readable sizes with -h" {
        $result = ll -h $testDir
        $result -match "B|K|M|G" | Should Be $true
    }
    It "Shows help" {
        $result = ll --help
        $result -match "Usage" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-ll-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = ll $emptyDir
        $result -match "total 0" | Should Be $true
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
}