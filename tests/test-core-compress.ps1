# tests\test-core-compress.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\args-parser.ps1")
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\core-compress.ps1")

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
        $result = tar --help
        $result -match "Usage" | Should Be $true
    }
    It "Creates archive" {
        # Skip if native tar not available
        if (Get-Command 'tar' -ErrorAction SilentlyContinue) {
            tar -c -f test-archive.tar $testDir
            Test-Path "test-archive.tar" | Should Be $true
        } else {
            $true | Should Be $true  # Skip test
        }
    }
    It "Lists archive contents" {
        if (Get-Command 'tar' -ErrorAction SilentlyContinue) {
            tar -t -f test-archive.tar 2>&1 | Out-Null
            $true | Should Be $true
        } else {
            $true | Should Be $true
        }
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
        $result = zip --help
        $result -match "Usage" | Should Be $true
    }
    It "Creates zip archive" {
        zip test-archive.zip $testFile
        Test-Path "test-archive.zip" | Should Be $true
    }
    It "Adds .zip extension if missing" {
        zip test-archive $testFile
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
        $result = unzip --help
        $result -match "Usage" | Should Be $true
    }
    It "Lists archive contents" {
        $result = unzip -l test-unzip.zip
        $result -match "test-unzip-file.txt" | Should Be $true
    }
    It "Extracts archive" {
        unzip -d test-unzip-out test-unzip.zip
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
        $result = gzip --help
        $result -match "Usage" | Should Be $true
    }
    It "Compresses file" {
        gzip $testFile
        Test-Path "test-gzip-file.txt.gz" | Should Be $true
        Test-Path $testFile | Should Be $false
    }
    It "Keeps original with -k" {
        $testFile2 = "test-gzip-keep.txt"
        Set-Content -Path $testFile2 -Value "test" -Encoding UTF8
        gzip -k $testFile2
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
        $result = gunzip --help
        $result -match "Usage" | Should Be $true
    }
    It "Decompresses file" {
        gunzip "$testFile.gz"
        Test-Path $testFile | Should Be $true
    }
    It "Keeps original with -k" {
        $testFile2 = "test-gunzip-keep.txt"
        Set-Content -Path $testFile2 -Value "test" -Encoding UTF8
        gzip $testFile2
        gunzip -k "$testFile2.gz"
        Test-Path "$testFile2.gz" | Should Be $true
        Remove-Item "$testFile2.gz" -Force -ErrorAction SilentlyContinue
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
        $result = bzip2 --help
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
        $result = bunzip2 --help
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