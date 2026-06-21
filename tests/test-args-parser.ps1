# tests\test-args-parser.ps1 (compatible with Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\args-parser.ps1")

Describe "Parse-BashArgs" {
    It "Returns empty result for empty input" {
        $result = Parse-BashArgs -ArgsArray @() -OptionSpec @{}
        $result.Options.Count | Should Be 0
        $result.Positional.Count | Should Be 0
    }
}