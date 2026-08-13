# tests\test-utf8-encoding.ps1 (compatible with Pester 3.4.0)
# Regression tests: BOM-less UTF-8 files must be decoded as UTF-8, not as the
# system ANSI code page (GBK on Chinese Windows). PowerShell 5.1 Get-Content
# without -Encoding decodes BOM-less files as ANSI, garbling UTF-8 text.
# Chinese content is built from codepoints so this test file stays ASCII-only.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Remove conflicting aliases before importing the module
foreach ($a in @('ls','cat','rm','cp','mv','ps','kill','sort','ping','wget','diff')) {
    Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue
}
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

$script:catFunc  = Get-Command cat  -CommandType Function -ErrorAction SilentlyContinue
$script:headFunc = Get-Command head -CommandType Function -ErrorAction SilentlyContinue
$script:tailFunc = Get-Command tail -CommandType Function -ErrorAction SilentlyContinue
$script:wcFunc   = Get-Command wc   -CommandType Function -ErrorAction SilentlyContinue
$script:sortFunc = Get-Command sort -CommandType Function -ErrorAction SilentlyContinue
$script:cutFunc  = Get-Command cut  -CommandType Function -ErrorAction SilentlyContinue
$script:grepFunc = Get-Command grep -CommandType Function -ErrorAction SilentlyContinue
$script:sedFunc  = Get-Command sed  -CommandType Function -ErrorAction SilentlyContinue
$script:diffFunc = Get-Command diff -CommandType Function -ErrorAction SilentlyContinue

# Chinese words built from codepoints (no non-ASCII literals in this file)
$script:benTiLun = [string][char]0x672C + [string][char]0x4F53 + [string][char]0x8BBA   # ontology
$script:xiTong   = [string][char]0x7CFB + [string][char]0x7EDF                          # system

Describe "UTF-8 no-BOM file decoding" {
    BeforeAll {
        $script:testFileA = "test-utf8-a.txt"
        $script:testFileB = "test-utf8-b.txt"
        # Write UTF-8 WITHOUT BOM (this is the case that used to break)
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllLines($testFileA,
            @("hello $benTiLun alpha", "beta $xiTong world"), $utf8NoBom)
        [System.IO.File]::WriteAllLines($testFileB,
            @("hello $benTiLun alpha", "beta $xiTong CHANGED"), $utf8NoBom)
    }

    AfterAll {
        Remove-Item $testFileA, $testFileB -Force -ErrorAction SilentlyContinue
    }

    It "cat decodes UTF-8 no-BOM content" {
        $result = & $script:catFunc $testFileA
        $result[0] -like "*$benTiLun*" | Should Be $true
        $result[1] -like "*$xiTong*" | Should Be $true
    }

    It "head decodes UTF-8 no-BOM content" {
        $result = & $script:headFunc -n 1 $testFileA
        (@($result)[0]) -like "*$benTiLun*" | Should Be $true
    }

    It "tail decodes UTF-8 no-BOM content" {
        $result = & $script:tailFunc -n 1 $testFileA
        (@($result)[0]) -like "*$xiTong*" | Should Be $true
    }

    It "wc -l counts UTF-8 no-BOM lines" {
        $result = & $script:wcFunc -l $testFileA
        $result -match "2" | Should Be $true
    }

    It "sort preserves UTF-8 no-BOM content" {
        $result = & $script:sortFunc $testFileA
        ($result -join ' ') -match [regex]::Escape($benTiLun) | Should Be $true
    }

    It "cut extracts UTF-8 no-BOM field" {
        $result = & $script:cutFunc -d " " -f 2 $testFileA
        $result[0] | Should Be $benTiLun
    }

    It "grep matches UTF-8 no-BOM content" {
        $result = & $script:grepFunc $benTiLun $testFileA
        (@($result)[0]) -match [regex]::Escape($benTiLun) | Should Be $true
    }

    It "sed preserves UTF-8 no-BOM content" {
        $result = & $script:sedFunc "s/alpha/omega/" $testFileA
        $result[0] -like "*$benTiLun*" | Should Be $true
    }

    It "diff -u shows UTF-8 no-BOM content" {
        $result = & $script:diffFunc -u $testFileA $testFileB
        $result -match [regex]::Escape($xiTong) | Should Be $true
    }
}
