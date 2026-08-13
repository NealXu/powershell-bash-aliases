<#
.SYNOPSIS
    Install bash-aliases PowerShell module
.DESCRIPTION
    Copies the bash-aliases module to the module directory of every PowerShell
    installed on this machine. Deploy targets are auto-detected from the
    installed shell types (Windows PowerShell 5.1 and/or PowerShell 7+).
.EXAMPLE
    install.ps1
.EXAMPLE
    install.ps1 -AddToProfile -Force
.EXAMPLE
    install.ps1 -InstallPaths "C:\custom\Modules\bash-aliases"
#>
param(
    # 可选:手动指定安装路径。不提供时自动识别本机已安装的 shell 类型再部署。
    [string[]]$InstallPaths,
    [switch]$AddToProfile,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$sourceDir = $PSScriptRoot
$files = @('bash-aliases.psm1', 'args-parser.ps1', 'utils.ps1', 'core-file.ps1', 'core-text.ps1', 'core-search.ps1', 'core-process.ps1', 'core-network.ps1', 'core-view.ps1', 'core-system.ps1', 'core-utils.ps1', 'core-compress.ps1', 'core-edit.ps1')

# --- 自动识别本机安装的 PowerShell 类型,决定部署目标 ---
# 每个 PowerShell 版本在 Documents 下使用自己的模块目录,互不共享:
#   Windows PowerShell 5.1 -> $HOME\Documents\WindowsPowerShell\Modules
#   PowerShell 7+ (pwsh)   -> $HOME\Documents\PowerShell\Modules
# 因此只部署到实际安装了对应 shell 的目录,不为不存在的 shell 预留副本。
if (-not $InstallPaths -or $InstallPaths.Count -eq 0) {
    $InstallPaths = @()

    # 5.1: Windows 系统组件,固定在 System32 下。用固定路径探测比 Get-Command 更可靠。
    $ps51Exe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $ps51Exe) {
        $InstallPaths += "$HOME\Documents\WindowsPowerShell\Modules\bash-aliases"
    }

    # 7+: 通过 PATH 上的 pwsh.exe 探测
    if (Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue) {
        $InstallPaths += "$HOME\Documents\PowerShell\Modules\bash-aliases"
    }

    if ($InstallPaths.Count -eq 0) {
        Write-Error "未检测到任何 PowerShell(5.1 或 7+),无法确定部署目标。"
        exit 1
    }

    Write-Host "检测到本机 PowerShell,部署目标:"
    foreach ($p in $InstallPaths) { Write-Host "  $p" }
} else {
    Write-Host "使用手动指定的部署路径:"
    foreach ($p in $InstallPaths) { Write-Host "  $p" }
}

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
