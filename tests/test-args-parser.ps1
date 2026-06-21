# tests\test-args-parser.ps1 (compatible with Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\args-parser.ps1")

Describe "Parse-BashArgs" {
    It "Returns empty result for empty input" {
        $result = Parse-BashArgs -ArgsArray @() -OptionSpec @{}
        $result.Options.Count | Should Be 0
        $result.Positional.Count | Should Be 0
    }

    It "Parses single short switch -a" {
        $spec = @{ 'a' = @{ Long = 'all'; Type = 'switch' } }
        $result = Parse-BashArgs -ArgsArray @('-a') -OptionSpec $spec
        $result.Options['a'] | Should Be $true
        $result.LongOptions['all'] | Should Be $true
    }

    It "Parses combined short switches -la" {
        $spec = @{
            'l' = @{ Long = 'long'; Type = 'switch' }
            'a' = @{ Long = 'all'; Type = 'switch' }
        }
        $result = Parse-BashArgs -ArgsArray @('-la') -OptionSpec $spec
        $result.Options['l'] | Should Be $true
        $result.Options['a'] | Should Be $true
    }

    It "Parses long option --all" {
        $spec = @{ 'a' = @{ Long = 'all'; Type = 'switch' } }
        $result = Parse-BashArgs -ArgsArray @('--all') -OptionSpec $spec
        $result.Options['a'] | Should Be $true
        $result.LongOptions['all'] | Should Be $true
    }
}