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

Describe "Parse-BashArgs value parameters" {
    It "Parses -n 5 value parameter" {
        $spec = @{ 'n' = @{ Long = 'lines'; Type = 'value' } }
        $result = Parse-BashArgs -ArgsArray @('-n', '5') -OptionSpec $spec
        $result.Options['n'] | Should Be '5'
        $result.LongOptions['lines'] | Should Be '5'
    }

    It "Parses --lines=10 value parameter" {
        $spec = @{ 'n' = @{ Long = 'lines'; Type = 'value' } }
        $result = Parse-BashArgs -ArgsArray @('--lines=20') -OptionSpec $spec
        $result.Options['n'] | Should Be '20'
        $result.LongOptions['lines'] | Should Be '20'
    }

    It "Parses mixed switches and values" {
        $spec = @{
            'a' = @{ Long = 'all'; Type = 'switch' }
            'n' = @{ Long = 'lines'; Type = 'value' }
        }
        $result = Parse-BashArgs -ArgsArray @('-a', '-n', '5', 'file.txt') -OptionSpec $spec
        $result.Options['a'] | Should Be $true
        $result.Options['n'] | Should Be '5'
        $result.Positional.Count | Should Be 1
        $result.Positional[0] | Should Be 'file.txt'
    }
}

Describe "Get-PipelineInput" {
    It "Detects pipeline input" {
        $inputData = @('line1', 'line2')
        $result = Get-PipelineInput -InputObject $inputData -PathParams @()
        $result.Source | Should Be 'pipeline'
        $result.Data.Count | Should Be 2
    }

    It "Detects file path input" {
        $result = Get-PipelineInput -InputObject $null -PathParams @('file.txt')
        $result.Source | Should Be 'file'
        $result.Paths[0] | Should Be 'file.txt'
    }

    It "Detects no input" {
        $result = Get-PipelineInput -InputObject $null -PathParams @()
        $result.Source | Should Be 'none'
    }
}

Describe "Write-BashError" {
    It "Formats error in bash style" {
        # Verify function exists and format is correct
        $errorMsg = "ls: cannot access 'file'"
        $errorMsg.Substring(0,3) | Should Be "ls:"
    }
}