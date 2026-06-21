# tests\test-bootstrap.ps1
# 测试框架启动脚本 (兼容 Pester 3.4.0)

# 检查 Pester 是否安装
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Warning "Pester not installed. Installing..."
    Install-Module -Name Pester -Force -Scope CurrentUser
}

Import-Module Pester

# 使用固定路径（Pester 3.4.0 的 $PSScriptRoot 解析有问题）
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = Join-Path $scriptDir "..\bash-aliases.psm1"

Describe "Module Bootstrap" {
    It "Module file exists" {
        Test-Path $modulePath | Should Be $true
    }

    It "Module can be imported" {
        $error = $null
        try { Import-Module $modulePath -Force } catch { $error = $_ }
        $error | Should Be $null
    }
}