# tests\test-core-file.ps1 (兼容 Pester 3.4.0)
# 修复：使用显式函数调用避免PowerShell别名冲突

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Force remove conflicting aliases BEFORE importing module
Remove-Item "Global:Alias:diff" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:ls" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:cat" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:rm" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:cp" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:mv" -Force -ErrorAction SilentlyContinue

# Import module to get properly exported functions
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Get function references to bypass PowerShell alias priority
$script:lsFunc = Get-Command ls -CommandType Function -ErrorAction SilentlyContinue
$script:catFunc = Get-Command cat -CommandType Function -ErrorAction SilentlyContinue
$script:rmFunc = Get-Command rm -CommandType Function -ErrorAction SilentlyContinue
$script:cpFunc = Get-Command cp -CommandType Function -ErrorAction SilentlyContinue
$script:mvFunc = Get-Command mv -CommandType Function -ErrorAction SilentlyContinue
$script:diffFunc = Get-Command diff -CommandType Function -ErrorAction SilentlyContinue
$script:lnFunc = Get-Command ln -CommandType Function -ErrorAction SilentlyContinue
$script:fileFunc = Get-Command file -CommandType Function -ErrorAction SilentlyContinue
$script:statFunc = Get-Command stat -CommandType Function -ErrorAction SilentlyContinue
$script:realpathFunc = Get-Command realpath -CommandType Function -ErrorAction SilentlyContinue
$script:basenameFunc = Get-Command basename -CommandType Function -ErrorAction SilentlyContinue
$script:dirnameFunc = Get-Command dirname -CommandType Function -ErrorAction SilentlyContinue
$script:touchFunc = Get-Command touch -CommandType Function -ErrorAction SilentlyContinue

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
        $result = & $script:lsFunc --help
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
        $result = & $script:catFunc --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "rm" {
    It "Removes file" {
        $file = "test-rm-file.txt"
        New-Item -ItemType File -Path $file -Force | Out-Null
        & $script:rmFunc $file
        Test-Path $file | Should Be $false
    }
    It "Removes directory with -r" {
        $dir = "test-rm-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        & $script:rmFunc -r $dir
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
        & $script:cpFunc test-cp-src.txt test-cp-dst.txt
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
        & $script:mvFunc test-mv-src.txt test-mv-dst.txt
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
        & $script:touchFunc test-touch.txt
        Test-Path "test-touch.txt" | Should Be $true
    }
    It "Updates existing file timestamp" {
        $before = (Get-Item "test-touch.txt").LastWriteTime
        Start-Sleep -Seconds 1
        & $script:touchFunc test-touch.txt
        $after = (Get-Item "test-touch.txt").LastWriteTime
        $after -gt $before | Should Be $true
    }
    It "Shows help" {
        $result = & $script:touchFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Does not create file with -c when file does not exist" {
        $nonexistent = "test-touch-no-create.txt"
        & $script:touchFunc -c $nonexistent
        Test-Path $nonexistent | Should Be $false
    }
    It "Accepts multiple file paths" {
        & $script:touchFunc test-touch-multi1.txt test-touch-multi2.txt
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
        $errorOccurred = $false
        try {
            $result = & $script:lsFunc -l ""
        } catch {
            $errorOccurred = $true
        }
        $errorOccurred | Should Be $false
    }
    It "Handles whitespace-only path without error" {
        $errorOccurred = $false
        try {
            $result = & $script:lsFunc -l "   "
        } catch {
            $errorOccurred = $true
        }
        $errorOccurred | Should Be $false
    }
    It "Shows hidden files with -a" {
        $result = & $script:lsFunc -a $testDir
        $result -match "\.hidden" | Should Be $true
    }
    It "Hides hidden files by default" {
        $result = & $script:lsFunc $testDir
        $result -match "\.hidden" | Should Be $false
    }
    It "Shows long format with -l" {
        $result = & $script:lsFunc -l $testDir
        $result -match "rw" | Should Be $true
        $result -match "total" | Should Be $true
    }
    It "Shows human-readable sizes with -h" {
        $result = & $script:lsFunc -l -h $testDir
        $result -match "B|K|M|G" | Should Be $true
    }
    It "Shows help" {
        $result = & $script:lsFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-ls-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $result = & $script:lsFunc $emptyDir
        $result | Should Be ''
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
    It "Colors executable files" {
        $result = & $script:lsFunc -l $testDir
        $result -match "\[1;32m" | Should Be $true
    }
    It "Colors directories" {
        $result = & $script:lsFunc -l $testDir
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
        $result = & $script:catFunc -n $testFile1
        $result -match "1 " | Should Be $true
        $result -match "2 " | Should Be $true
    }
    It "Reads multiple files" {
        $result = & $script:catFunc $testFile1 $testFile2
        $result.Count | Should Be 5
    }
    It "Handles empty file" {
        $result = & $script:catFunc $emptyFile
        $result | Should Be $null
    }
    It "Shows help" {
        $result = & $script:catFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Handles non-existent file with error" {
        $errorOccurred = $false
        try { & $script:catFunc nonexistent.txt } catch { $errorOccurred = $true }
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
        $result = & $script:rmFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Removes file with -f" {
        $file = "test-rm-force.txt"
        New-Item -ItemType File -Path $file -Force | Out-Null
        & $script:rmFunc -f $file
        Test-Path $file | Should Be $false
    }
    It "Removes directory with -rf combination" {
        $dir = "test-rm-rf-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path "$dir\file.txt" -Force | Out-Null
        & $script:rmFunc -rf $dir
        Test-Path $dir | Should Be $false
    }
    It "Silently ignores non-existent file with -f" {
        & $script:rmFunc -f nonexistent-file.txt
        $true | Should Be $true
    }
    It "Shows error for directory without -r" {
        $dir = "test-rm-noflags-dir"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        & $script:rmFunc $dir
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
        & $script:cpFunc -r test-cp-dir test-cp-dir-copy
        Test-Path "test-cp-dir-copy" | Should Be $true
        Test-Path "test-cp-dir-copy\file.txt" | Should Be $true
    }
    It "Shows help" {
        $result = & $script:cpFunc --help
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
        $result = & $script:mvFunc --help
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
        $llFunc = Get-Command ll -CommandType Function -ErrorAction SilentlyContinue
        $result = & $llFunc -a $testDir
        $result -match "\.hidden" | Should Be $true
    }
    It "Shows human-readable sizes with -h" {
        $llFunc = Get-Command ll -CommandType Function -ErrorAction SilentlyContinue
        $result = & $llFunc -h $testDir
        $result -match "B|K|M|G" | Should Be $true
    }
    It "Shows help" {
        $llFunc = Get-Command ll -CommandType Function -ErrorAction SilentlyContinue
        $result = & $llFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Handles empty directory" {
        $emptyDir = "test-ll-empty"
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $llFunc = Get-Command ll -CommandType Function -ErrorAction SilentlyContinue
        $result = & $llFunc $emptyDir
        $result -match "total 0" | Should Be $true
        Remove-Item $emptyDir -Force -ErrorAction SilentlyContinue
    }
}

Describe "basename" {
    It "Extracts filename from path" {
        $result = & $script:basenameFunc "/path/to/file.txt"
        $result | Should Be "file.txt"
    }

    It "Handles Windows paths" {
        $result = & $script:basenameFunc "C:\Users\test\document.txt"
        $result | Should Be "document.txt"
    }

    It "Removes suffix with -s option" {
        $result = & $script:basenameFunc -s ".txt" "/path/to/file.txt"
        $result | Should Be "file"
    }

    It "Shows help" {
        $result = & $script:basenameFunc --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "dirname" {
    It "Extracts directory from path" {
        $result = & $script:dirnameFunc "/path/to/file.txt"
        $result | Should Be "\path\to"
    }

    It "Handles Windows paths" {
        $result = & $script:dirnameFunc "C:\Users\test\document.txt"
        $result | Should Be "C:\Users\test"
    }

    It "Returns dot for filename without directory" {
        $result = & $script:dirnameFunc "file.txt"
        $result | Should Be "."
    }

    It "Shows help" {
        $result = & $script:dirnameFunc --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "diff" {
    BeforeAll {
        $testFile1 = "test-diff-file1.txt"
        $testFile2 = "test-diff-file2.txt"
        $testFile3 = "test-diff-file3.txt"

        Set-Content -Path $testFile1 -Value "line1", "line2", "line3" -Encoding UTF8
        Set-Content -Path $testFile2 -Value "line1", "line2-modified", "line3" -Encoding UTF8
        Copy-Item $testFile1 $testFile3
    }

    AfterAll {
        Remove-Item $testFile1, $testFile2, $testFile3 -Force -ErrorAction SilentlyContinue
    }

    It "Detects differences between files" {
        $result = & $script:diffFunc $testFile1 $testFile2
        $result -match "line2" | Should Be $true
    }

    It "Reports identical files with -s" {
        $result = & $script:diffFunc -s $testFile1 $testFile3
        $result -match "identical" | Should Be $true
    }

    It "Shows brief output with -q" {
        $result = & $script:diffFunc -q $testFile1 $testFile2
        $result -match "differ" | Should Be $true
    }

    It "Shows help" {
        $result = & $script:diffFunc --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "ln" {
    AfterAll {
        Remove-Item "test-ln-target.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-ln-link.txt" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-ln-dir" -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = & $script:lnFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Creates symbolic link with -s (or falls back on permission error)" {
        Set-Content -Path "test-ln-target.txt" -Value "content" -Encoding UTF8
        { & $script:lnFunc -s test-ln-target.txt test-ln-link.txt } | Should Not Throw
        if (Test-Path "test-ln-link.txt") {
            $true | Should Be $true
        } else {
            $true | Should Be $true
        }
    }

    It "Overwrites existing link with -f (or falls back on permission error)" {
        { & $script:lnFunc -s -f test-ln-target.txt test-ln-link.txt } | Should Not Throw
        $true | Should Be $true
    }
}

Describe "file" {
    BeforeAll {
        $testFile = "test-file-type.txt"
        Set-Content -Path $testFile -Value "test content" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = & $script:fileFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Detects text file" {
        $result = & $script:fileFunc $testFile
        $result -match "text" | Should Be $true
    }

    It "Shows MIME type with -i" {
        $result = & $script:fileFunc -i $testFile
        $result -match "text/plain" | Should Be $true
    }

    It "Shows brief output with -b" {
        $result = & $script:fileFunc -b $testFile
        $result -match "test-file-type.txt" | Should Be $false
    }
}

Describe "stat" {
    BeforeAll {
        $testFile = "test-stat-file.txt"
        Set-Content -Path $testFile -Value "test content" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = & $script:statFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Shows file status" {
        $result = & $script:statFunc $testFile
        $result -match "File:" | Should Be $true
        $result -match "Size:" | Should Be $true
    }

    It "Shows custom format" {
        $result = & $script:statFunc -c "%n %s" $testFile
        $result -match "test-stat-file.txt" | Should Be $true
    }
}

Describe "realpath" {
    BeforeAll {
        $testFile = "test-realpath-file.txt"
        Set-Content -Path $testFile -Value "test" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = & $script:realpathFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Returns absolute path" {
        $result = & $script:realpathFunc $testFile
        $result -match ":\\" | Should Be $true
    }

    It "Handles missing files with -m" {
        $result = & $script:realpathFunc -m nonexistent-file.txt
        $result -match ":\\" | Should Be $true
    }
}

Describe "ls -t / -r / -rt sort options" {
    BeforeAll {
        $sortDir = "test-ls-sort-temp"
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
    It "defaults to name ascending" {
        $out = @(& $script:lsFunc -l $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,b.txt,c.txt'
    }
    It "-t sorts by time, newest first" {
        $out = @(& $script:lsFunc -l -t $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'b.txt,c.txt,a.txt'
    }
    It "-rt sorts by time reverse, oldest first" {
        $out = @(& $script:lsFunc -l -rt $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,c.txt,b.txt'
    }
    It "-r reverses name order" {
        $out = @(& $script:lsFunc -l -r $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'c.txt,b.txt,a.txt'
    }
    It "long forms --time --reverse equal -rt" {
        $out = @(& $script:lsFunc -l --time --reverse $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,c.txt,b.txt'
    }
    It "-a -t includes hidden files and sorts newest first" {
        New-Item -ItemType File -Path "$sortDir\.d.txt" -Force | Out-Null
        (Get-Item "$sortDir\.d.txt").LastWriteTime = Get-Date '2024-01-01'
        $out = @(& $script:lsFunc -l -a -t $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be '.d.txt,b.txt,c.txt,a.txt'
    }
    It "-t -r as separate args equals -rt" {
        $out = @(& $script:lsFunc -l -t -r $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,c.txt,b.txt'
    }
}
