<#
.SYNOPSIS
    Install bash-aliases PowerShell module
.DESCRIPTION
    Copies the bash-aliases module to user's PowerShell modules directory.
.EXAMPLE
    install.ps1 -AddToProfile
#>
param(
    [string[]]$InstallPaths = @(
        "$HOME\Documents\PowerShell\Modules\bash-aliases",
        "$HOME\Documents\WindowsPowerShell\Modules\bash-aliases"
    ),
    [switch]$AddToProfile,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$sourceDir = $PSScriptRoot
$files = @('bash-aliases.psm1', 'args-parser.ps1', 'utils.ps1', 'core-file.ps1', 'core-text.ps1', 'core-search.ps1', 'core-process.ps1', 'core-network.ps1', 'core-view.ps1', 'core-system.ps1')

foreach ($InstallPath in $InstallPaths) {
    if (Test-Path $InstallPath) {
        if ($Force) { Remove-Item $InstallPath -Recurse -Force }
        else { Write-Warning "Module exists at $InstallPath. Use -Force."; continue }
    }

    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    foreach ($f in $files) {
        $src = Join-Path $sourceDir $f
        if (Test-Path $src) { Copy-Item $src -Destination $InstallPath; Write-Output "Copied: $f -> $InstallPath" }
    }
}

if ($AddToProfile) {
    $line = @"
# Bash-aliases module - remove conflicting aliases before import
foreach (`$a in @('ls','cat','rm','cp','mv','ps','kill','sort','ping','wget')) { Remove-Item Alias:`$a -Force -ErrorAction SilentlyContinue }
Import-Module bash-aliases -Force -ErrorAction SilentlyContinue
"@
    if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
    if ((Get-Content $PROFILE -ErrorAction SilentlyContinue) -notcontains 'Import-Module bash-aliases') {
        Add-Content $PROFILE $line; Write-Output "Added to profile"
    }
}

Write-Output "Installation complete at: $InstallPath"
Write-Output "To use: Import-Module bash-aliases"