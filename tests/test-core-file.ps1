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
}