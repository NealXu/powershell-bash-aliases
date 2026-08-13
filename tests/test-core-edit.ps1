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
    It "emits a no-editor-found error when Get-Command finds nothing" {
        InModuleScope bash-aliases {
            Mock Get-Command { $null }
            Mock Get-GitVimPath { $null }
            $oldEditor = $env:EDITOR
            if ($null -ne $oldEditor) { Remove-Item Env:EDITOR -Force }
            try {
                $err = @(& vim 'x' 2>&1)
                $err.Count | Should BeGreaterThan 0
                ($err -join "`n") -match 'no editor found' | Should Be $true
            } finally {
                if ($null -ne $oldEditor) { $env:EDITOR = $oldEditor }
            }
        }
    }
}

Describe "Resolve-Editor fallback chain" {
    It "falls back to code when vim is absent and code is present" {
        InModuleScope bash-aliases {
            Mock Get-Command -ParameterFilter { $Name -eq 'vim' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'code' } { [pscustomobject]@{ Source = 'C:\fake\code.exe' } }
            Mock Get-Command -ParameterFilter { $Name -eq 'notepad' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'my-editor' } { $null }
            Mock Get-GitVimPath { $null }
            $oldEditor = $env:EDITOR
            if ($null -ne $oldEditor) { Remove-Item Env:EDITOR -Force }
            try {
                $result = Resolve-Editor
                $result | Should Be 'C:\fake\code.exe'
            } finally {
                if ($null -ne $oldEditor) { $env:EDITOR = $oldEditor }
            }
        }
    }

    It "uses the editor from EDITOR when vim is absent" {
        InModuleScope bash-aliases {
            Mock Get-Command -ParameterFilter { $Name -eq 'vim' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'code' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'notepad' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'my-editor' } { [pscustomobject]@{ Source = 'C:\fake\my-editor.exe' } }
            Mock Get-GitVimPath { $null }
            $oldEditor = $env:EDITOR
            $env:EDITOR = 'my-editor'
            try {
                $result = Resolve-Editor
                $result | Should Be 'C:\fake\my-editor.exe'
            } finally {
                if ($null -ne $oldEditor) { $env:EDITOR = $oldEditor } else { Remove-Item Env:EDITOR -Force -ErrorAction SilentlyContinue }
            }
        }
    }

    It "prefers the Git-bundled vim over EDITOR/code when vim is not on PATH" {
        InModuleScope bash-aliases {
            Mock Get-Command -ParameterFilter { $Name -eq 'vim' } { $null }
            Mock Get-GitVimPath { 'C:\fake\Git\usr\bin\vim.exe' }
            $oldEditor = $env:EDITOR
            if ($null -ne $oldEditor) { Remove-Item Env:EDITOR -Force }
            try {
                $result = Resolve-Editor
                $result | Should Be 'C:\fake\Git\usr\bin\vim.exe'
            } finally {
                if ($null -ne $oldEditor) { $env:EDITOR = $oldEditor }
            }
        }
    }

    It "returns null when no editor is available" {
        InModuleScope bash-aliases {
            Mock Get-Command -ParameterFilter { $Name -eq 'vim' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'code' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'notepad' } { $null }
            Mock Get-Command -ParameterFilter { $Name -eq 'my-editor' } { $null }
            Mock Get-GitVimPath { $null }
            $oldEditor = $env:EDITOR
            if ($null -ne $oldEditor) { Remove-Item Env:EDITOR -Force }
            try {
                $result = Resolve-Editor
                $result | Should Be $null
            } finally {
                if ($null -ne $oldEditor) { $env:EDITOR = $oldEditor }
            }
        }
    }
}

Describe "Get-GitVimPath" {
    It "derives the vim path from the git install root" {
        InModuleScope bash-aliases {
            Mock Get-Command -ParameterFilter { $Name -eq 'git' } { [pscustomobject]@{ Source = 'C:\fake\Git\cmd\git.exe' } }
            Mock Test-Path { $true }
            $result = Get-GitVimPath
            $result | Should Be 'C:\fake\Git\usr\bin\vim.exe'
        }
    }

    It "returns null when git is absent and no known path exists" {
        InModuleScope bash-aliases {
            Mock Get-Command -ParameterFilter { $Name -eq 'git' } { $null }
            Mock Test-Path { $false }
            $result = Get-GitVimPath
            $result | Should Be $null
        }
    }
}
