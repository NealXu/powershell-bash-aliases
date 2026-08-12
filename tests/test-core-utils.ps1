# tests/test-core-utils.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force
$echoFunc = Get-Command echo -CommandType Function -ErrorAction SilentlyContinue

Describe "echo" {
    It "Outputs text" {
        $result = & $echoFunc "Hello World"
        $result | Should Be "Hello World"
    }

    It "Outputs without newline with -n" {
        # Note: -n uses Write-Host -NoNewline, so we just verify it doesn't throw
        { & $echoFunc -n "test" } | Should Not Throw
    }

    It "Parses escape sequences with --enable-escape" {
        $result = & $echoFunc --enable-escape "Line1\nLine2"
        $result | Should Be "Line1
Line2"
    }

    It "Handles multiple arguments" {
        $result = & $echoFunc "Hello" "World"
        $result | Should Be "Hello World"
    }

    It "Shows help" {
        $result = & $echoFunc --help
        $result | Should Match "Usage"
    }
}