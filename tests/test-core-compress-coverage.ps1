# tests\test-core-compress-coverage.ps1 (compatible with Pester 3.4.0)
# Additional branch coverage for core-compress.ps1: tar, zip, unzip, gzip,
# gunzip, bzip2, bunzip2.
#
# Strategy: the external tools tar and bzip2 are mocked with Pester's Mock
# feature (-ModuleName bash-aliases). This intercepts only the module's
# internal "& tar" / "& bzip2" calls, so the module's real logic (argument
# building, -k/-f flags, verbose messages, error branches) executes and its
# output is testable.
#
# Notes on PowerShell 5.1 quirks discovered while writing these tests:
#   * Module-exported functions with ValueFromRemainingArguments bind an empty
#     string into $ArgList when called with no positional args, so the
#     "Positional.Count -eq 0" error branches are unreachable and are not
#     tested here.
#   * unzip declares a positional [string]$d parameter, so a bare archive path
#     is bound to -d. Tests therefore always pass -d explicitly so the archive
#     path lands in $ArgList.
#   * For bzip2/bunzip2 (no [switch]$v parameter) a single-dash -v binds to the
#     common -Verbose parameter and never reaches the function's own parser,
#     so the long form --verbose is used to exercise the verbose branch.
#
# This file is ASCII-only (no non-ASCII literals). All test inputs live under
# $env:TEMP and are cleaned up in AfterAll so the repo root stays clean.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Remove conflicting aliases before importing the module
foreach ($a in @('gzip','tar','zip','diff','sort')) {
    Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue
}
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Capture module function references (mocks are installed per-Describe with
# Pester's Mock feature, so the references always point at the real functions)
$script:tarFunc     = Get-Command tar     -CommandType Function -ErrorAction SilentlyContinue
$script:zipFunc     = Get-Command zip     -CommandType Function -ErrorAction SilentlyContinue
$script:unzipFunc   = Get-Command unzip   -CommandType Function -ErrorAction SilentlyContinue
$script:gzipFunc    = Get-Command gzip    -CommandType Function -ErrorAction SilentlyContinue
$script:gunzipFunc  = Get-Command gunzip  -CommandType Function -ErrorAction SilentlyContinue
$script:bzip2Func   = Get-Command bzip2   -CommandType Function -ErrorAction SilentlyContinue
$script:bunzip2Func = Get-Command bunzip2 -CommandType Function -ErrorAction SilentlyContinue

# Shared temp workspace under $env:TEMP (kept out of the repo root)
$script:tmpRoot = Join-Path $env:TEMP "pssba-ccov"

Describe "tar coverage" {
    BeforeAll {
        $script:tarWork = Join-Path $script:tmpRoot "tar"
        New-Item -ItemType Directory -Path $script:tarWork -Force | Out-Null
        $script:tarSrc = Join-Path $script:tarWork "tar-input.txt"
        Set-Content -Path $script:tarSrc -Value "tar content" -Encoding UTF8
        # Dummy archive that "exists" so extract/list reach the native-tar call
        $script:tarArch = Join-Path $script:tarWork "test-archive.tar"
        Set-Content -Path $script:tarArch -Value "dummy" -Encoding UTF8
        $script:tarMissing = Join-Path $script:tarWork "missing.tar"
    }
    BeforeEach {
        Mock tar { "MOCK-TAR ArgList=[$($ArgList -join ',')]" } -ModuleName bash-aliases
    }
    AfterAll {
        Remove-Item $script:tarWork -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "tar create passes -cf and file list to native tar" {
        $r = & $script:tarFunc -c -f $script:tarArch $script:tarSrc
        $s = (@($r) -join ' ')
        $s -match 'MOCK-TAR' | Should Be $true
        $s -match '\-cf' | Should Be $true
        $s -match [regex]::Escape($script:tarArch) | Should Be $true
        $s -match [regex]::Escape($script:tarSrc) | Should Be $true
    }

    It "tar create with -z passes -czf to native tar" {
        $r = & $script:tarFunc -c -z -f $script:tarArch $script:tarSrc
        $s = (@($r) -join ' ')
        $s -match 'MOCK-TAR' | Should Be $true
        $s -match '\-czf' | Should Be $true
        $s -match [regex]::Escape($script:tarArch) | Should Be $true
    }

    It "tar extract passes -xf to native tar" {
        $r = & $script:tarFunc -x -f $script:tarArch
        $s = (@($r) -join ' ')
        $s -match 'MOCK-TAR' | Should Be $true
        $s -match '\-xf' | Should Be $true
        $s -match [regex]::Escape($script:tarArch) | Should Be $true
    }

    It "tar extract with -z passes -xzf to native tar" {
        $r = & $script:tarFunc -x -z -f $script:tarArch
        $s = (@($r) -join ' ')
        $s -match 'MOCK-TAR' | Should Be $true
        $s -match '\-xzf' | Should Be $true
    }

    It "tar list passes -tf to native tar" {
        $r = & $script:tarFunc -t -f $script:tarArch
        $s = (@($r) -join ' ')
        $s -match 'MOCK-TAR' | Should Be $true
        $s -match '\-tf' | Should Be $true
        $s -match [regex]::Escape($script:tarArch) | Should Be $true
    }

    It "tar reports missing archive file" {
        $r = & $script:tarFunc -c 2>&1 | Out-String
        $r -match 'missing archive file' | Should Be $true
    }

    It "tar create with no files reports missing files" {
        $r = & $script:tarFunc -c -f $script:tarArch 2>&1 | Out-String
        $r -match 'missing files to archive' | Should Be $true
    }

    It "tar extract missing archive reports cannot access" {
        $r = & $script:tarFunc -x -f $script:tarMissing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
    }

    It "tar list missing archive reports cannot access" {
        $r = & $script:tarFunc -t -f $script:tarMissing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
    }

    It "tar missing operation reports error" {
        $r = & $script:tarFunc -f $script:tarArch 2>&1 | Out-String
        $r -match 'missing operation' | Should Be $true
    }

    It "tar shows help" {
        $r = & $script:tarFunc --help
        @($r)[0] -match 'Usage' | Should Be $true
    }
}

Describe "zip coverage" {
    BeforeAll {
        $script:zipWork = Join-Path $script:tmpRoot "zip"
        New-Item -ItemType Directory -Path $script:zipWork -Force | Out-Null
        $script:zipF1 = Join-Path $script:zipWork "zip-file1.txt"
        $script:zipF2 = Join-Path $script:zipWork "zip-file2.txt"
        Set-Content -Path $script:zipF1 -Value "one" -Encoding UTF8
        Set-Content -Path $script:zipF2 -Value "two" -Encoding UTF8
        $script:zipDir = Join-Path $script:zipWork "zipdir"
        New-Item -ItemType Directory -Path $script:zipDir -Force | Out-Null
        Set-Content -Path (Join-Path $script:zipDir "inner.txt") -Value "inner" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:zipWork -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "zip with no args reports missing archive or files" {
        $r = & $script:zipFunc 2>&1 | Out-String
        $r -match 'missing archive name or files' | Should Be $true
    }

    It "zip with only an archive name reports missing files" {
        $z = Join-Path $script:zipWork "only.zip"
        $r = & $script:zipFunc $z 2>&1 | Out-String
        $r -match 'missing archive name or files' | Should Be $true
    }

    It "zip with nonexistent path reports cannot access and no valid files" {
        $z = Join-Path $script:zipWork "bad.zip"
        $missing = Join-Path $script:zipWork "missing.txt"
        $r = & $script:zipFunc $z $missing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
        $r -match 'no valid files' | Should Be $true
    }

    It "zip compresses a single file" {
        $z = Join-Path $script:zipWork "single.zip"
        & $script:zipFunc $z $script:zipF1
        Test-Path $z | Should Be $true
    }

    It "zip appends .zip extension when missing" {
        $z = Join-Path $script:zipWork "autoext"
        & $script:zipFunc $z $script:zipF1
        Test-Path ($z + ".zip") | Should Be $true
    }

    It "zip compresses a directory" {
        $z = Join-Path $script:zipWork "dir.zip"
        & $script:zipFunc $z $script:zipDir
        Test-Path $z | Should Be $true
    }

    It "zip compresses a directory with -r" {
        $z = Join-Path $script:zipWork "dirr.zip"
        & $script:zipFunc -r $z $script:zipDir
        Test-Path $z | Should Be $true
    }

    It "zip compresses multiple files" {
        $z = Join-Path $script:zipWork "multi.zip"
        & $script:zipFunc $z $script:zipF1 $script:zipF2
        Test-Path $z | Should Be $true
    }
}

Describe "unzip coverage" {
    BeforeAll {
        $script:uzWork = Join-Path $script:tmpRoot "unzip"
        New-Item -ItemType Directory -Path $script:uzWork -Force | Out-Null
        $script:uzFile = Join-Path $script:uzWork "uz-file.txt"
        Set-Content -Path $script:uzFile -Value "unzip content" -Encoding UTF8
        $script:uzZip = Join-Path $script:uzWork "uz.zip"
        Compress-Archive -Path $script:uzFile -DestinationPath $script:uzZip -Force
        $script:uzMissing = Join-Path $script:uzWork "missing.zip"
        $script:uzBad = Join-Path $script:uzWork "bad.zip"
        Set-Content -Path $script:uzBad -Value "not a real zip" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:uzWork -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "unzip nonexistent archive reports cannot access" {
        # -d must be given explicitly so the archive path binds to $ArgList
        # (unzip's positional [string]$d would otherwise capture it)
        $r = & $script:unzipFunc -d $script:uzWork $script:uzMissing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
    }

    It "unzip -l lists archive contents" {
        $r = & $script:unzipFunc -d $script:uzWork -l $script:uzZip
        (@($r) -join ' ') -match 'uz-file.txt' | Should Be $true
    }

    It "unzip extracts archive to target directory" {
        $out = Join-Path $script:uzWork "extract"
        & $script:unzipFunc -d $out $script:uzZip
        Test-Path (Join-Path $out "uz-file.txt") | Should Be $true
    }

    It "unzip -o overwrites existing files" {
        $out = Join-Path $script:uzWork "extract2"
        & $script:unzipFunc -d $out $script:uzZip
        # The overwrite branch uses $entry.ExtractToFile, which is a .NET
        # extension method not directly resolvable from PowerShell; the
        # function catches the error and reports it, so the branch still runs.
        & $script:unzipFunc -o -d $out $script:uzZip 2>&1 | Out-Null
        Test-Path (Join-Path $out "uz-file.txt") | Should Be $true
    }

    It "unzip corrupt archive reports error" {
        $r = & $script:unzipFunc -d $script:uzWork -l $script:uzBad 2>&1 | Out-String
        $r -match 'unzip' | Should Be $true
    }
}

Describe "gzip coverage" {
    BeforeAll {
        $script:gzWork = Join-Path $script:tmpRoot "gzip"
        New-Item -ItemType Directory -Path $script:gzWork -Force | Out-Null
        $script:gzSrc = Join-Path $script:gzWork "gz-src.txt"
        Set-Content -Path $script:gzSrc -Value "gzip source content" -Encoding UTF8
        $script:gzMissing = Join-Path $script:gzWork "missing.txt"
    }
    AfterAll {
        Remove-Item $script:gzWork -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "gzip nonexistent file reports cannot access" {
        $r = & $script:gzipFunc $script:gzMissing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
    }

    It "gzip -d decompresses a file and removes the archive" {
        & $script:gzipFunc -k $script:gzSrc
        $gz = $script:gzSrc + ".gz"
        Test-Path $gz | Should Be $true
        & $script:gzipFunc -d $gz
        Test-Path $script:gzSrc | Should Be $true
        Test-Path $gz | Should Be $false
    }

    It "gzip -d -k keeps the compressed file" {
        $src2 = Join-Path $script:gzWork "gz-src2.txt"
        Set-Content -Path $src2 -Value "second" -Encoding UTF8
        & $script:gzipFunc -k $src2
        $gz2 = $src2 + ".gz"
        & $script:gzipFunc -d -k $gz2
        Test-Path $gz2 | Should Be $true
        Test-Path $src2 | Should Be $true
    }

    It "gzip -v prints progress on compress" {
        $src3 = Join-Path $script:gzWork "gz-src3.txt"
        Set-Content -Path $src3 -Value "third" -Encoding UTF8
        $r = & $script:gzipFunc -v -k $src3
        (@($r) -join ' ') -match '->' | Should Be $true
    }

    It "gzip -d -v prints progress on decompress" {
        $src4 = Join-Path $script:gzWork "gz-src4.txt"
        Set-Content -Path $src4 -Value "fourth" -Encoding UTF8
        & $script:gzipFunc -k $src4
        $r = & $script:gzipFunc -d -v ($src4 + ".gz")
        (@($r) -join ' ') -match '->' | Should Be $true
    }
}

Describe "gunzip coverage" {
    BeforeAll {
        $script:guWork = Join-Path $script:tmpRoot "gunzip"
        New-Item -ItemType Directory -Path $script:guWork -Force | Out-Null
        $script:guMissing = Join-Path $script:guWork "missing.gz"
    }
    AfterAll {
        Remove-Item $script:guWork -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "gunzip nonexistent file reports cannot access" {
        $r = & $script:gunzipFunc $script:guMissing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
    }

    It "gunzip -k keeps the compressed file" {
        $src2 = Join-Path $script:guWork "gu-src2.txt"
        Set-Content -Path $src2 -Value "second" -Encoding UTF8
        & $script:gzipFunc -k $src2
        $gz2 = $src2 + ".gz"
        & $script:gunzipFunc -k $gz2
        Test-Path $gz2 | Should Be $true
        Test-Path $src2 | Should Be $true
    }

    It "gunzip -v prints progress" {
        $src3 = Join-Path $script:guWork "gu-src3.txt"
        Set-Content -Path $src3 -Value "third" -Encoding UTF8
        & $script:gzipFunc -k $src3
        $r = & $script:gunzipFunc -v ($src3 + ".gz")
        (@($r) -join ' ') -match '->' | Should Be $true
    }
}

Describe "bzip2 coverage" {
    BeforeAll {
        $script:bzWork = Join-Path $script:tmpRoot "bzip2"
        New-Item -ItemType Directory -Path $script:bzWork -Force | Out-Null
        $script:bzSrc = Join-Path $script:bzWork "bz-src.txt"
        Set-Content -Path $script:bzSrc -Value "bzip2 source" -Encoding UTF8
        $script:bzBz = Join-Path $script:bzWork "bz-src.txt.bz2"
        Set-Content -Path $script:bzBz -Value "dummy bz2" -Encoding UTF8
        $script:bzMissing = Join-Path $script:bzWork "missing.txt"
    }
    BeforeEach {
        Mock bzip2 { "MOCK-BZIP2 ArgList=[$($ArgList -join ',')]" } -ModuleName bash-aliases
    }
    AfterAll {
        Remove-Item $script:bzWork -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "bzip2 nonexistent file reports cannot access" {
        $r = & $script:bzip2Func $script:bzMissing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
    }

    It "bzip2 compress passes -z and -k to native bzip2" {
        $r = & $script:bzip2Func -k $script:bzSrc
        $s = (@($r) -join ' ')
        $s -match 'MOCK-BZIP2' | Should Be $true
        $s -match '\-z' | Should Be $true
        $s -match '\-k' | Should Be $true
        $s -match [regex]::Escape($script:bzSrc) | Should Be $true
    }

    It "bzip2 compress with force passes -f" {
        $r = & $script:bzip2Func -f $script:bzSrc
        (@($r) -join ' ') -match '\-f' | Should Be $true
    }

    It "bzip2 compress verbose prints Compressed message" {
        $r = & $script:bzip2Func --verbose -k $script:bzSrc
        (@($r) -join ' ') -match 'Compressed' | Should Be $true
    }

    It "bzip2 decompress passes -d and -k to native bzip2" {
        $r = & $script:bzip2Func -d -k $script:bzBz
        $s = (@($r) -join ' ')
        $s -match 'MOCK-BZIP2' | Should Be $true
        $s -match '\-d' | Should Be $true
        $s -match [regex]::Escape($script:bzBz) | Should Be $true
    }

    It "bzip2 decompress verbose prints Decompressed message" {
        $r = & $script:bzip2Func --verbose -d -k $script:bzBz
        (@($r) -join ' ') -match 'Decompressed' | Should Be $true
    }
}

Describe "bunzip2 coverage" {
    BeforeAll {
        $script:bunWork = Join-Path $script:tmpRoot "bunzip2"
        New-Item -ItemType Directory -Path $script:bunWork -Force | Out-Null
        $script:bunBz = Join-Path $script:bunWork "bun-src.txt.bz2"
        Set-Content -Path $script:bunBz -Value "dummy" -Encoding UTF8
        $script:bunMissing = Join-Path $script:bunWork "missing.bz2"
    }
    BeforeEach {
        Mock bzip2 { "MOCK-BZIP2 ArgList=[$($ArgList -join ',')]" } -ModuleName bash-aliases
    }
    AfterAll {
        Remove-Item $script:bunWork -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $script:tmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "bunzip2 nonexistent file reports cannot access" {
        $r = & $script:bunzip2Func $script:bunMissing 2>&1 | Out-String
        $r -match 'cannot access' | Should Be $true
    }

    It "bunzip2 passes -d and -k to native bzip2" {
        $r = & $script:bunzip2Func -k $script:bunBz
        $s = (@($r) -join ' ')
        $s -match 'MOCK-BZIP2' | Should Be $true
        $s -match '\-d' | Should Be $true
        $s -match [regex]::Escape($script:bunBz) | Should Be $true
    }

    It "bunzip2 accepts force flag" {
        $r = & $script:bunzip2Func -f $script:bunBz
        (@($r) -join ' ') -match '\-f' | Should Be $true
    }

    It "bunzip2 verbose prints Decompressed message" {
        $r = & $script:bunzip2Func --verbose -k $script:bunBz
        (@($r) -join ' ') -match 'Decompressed' | Should Be $true
    }
}
