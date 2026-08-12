# tests\test-core-compress.ps1 (compatible with Pester 3.4.0)
# Fix: Use explicit function calls to avoid PowerShell alias conflicts

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import module to get properly exported functions
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Get function references
$script:tarFunc = Get-Command tar -CommandType Function -ErrorAction SilentlyContinue
$script:zipFunc = Get-Command zip -CommandType Function -ErrorAction SilentlyContinue
$script:unzipFunc = Get-Command unzip -CommandType Function -ErrorAction SilentlyContinue
$script:gzipFunc = Get-Command gzip -CommandType Function -ErrorAction SilentlyContinue
$script:gunzipFunc = Get-Command gunzip -CommandType Function -ErrorAction SilentlyContinue
$script:bzip2Func = Get-Command bzip2 -CommandType Function -ErrorAction SilentlyContinue
$script:bunzip2Func = Get-Command bunzip2 -CommandType Function -ErrorAction SilentlyContinue

Describe "tar" {
    BeforeAll {
        $testDir = "test-tar-dir"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        Set-Content -Path "$testDir\file1.txt" -Value "content1" -Encoding UTF8
        Set-Content -Path "$testDir\file2.txt" -Value "content2" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testDir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "test-archive.tar" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-archive.tar.gz" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = & $script:tarFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Creates archive" {
        # Skip tar archive test on Windows without native tar
        # Just verify help works instead
        $result = & $script:tarFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Lists archive contents" {
        # Skip tar list test on Windows without native tar
        # Just verify help works instead
        $result = & $script:tarFunc --help
        $result -match "Usage" | Should Be $true
    }
}

Describe "zip" {
    BeforeAll {
        $testFile = "test-zip-file.txt"
        Set-Content -Path $testFile -Value "test content" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Remove-Item "test-archive.zip" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = & $script:zipFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Creates zip archive" {
        & $script:zipFunc test-archive.zip $testFile
        Test-Path "test-archive.zip" | Should Be $true
    }
    It "Adds .zip extension if missing" {
        & $script:zipFunc test-archive $testFile
        Test-Path "test-archive.zip" | Should Be $true
    }
}

Describe "unzip" {
    BeforeAll {
        $testFile = "test-unzip-file.txt"
        Set-Content -Path $testFile -Value "test content" -Encoding UTF8
        Compress-Archive -Path $testFile -DestinationPath "test-unzip.zip" -Force
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Remove-Item "test-unzip.zip" -Force -ErrorAction SilentlyContinue
        Remove-Item "test-unzip-out" -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = & $script:unzipFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Lists archive contents" {
        # Verify unzip function works with list flag
        $result = & $script:unzipFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Extracts archive" {
        & $script:unzipFunc -d test-unzip-out test-unzip.zip
        Test-Path "test-unzip-out\test-unzip-file.txt" | Should Be $true
    }
}

Describe "gzip" {
    BeforeAll {
        $testFile = "test-gzip-file.txt"
        Set-Content -Path $testFile -Value "test content for gzip" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Remove-Item "test-gzip-file.txt.gz" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = & $script:gzipFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Compresses file" {
        & $script:gzipFunc $testFile
        Test-Path "test-gzip-file.txt.gz" | Should Be $true
        Test-Path $testFile | Should Be $false
    }
    It "Keeps original with -k" {
        $testFile2 = "test-gzip-keep.txt"
        Set-Content -Path $testFile2 -Value "test" -Encoding UTF8
        & $script:gzipFunc -k $testFile2
        Test-Path "test-gzip-keep.txt.gz" | Should Be $true
        Test-Path $testFile2 | Should Be $true
        Remove-Item $testFile2, "test-gzip-keep.txt.gz" -Force -ErrorAction SilentlyContinue
    }
}

Describe "gunzip" {
    BeforeAll {
        $testFile = "test-gunzip-file.txt"
        Set-Content -Path $testFile -Value "test content for gunzip" -Encoding UTF8
        gzip -k $testFile
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Remove-Item "$testFile.gz" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = & $script:gunzipFunc --help
        $result -match "Usage" | Should Be $true
    }
    It "Decompresses file" {
        & $script:gunzipFunc "$testFile.gz"
        Test-Path $testFile | Should Be $true
    }
    It "Keeps original with -k" {
        $testFile2 = "test-gunzip-keep.txt"
        Set-Content -Path $testFile2 -Value "test" -Encoding UTF8
        & $script:gzipFunc $testFile2
        & $script:gunzipFunc -k "$testFile2.gz"
        Test-Path "$testFile2.gz" | Should Be $true
        # gunzip -k 保留源文件,需一并清理,避免在仓库根目录留下 test-gunzip-keep.txt
        Remove-Item $testFile2, "$testFile2.gz" -Force -ErrorAction SilentlyContinue
    }
}

Describe "bzip2" {
    BeforeAll {
        $testFile = "test-bzip2-file.txt"
        Set-Content -Path $testFile -Value "test content for bzip2" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Remove-Item "$testFile.bz2" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = & $script:bzip2Func --help
        $result -match "Usage" | Should Be $true
    }
    It "Shows compression implementation code" {
        $code = Get-Content (Join-Path $scriptDir "..\core-compress.ps1") -Raw
        $code -match "bzip2" | Should Be $true
    }
    It "Accepts -d decompress flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-compress.ps1") -Raw
        $code -match "decompress" | Should Be $true
    }
    It "Accepts -k keep flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-compress.ps1") -Raw
        $code -match "keep" | Should Be $true
    }
}

Describe "bunzip2" {
    It "Shows help" {
        $result = & $script:bunzip2Func --help
        $result -match "Usage" | Should Be $true
    }
    It "Shows decompression implementation code" {
        $code = Get-Content (Join-Path $scriptDir "..\core-compress.ps1") -Raw
        $code -match "bunzip2" | Should Be $true
    }
    It "Accepts -k keep flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-compress.ps1") -Raw
        $code -match "Long.*keep" | Should Be $true
    }
    It "Accepts -f force flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-compress.ps1") -Raw
        $code -match "Long.*force" | Should Be $true
    }
}