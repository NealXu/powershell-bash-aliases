# tests\test-core-view-coverage.ps1
# Pester 3.4.0, Windows PowerShell 5.1
# Exercises uncovered branches in core-view.ps1: less and more.
#   - --help branches (less and more)
#   - file-read path through Out-Host -Paging (small content does not block)
#   - more -d / -f / --silent / --logical flag parsing
#   - more --pattern filter (long form reaches the parser; the short -p form is
#     consumed by PowerShell's binder and never reaches ValueFromRemainingArguments)
#   - more non-existent file error branch (Write-BashError "cannot access")
# ASCII-only: no non-ASCII literals.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Force remove conflicting aliases/functions BEFORE importing the module
Remove-Item "Global:Alias:more" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:less" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Function:more" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Function:less" -Force -ErrorAction SilentlyContinue

Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Function references to bypass PowerShell alias priority
$script:lessFunc = Get-Command less -CommandType Function
$script:moreFunc = Get-Command more -CommandType Function

Describe "less (coverage)" {
    BeforeAll {
        $script:lessFile = Join-Path $TestDrive "less-cov.txt"
        Set-Content -Path $script:lessFile -Value @('alpha one','beta two','alpha three') -Encoding UTF8
    }

    It "less --help returns usage text" {
        $result = @(& $script:lessFunc --help)[0]
        $result | Should Match "Usage: less"
    }

    It "less reads an existing file without throwing" {
        { & $script:lessFunc $script:lessFile } | Should Not Throw
    }
}

Describe "more (coverage)" {
    BeforeAll {
        $script:moreFile = Join-Path $TestDrive "more-cov.txt"
        Set-Content -Path $script:moreFile -Value @('apple one','banana two','apple three','cherry four') -Encoding UTF8
        $script:missingFile = Join-Path $TestDrive "no-such-more-file.txt"
    }

    It "more --help returns usage text" {
        $result = @(& $script:moreFunc --help)[0]
        $result | Should Match "Usage: more"
    }

    It "more -d flag parses and reads a file without throwing" {
        { & $script:moreFunc -d $script:moreFile } | Should Not Throw
    }

    It "more -f flag parses and reads a file without throwing" {
        { & $script:moreFunc -f $script:moreFile } | Should Not Throw
    }

    It "more --silent long option parses without throwing" {
        { & $script:moreFunc --silent $script:moreFile } | Should Not Throw
    }

    It "more --logical long option parses without throwing" {
        { & $script:moreFunc --logical $script:moreFile } | Should Not Throw
    }

    It "more --pattern filters before paging without throwing" {
        { & $script:moreFunc --pattern 'apple' $script:moreFile } | Should Not Throw
    }

    It "more --pattern with no matching lines does not throw" {
        { & $script:moreFunc --pattern 'zzz-no-match' $script:moreFile } | Should Not Throw
    }

    It "more reads a file without throwing" {
        { & $script:moreFunc $script:moreFile } | Should Not Throw
    }

    It "more writes an error for a non-existent file" {
        $result = & $script:moreFunc $script:missingFile 2>&1
        $errorRecord = @($result) | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
        $errorRecord | Should Not Be $null
        $errorRecord[0].Exception.Message | Should Match "cannot access"
    }
}
