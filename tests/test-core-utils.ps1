# tests/test-core-utils.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Force remove echo and tee aliases to ensure function calls work
Remove-Item "Global:Alias:echo" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:tee" -Force -ErrorAction SilentlyContinue

Describe "echo" {
    It "Outputs text" {
        $result = echo "Hello World"
        $result | Should Be "Hello World"
    }

    It "Outputs without newline with -n" {
        # Note: -n uses Write-Host -NoNewline, so we just verify it doesn't throw
        { echo -n "test" } | Should Not Throw
    }

    It "Parses escape sequences with --enable-escape" {
        $result = echo --enable-escape "Line1\nLine2"
        $result | Should Be "Line1
Line2"
    }

    It "Handles multiple arguments" {
        $result = echo "Hello" "World"
        $result | Should Be "Hello World"
    }

    It "Shows help" {
        $result = echo --help
        $result | Should Match "Usage"
    }
}

Describe "tee" {
    It "Writes to file and stdout" {
        $testFile = "$env:TEMP\tee-test-$(Get-Random).txt"
        $result = "Hello World" | tee $testFile
        $result | Should Be "Hello World"
        Get-Content $testFile | Should Be "Hello World"
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Appends to file with -a" {
        $testFile = "$env:TEMP\tee-append-$(Get-Random).txt"
        Set-Content $testFile "Line1"
        $result = "Line2" | tee -a $testFile
        $result | Should Be "Line2"
        $content = Get-Content $testFile
        $content.Count | Should Be 2
        $content[0] | Should Be "Line1"
        $content[1] | Should Be "Line2"
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Handles multiple files" {
        $testFile1 = "$env:TEMP\tee-multi1-$(Get-Random).txt"
        $testFile2 = "$env:TEMP\tee-multi2-$(Get-Random).txt"
        $result = "Test" | tee $testFile1 $testFile2
        $result | Should Be "Test"
        Get-Content $testFile1 | Should Be "Test"
        Get-Content $testFile2 | Should Be "Test"
        Remove-Item $testFile1,$testFile2 -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = tee --help
        $result | Should Match "Usage"
    }
}