# tests\test-core-text-fixes.ps1
# Regression tests for production bugs in core-text.ps1.
# Compatible with Pester 3.4.0 and Windows PowerShell 5.1.
# IMPORTANT: This file is ASCII-only. Do not insert non-ASCII literals.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Remove conflicting aliases so the module's functions win.
foreach ($a in @('sort','cat','ls','rm','cp','mv')) {
    Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue
}

Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

$script:headFunc  = Get-Command head  -CommandType Function -ErrorAction SilentlyContinue
$script:uniqFunc  = Get-Command uniq  -CommandType Function -ErrorAction SilentlyContinue
$script:cutFunc   = Get-Command cut   -CommandType Function -ErrorAction SilentlyContinue
$script:trFunc    = Get-Command tr    -CommandType Function -ErrorAction SilentlyContinue
$script:awkFunc   = Get-Command awk   -CommandType Function -ErrorAction SilentlyContinue
$script:patchFunc = Get-Command patch -CommandType Function -ErrorAction SilentlyContinue

Describe "pipeline input" {
    It "uniq accepts pipeline input" {
        $r = @('b','a','b','a') | & $script:uniqFunc
        $r -join '|' | Should Be 'a|b'
    }
    It "tr translates characters from the pipeline" {
        $r = 'hello' | & $script:trFunc 'l' 'x'
        @($r)[0] | Should Be 'hexxo'
    }
    It "tr deletes characters from the pipeline" {
        $r = 'hello' | & $script:trFunc -d 'l'
        @($r)[0] | Should Be 'heo'
    }
    It "awk prints the first field from the pipeline" {
        $r = 'x y z' | & $script:awkFunc '{print $1}'
        @($r)[0] | Should Be 'x'
    }
    It "cut extracts a field from the pipeline" {
        $r = 'a,b,c' | & $script:cutFunc -d ',' -f '2'
        @($r)[0] | Should Be 'b'
    }
}

Describe "awk file arguments" {
    BeforeAll {
        $script:awkFile = "test-awk-fix.txt"
        Set-Content -Path $script:awkFile -Value @('apple 10 red','banana 20 yellow') -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:awkFile -Force -ErrorAction SilentlyContinue
    }
    It "processes a file without crashing on the F switch collision" {
        $r = & $script:awkFunc '{print $1}' $script:awkFile
        $r -join '|' | Should Be 'apple|banana'
    }
}

Describe "patch reverse with -p" {
    BeforeAll {
        $script:rTmp = Join-Path $env:TEMP ("test-patch-r-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force $script:rTmp | Out-Null
        $script:rOrig = Join-Path $script:rTmp 'orig.txt'
        $script:rDiff = Join-Path $script:rTmp 'rev.diff'
        $d = @(
            "--- a/orig.txt",
            "+++ b/$($script:rOrig)",
            '@@ -1,3 +1,2 @@',
            ' line1',
            '-line2',
            ' line3'
        )
        Set-Content -Path $script:rDiff -Value $d -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:rTmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "-p 1 -R reverse-applies with prefix stripping" {
        Set-Content -Path $script:rOrig -Value @('line1','line3') -Encoding UTF8
        & $script:patchFunc -p 1 -R $script:rDiff 2>$null | Out-Null
        @(Get-Content $script:rOrig) -join '|' | Should Be 'line1|line2|line3'
    }
    It "-R -p 1 reverse-applies with prefix stripping" {
        Set-Content -Path $script:rOrig -Value @('line1','line3') -Encoding UTF8
        & $script:patchFunc -R -p 1 $script:rDiff 2>$null | Out-Null
        @(Get-Content $script:rOrig) -join '|' | Should Be 'line1|line2|line3'
    }
}
