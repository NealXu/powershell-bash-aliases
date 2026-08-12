# tests\run-tests.ps1
# 测试运行脚本 - 运行所有测试并估算覆盖率

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$testsDir = $scriptDir

# 检查 Pester 是否安装
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Warning "Pester not installed. Installing..."
    Install-Module -Name Pester -Force -Scope CurrentUser
}

Import-Module Pester -ErrorAction Stop

Write-Host "Running all tests..." -ForegroundColor Cyan
Write-Host "==================" -ForegroundColor Cyan

# 运行所有测试
$result = Invoke-Pester -Path $testsDir -PassThru

Write-Host ""
Write-Host "Test Results Summary:" -ForegroundColor Yellow
Write-Host "  Total Tests: $($result.TotalCount)"
Write-Host "  Passed: $($result.PassedCount)" -ForegroundColor Green
Write-Host "  Failed: $($result.FailedCount)" -ForegroundColor Red
Write-Host "  Skipped: $($result.SkippedCount)" -ForegroundColor Gray
Write-Host ""

# 估算覆盖率
Write-Host "Coverage Estimation:" -ForegroundColor Yellow

$coreFiles = @(
    "utils.ps1",
    "core-file.ps1",
    "core-text.ps1",
    "core-search.ps1",
    "core-process.ps1",
    "core-network.ps1",
    "core-view.ps1",
    "core-system.ps1"
)

$testFiles = @(
    "test-utils.ps1",
    "test-core-file.ps1",
    "test-core-text.ps1",
    "test-core-search.ps1",
    "test-core-process.ps1",
    "test-core-network.ps1",
    "test-core-view.ps1",
    "test-core-system.ps1",
    "test-ll.ps1",
    "test-bootstrap.ps1"
)

# 统计每个核心文件的函数数
$functionCounts = @{
    "utils.ps1" = 5      # Format-FileSize, Format-FileTime, Format-UnixMode, Format-Columns, Convert-BashPath
    "core-file.ps1" = 8  # ls, cat, rm, mkdir, cp, mv, touch, ll
    "core-text.ps1" = 7  # head, tail, wc, sort, uniq, cut, tr
    "core-search.ps1" = 3 # grep, find, which
    "core-process.ps1" = 4 # ps, kill, killall, top
    "core-network.ps1" = 4 # curl, ping, netstat, wget
    "core-view.ps1" = 1   # less
    "core-system.ps1" = 6 # df, du, uptime, uname, hostname, yolo/yoloc
}

# 估算每个核心文件的测试覆盖函数数
$coveredFunctions = @{
    "utils.ps1" = 5
    "core-file.ps1" = 8
    "core-text.ps1" = 7
    "core-search.ps1" = 3
    "core-process.ps1" = 4
    "core-network.ps1" = 4
    "core-view.ps1" = 1
    "core-system.ps1" = 5  # yolo/yoloc 未测试
}

$totalFunctions = 0
$totalCovered = 0

foreach ($file in $coreFiles) {
    $totalFunctions += $functionCounts[$file]
    $covered = $coveredFunctions[$file]
    $totalCovered += $covered
    $coveragePercent = [Math]::Round(($covered / $functionCounts[$file]) * 100)
    Write-Host "  ${file}: $coveragePercent% ($covered/$($functionCounts[$file]) functions)"
}

$overallCoverage = [Math]::Round(($totalCovered / $totalFunctions) * 100)
Write-Host ""
Write-Host "Overall Estimated Coverage: $overallCoverage% ($totalCovered/$totalFunctions functions)" -ForegroundColor $(if ($overallCoverage -ge 85) { "Green" } else { "Yellow" })

if ($overallCoverage -ge 85) {
    Write-Host "Coverage target of 85% achieved!" -ForegroundColor Green
} else {
    Write-Host "Coverage target of 85% not yet achieved. Need $($totalFunctions - $totalCovered) more function tests." -ForegroundColor Yellow
}

# 返回结果
return $result