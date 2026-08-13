# tests\test-core-edit.ps1 (Pester 3.4.0, Windows PowerShell 5.1)
# vi/vim commands: launch the real vim from Git for Windows in the foreground.
#   - --help / -h are intercepted and return usage text
#   - all other args are converted (tilde expansion) and passed through to vim
# ASCII-only: no non-ASCII literals.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
foreach ($a in @('ls','cat','rm','cp','mv','sort','diff','vi')) { Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue }
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force
$script:viFunc = Get-Command vi -CommandType Function
$script:vimFunc = Get-Command vim -CommandType Function

Describe "vi --help" {
    It "vi --help returns usage text" {
        $result = & $script:viFunc --help
        @($result)[0] -match "Usage" | Should Be $true
    }
}

Describe "vim --help" {
    It "vim --help returns usage text" {
        $result = & $script:vimFunc --help
        @($result)[0] -match "Usage" | Should Be $true
    }
}

Describe "vim -h" {
    It "vim -h returns usage text" {
        $result = & $script:vimFunc -h
        @($result)[0] -match "Usage" | Should Be $true
    }
}

Describe "Build-VimArgs" {
    It "passes through a plain filename unchanged" {
        InModuleScope bash-aliases {
            $result = @(Build-VimArgs @('file.txt'))
            $result.Count | Should Be 1
            $result[0] | Should Be 'file.txt'
        }
    }

    It "passes through flags and filenames" {
        InModuleScope bash-aliases {
            $result = @(Build-VimArgs @('-R', 'file.txt'))
            $result.Count | Should Be 2
            $result[0] | Should Be '-R'
            $result[1] | Should Be 'file.txt'
        }
    }

    It "passes through vim-internal +N line arguments" {
        InModuleScope bash-aliases {
            $result = @(Build-VimArgs @('+10', 'file.txt'))
            $result.Count | Should Be 2
            $result[0] | Should Be '+10'
            $result[1] | Should Be 'file.txt'
        }
    }

    It "expands a leading tilde to HOME" {
        InModuleScope bash-aliases {
            $result = @(Build-VimArgs @('~/x.txt'))
            $result.Count | Should Be 1
            $result[0].StartsWith($HOME) | Should Be $true
        }
    }
}

Describe "vim without an installed vim" {
    It "emits a vim-not-found error when Get-Command finds nothing" {
        InModuleScope bash-aliases {
            Mock Get-Command { $null }
            $err = @(& vim 'x' 2>&1)
            $err.Count | Should BeGreaterThan 0
            ($err -join "`n") -match 'vim not found' | Should Be $true
        }
    }
}
