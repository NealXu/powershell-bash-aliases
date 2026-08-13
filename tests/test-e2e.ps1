# tests\test-e2e.ps1
# End-to-end acceptance: the REAL user journey against the INSTALLED module.
#   1. install.ps1 deploys the complete module layout to a temp install dir
#   2. importing the INSTALLED copy via its MANIFEST yields bash functions that
#      win over built-in aliases (ScriptsToProcess runs in the caller's scope)
#   3. representative commands (ls, cat, nohup) work against the installed copy
# Pester 3.4.0, Windows PowerShell 5.1. ASCII-only.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:e2eInstall = Join-Path $env:TEMP ('e2e-install-' + [guid]::NewGuid().ToString('N'))

# --- Setup: deploy a fresh install to a temp dir, then import it via manifest ---
$null = & (Join-Path $scriptDir '..\install.ps1') -InstallPaths $script:e2eInstall

Import-Module (Join-Path $script:e2eInstall 'bash-aliases.psd1') -Force

$script:lsFunc = Get-Command ls -CommandType Function -ErrorAction SilentlyContinue
$script:catFunc = Get-Command cat -CommandType Function -ErrorAction SilentlyContinue
$script:nohupFunc = Get-Command nohup -CommandType Function -ErrorAction SilentlyContinue

# File layout the install script MUST deploy (mirrors install.ps1's $files).
$script:expectedFiles = @(
    'bash-aliases.psm1', 'args-parser.ps1', 'utils.ps1', 'core-file.ps1',
    'core-text.ps1', 'core-search.ps1', 'core-process.ps1', 'core-network.ps1',
    'core-view.ps1', 'core-system.ps1', 'core-utils.ps1', 'core-compress.ps1',
    'core-edit.ps1', 'bash-aliases.psd1', 'alias-cleanup.ps1', 'profile-setup.ps1'
)

Describe "e2e: install deployment layout" {
    It "deploys every module file to the install dir" {
        foreach ($f in $script:expectedFiles) {
            Test-Path (Join-Path $script:e2eInstall $f) | Should Be $true
        }
    }

    It "installed manifest is valid and resolves its RootModule" {
        $m = Test-ModuleManifest -Path (Join-Path $script:e2eInstall 'bash-aliases.psd1')
        $m.RootModule | Should Be 'bash-aliases.psm1'
    }
}

Describe "e2e: installed module import via manifest" {
    It "ls resolves to the installed module function, not the built-in alias" {
        $script:lsFunc | Should Not Be $null
        $script:lsFunc.CommandType | Should Be Function
    }

    It "cd, cat, rm, cp, mv also resolve to module functions" {
        foreach ($name in @('cd', 'cat', 'rm', 'cp', 'mv')) {
            (Get-Command $name -CommandType Function -ErrorAction SilentlyContinue).Name | Should Be $name
        }
    }
}

Describe "e2e: installed command smoke" {
    It "ls lists a temp directory's files" {
        $dir = Join-Path $env:TEMP ('e2e-ls-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir 'alpha.txt') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $dir 'sub') -Force | Out-Null
        try {
            Push-Location $dir
            $out = @(& $script:lsFunc)
            $out | Should Not BeNullOrEmpty
            ($out -join ' ') | Should Match 'alpha.txt'
            ($out -join ' ') | Should Match 'sub'
        } finally {
            Pop-Location
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "cat prints file content" {
        $file = Join-Path $env:TEMP ('e2e-cat-' + [guid]::NewGuid().ToString('N') + '.txt')
        Set-Content -Path $file -Value @('line one', 'line two') -Encoding ASCII
        try {
            $out = @(& $script:catFunc $file)
            ($out -join ' ') | Should Match 'line one'
            ($out -join ' ') | Should Match 'line two'
        } finally {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
        }
    }

    It "nohup starts a background job and writes nohup.out" {
        $dir = Join-Path $env:TEMP ('e2e-nohup-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Push-Location $dir
        try {
            $nohupOut = Join-Path $dir 'nohup.out'
            $r = @(& $script:nohupFunc Write-Output 'e2e-nohup-marker' 2>&1)
            ($r -join "`n") -match 'Started background job' | Should Be $true
            $deadline = (Get-Date).AddSeconds(15)
            while (-not (Test-Path $nohupOut) -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 250
            }
            Test-Path $nohupOut | Should Be $true
            (Get-Content $nohupOut -Raw) -match 'e2e-nohup-marker' | Should Be $true
        } finally {
            Pop-Location
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
            Get-EventSubscriber -ErrorAction SilentlyContinue | Unregister-Event -Force -ErrorAction SilentlyContinue
            Get-Job | Stop-Job -ErrorAction SilentlyContinue
            Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }
}

# --- Teardown: remove the temp install and unload the installed module copy ---
# Must also Remove-Module the INSTALLED instance: leaving a second 'bash-aliases'
# script module loaded breaks Pester 3.4 InModuleScope/Mock in later test files
# ("Multiple Script modules named 'bash-aliases' are currently loaded"). Filter by
# ModuleBase so only the installed copy is removed, never the repo module instance.
Get-Module bash-aliases -ErrorAction SilentlyContinue |
    Where-Object { $_.ModuleBase -eq $script:e2eInstall } |
    Remove-Module -Force -ErrorAction SilentlyContinue
Remove-Item $script:e2eInstall -Recurse -Force -ErrorAction SilentlyContinue
