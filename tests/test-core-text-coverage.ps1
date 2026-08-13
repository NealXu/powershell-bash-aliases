# tests\test-core-text-coverage.ps1
# Coverage-focused tests for the previously-uncovered branches of the
# patch, awk, uniq, tr and sed functions in core-text.ps1.
# Compatible with Pester 3.4.0 and Windows PowerShell 5.1.
# IMPORTANT: This file is ASCII-only. Do not insert non-ASCII literals.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Remove conflicting aliases so the module's functions win.
foreach ($a in @('ls','cat','rm','cp','mv','ps','kill','sort','ping','wget','diff')) {
    Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue
}

Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Load the argument parser + path helpers into this scope so the simple-function
# copies defined below can resolve Parse-BashArgs / Convert-BashPath / etc.
. (Join-Path $scriptDir "..\args-parser.ps1")
. (Join-Path $scriptDir "..\utils.ps1")

# Real function references.
$script:patchFunc = Get-Command patch -CommandType Function -ErrorAction SilentlyContinue
$script:sedFunc   = Get-Command sed   -CommandType Function -ErrorAction SilentlyContinue
$script:trFunc    = Get-Command tr    -CommandType Function -ErrorAction SilentlyContinue
$script:uniqFunc  = Get-Command uniq  -CommandType Function -ErrorAction SilentlyContinue
$script:awkFunc   = Get-Command awk   -CommandType Function -ErrorAction SilentlyContinue

# The production tr / uniq functions declare
# [Parameter(ValueFromRemainingArguments=$true)] on their ArgList parameter.  That
# attribute makes them *advanced* functions which reject pipeline input into the
# automatic $input variable, so they cannot be driven through a pipeline.
#
# To exercise the identical body logic, we build simple-function copies whose
# parameter block is replaced with `param()` + `$ArgList = @($args)`.  A simple
# function accepts pipeline input through $input, and $args still collects every
# positional / short-flag argument so Parse-BashArgs behaves exactly as in the
# production body.
#
# awk takes its input as file arguments (not a pipeline), so it needs no copy:
# we call the real awk function directly so Pester can attribute its coverage.
function Get-CopySource {
    param([string]$FuncName, [string]$NewName)
    $body = (Get-Command $FuncName -CommandType Function -ErrorAction SilentlyContinue).Definition
    $lines = $body -split "`n"
    $paramEnd = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*\)\s*$') { $paramEnd = $i; break }
    }
    $rest = ($lines[($paramEnd+1)..($lines.Count-1)] -join "`n")
    return "function $NewName {`nparam()`n`$ArgList = @(`$args)`n" + $rest + "`n}"
}

Invoke-Expression (Get-CopySource -FuncName 'tr'   -NewName 'tr_copy')
Invoke-Expression (Get-CopySource -FuncName 'uniq' -NewName 'uniq_copy')

$script:trCopy   = Get-Command tr_copy   -CommandType Function -ErrorAction SilentlyContinue
$script:uniqCopy = Get-Command uniq_copy -CommandType Function -ErrorAction SilentlyContinue

Describe "patch" {
    BeforeAll {
        $script:pTmp = Join-Path $env:TEMP ("test-patch-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force $script:pTmp | Out-Null
        $script:pOrig = Join-Path $script:pTmp 'orig.txt'

        # Replacement diff (uses a/ b/ prefix so -p 1 strips it).
        $one = @(
            "--- a/orig.txt",
            "+++ b/$($script:pOrig)",
            '@@ -1,3 +1,3 @@',
            ' line1',
            '-line2',
            '+LINE2_MODIFIED',
            ' line3'
        )
        Set-Content -Path (Join-Path $script:pTmp 'one.diff') -Value $one -Encoding UTF8

        # Multi-hunk diff.
        $multi = @(
            "--- a/orig.txt",
            "+++ b/$($script:pOrig)",
            '@@ -1,2 +1,2 @@',
            ' line1',
            '-line2',
            '+line2-X',
            '@@ -4,2 +4,2 @@',
            ' line4',
            '-line5',
            '+line5-X'
        )
        Set-Content -Path (Join-Path $script:pTmp 'multi.diff') -Value $multi -Encoding UTF8

        # Deletion diff (no a/ b/ prefix) used for both forward and reverse apply.
        $del = @(
            "--- a/orig.txt",
            "+++ $($script:pOrig)",
            '@@ -1,3 +1,2 @@',
            ' line1',
            '-line2',
            ' line3'
        )
        Set-Content -Path (Join-Path $script:pTmp 'del.diff') -Value $del -Encoding UTF8

        # Diff with no hunks at all.
        $nohunks = @(
            "--- a/orig.txt",
            "+++ $($script:pOrig)"
        )
        Set-Content -Path (Join-Path $script:pTmp 'nohunks.diff') -Value $nohunks -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:pTmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "applies a simple replacement hunk" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        & $script:patchFunc -p 1 (Join-Path $script:pTmp 'one.diff') 2>$null | Out-Null
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|LINE2_MODIFIED|line3'
    }

    It "applies multiple hunks" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3','line4','line5') -Encoding UTF8
        & $script:patchFunc -p 1 (Join-Path $script:pTmp 'multi.diff') 2>$null | Out-Null
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|line2-X|line3|line4|line5-X'
    }

    It "-p 1 strips the a/ b/ prefix" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        $r = & $script:patchFunc -p 1 (Join-Path $script:pTmp 'one.diff') 2>$null
        ($r -join ' ') -match 'Patched' | Should Be $true
        @(Get-Content $script:pOrig)[1] | Should Be 'LINE2_MODIFIED'
    }

    It "-p 0 does not strip, so a b/ prefixed target cannot be found" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        $r = & $script:patchFunc (Join-Path $script:pTmp 'one.diff') 2>$null
        $null -eq $r | Should Be $true
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|line2|line3'
    }

    It "--dry-run reports the patch but leaves the file unchanged" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        $r = @(& $script:patchFunc -p 1 --dry-run (Join-Path $script:pTmp 'one.diff') 2>$null)
        $r.Count | Should Be 2
        $r[0] -match 'Dry run' | Should Be $true
        $r[1] -match '1 hunk' | Should Be $true
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|line2|line3'
    }

    It "forward apply removes a line" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        & $script:patchFunc (Join-Path $script:pTmp 'del.diff') 2>$null | Out-Null
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|line3'
    }

    It "-R reverse-apply restores a removed line" {
        Set-Content -Path $script:pOrig -Value @('line1','line3') -Encoding UTF8
        & $script:patchFunc -R (Join-Path $script:pTmp 'del.diff') 2>$null | Out-Null
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|line2|line3'
    }

    It "-o writes patched content to the output file and leaves the target untouched" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        $outFile = Join-Path $script:pTmp 'out.txt'
        & $script:patchFunc -p 1 --output $outFile (Join-Path $script:pTmp 'one.diff') 2>$null | Out-Null
        @(Get-Content $outFile) -join '|' | Should Be 'line1|LINE2_MODIFIED|line3'
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|line2|line3'
    }

    It "-i / --input reads the patch from a file" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        & $script:patchFunc -p 1 --input (Join-Path $script:pTmp 'one.diff') 2>$null | Out-Null
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|LINE2_MODIFIED|line3'
    }

    It "reports an error when the patch file cannot be accessed" {
        $r = & $script:patchFunc -p 1 (Join-Path $script:pTmp 'missing.diff') 2>$null
        $null -eq $r | Should Be $true
    }

    It "reports an error when the patch contains no hunks" {
        Set-Content -Path $script:pOrig -Value @('line1','line2','line3') -Encoding UTF8
        $r = & $script:patchFunc (Join-Path $script:pTmp 'nohunks.diff') 2>$null
        $null -eq $r | Should Be $true
        @(Get-Content $script:pOrig) -join '|' | Should Be 'line1|line2|line3'
    }
}

Describe "sed" {
    BeforeAll {
        $script:sTmp = Join-Path $env:TEMP ("test-sed-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force $script:sTmp | Out-Null
        $script:sFile = Join-Path $script:sTmp 'sed.txt'
        Set-Content -Path $script:sFile -Value @('hello world','foo bar','test line') -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:sTmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "substitutes a pattern" {
        $r = @(& $script:sedFunc 's/hello/HELLO/' $script:sFile)
        $r[0] | Should Be 'HELLO world'
        $r.Count | Should Be 3
    }

    It "substitutes globally with the g flag" {
        $r = @(& $script:sedFunc 's/o/O/g' $script:sFile)
        $r[0] | Should Be 'hellO wOrld'
        $r[1] | Should Be 'fOO bar'
    }

    It "non-global substitution still replaces all occurrences in a matched line" {
        $r = @(& $script:sedFunc 's/o/O/' $script:sFile)
        $r[0] | Should Be 'hellO wOrld'
    }

    It "accepts a script through --expression" {
        $r = @(& $script:sedFunc --expression 's/foo/BAR/' $script:sFile)
        $r[1] | Should Be 'BAR bar'
        $r[0] | Should Be 'hello world'
    }

    It "-n quiet mode suppresses output" {
        $r = @(& $script:sedFunc -n 's/foo/BAR/' $script:sFile)
        $r.Count | Should Be 0
    }

    It "-i edits the file in place" {
        $inPlace = Join-Path $script:sTmp 'inplace.txt'
        Copy-Item $script:sFile $inPlace
        & $script:sedFunc -i 's/hello/HELLO/' $inPlace 2>$null | Out-Null
        @(Get-Content $inPlace)[0] | Should Be 'HELLO world'
        @(Get-Content $inPlace)[1] | Should Be 'foo bar'
    }

    It "reports an error for an unsupported script" {
        $r = & $script:sedFunc 'd' $script:sFile 2>$null
        $null -eq $r | Should Be $true
    }
}

Describe "tr" {
    BeforeAll {
        $script:trCopy = Get-Command tr_copy -CommandType Function -ErrorAction SilentlyContinue
        $script:trFunc = Get-Command tr -CommandType Function -ErrorAction SilentlyContinue
    }

    It "the real function shows help" {
        $r = & $script:trFunc --help
        ($r -join '') -match 'Usage' | Should Be $true
    }

    It "-d deletes characters from the input" {
        $r = 'hello world' | & $script:trCopy -d 'lo'
        @($r)[0] | Should Be 'he wrd'
    }

    It "translates character pairs" {
        $r = 'hello' | & $script:trCopy 'el' 'EI'
        @($r)[0] | Should Be 'hEIIo'
    }

    It "translates a single character" {
        $r = 'abc' | & $script:trCopy 'a' 'b'
        @($r)[0] | Should Be 'bbc'
    }

    It "processes multiple input lines" {
        $r = @('abc','def') | & $script:trCopy 'a' 'z'
        $r[0] | Should Be 'zbc'
        $r[1] | Should Be 'def'
    }

    It "-d with a range of characters" {
        $r = 'a1b2c3' | & $script:trCopy -d '123'
        @($r)[0] | Should Be 'abc'
    }

    It "reports an error when SET1 is missing" {
        $r = & $script:trCopy -d 2>$null
        $null -eq $r | Should Be $true
    }

    It "reports an error when SET2 is missing" {
        $r = & $script:trCopy 'abc' 2>$null
        $null -eq $r | Should Be $true
    }
}

Describe "uniq" {
    BeforeAll {
        $script:uniqCopy = Get-Command uniq_copy -CommandType Function -ErrorAction SilentlyContinue
        $script:uniqFunc = Get-Command uniq -CommandType Function -ErrorAction SilentlyContinue
    }

    It "the real function shows help" {
        $r = & $script:uniqFunc --help
        ($r -join '') -match 'Usage' | Should Be $true
    }

    It "-c counts occurrences of each line" {
        $r = @('a','a','b','b','c') | & $script:uniqCopy -c
        $r[0] | Should Be '2 a'
        $r[1] | Should Be '2 b'
        $r[2] | Should Be '1 c'
    }

    It "-d prints only duplicated lines" {
        $r = @('a','a','b','b','c') | & $script:uniqCopy -d
        $r[0] | Should Be 'a'
        $r[1] | Should Be 'b'
        $r.Count | Should Be 2
    }

    It "with no flags prints sorted unique lines" {
        $r = @('a','a','b','b','c') | & $script:uniqCopy
        $r -join '|' | Should Be 'a|b|c'
    }

    It "handles input that is already sorted" {
        $r = @('x','x','x','y') | & $script:uniqCopy -c
        $r[0] | Should Be '3 x'
        $r[1] | Should Be '1 y'
    }
}

Describe "awk" {
    BeforeAll {
        $script:aTmp = Join-Path $env:TEMP ("test-awk-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Force $script:aTmp | Out-Null
        $script:aData = Join-Path $script:aTmp 'data.txt'
        Set-Content -Path $script:aData -Value @('apple 10 red','banana 20 yellow','cherry 30 red') -Encoding UTF8
        $script:aCsv = Join-Path $script:aTmp 'csv.txt'
        Set-Content -Path $script:aCsv -Value @('a,b,c','x,y,z') -Encoding UTF8
        $script:awkFunc = Get-Command awk -CommandType Function -ErrorAction SilentlyContinue
    }
    AfterAll {
        Remove-Item $script:aTmp -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "the real function shows help" {
        $r = & $script:awkFunc --help
        ($r -join '') -match 'Usage' | Should Be $true
    }

    It "{print $N} prints a single field" {
        $r = & $script:awkFunc '{print $1}' $script:aData
        $r -join '|' | Should Be 'apple|banana|cherry'
    }

    It "-F changes the field separator" {
        $r = & $script:awkFunc -F ',' '{print $2}' $script:aCsv
        $r -join '|' | Should Be 'b|y'
    }

    It "/pattern/ {print $N} applies a pattern action" {
        $r = & $script:awkFunc '/red/ {print $1}' $script:aData
        $r -join '|' | Should Be 'apple|cherry'
    }

    It "print $N without braces prints a field" {
        $r = & $script:awkFunc 'print $2' $script:aData
        $r -join '|' | Should Be '10|20|30'
    }

    It "{print} defaults to the whole line" {
        $r = & $script:awkFunc '{print}' $script:aData
        $r -join '|' | Should Be 'apple 10 red|banana 20 yellow|cherry 30 red'
    }

    It "unmatched patterns print the whole line" {
        $r = & $script:awkFunc '$0' $script:aData
        $r -join '|' | Should Be 'apple 10 red|banana 20 yellow|cherry 30 red'
    }

    It "-v accepts a variable assignment" {
        $r = & $script:awkFunc -v 'x=5' '{print $1}' $script:aData
        $r -join '|' | Should Be 'apple|banana|cherry'
    }

    It "processes multiple files in sequence" {
        $r = & $script:awkFunc '{print $1}' $script:aData $script:aCsv
        $r -join '|' | Should Be 'apple|banana|cherry|a,b,c|x,y,z'
    }

    It "reports an error when the program is missing" {
        $r = & $script:awkFunc 'not-a-program.txt' 2>$null
        $null -eq $r | Should Be $true
    }

    It "reports an error when a file cannot be accessed" {
        $r = & $script:awkFunc '{print $1}' (Join-Path $script:aTmp 'missing.txt') 2>$null
        $null -eq $r | Should Be $true
    }
}
