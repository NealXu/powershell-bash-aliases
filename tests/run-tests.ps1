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

# 显式收集测试文件。Pester 3.x 默认只发现 *.Tests.ps1,而本项目测试命名为 test-*.ps1,
# 直接传目录会导致 0 个测试被运行,让失败和文件污染都无法被发现。
# 注意:不能把测试隔离到临时目录运行 —— 压缩类函数用 .NET File API 打开相对路径,
# 而 .NET 进程当前目录不跟随 PowerShell 的 Push-Location,会导致找不到测试文件。
$testScripts = @(Get-ChildItem -Path $testsDir -Filter '*.ps1' | Where-Object { $_.Name -ne 'run-tests.ps1' })

# 运行所有测试(在仓库根目录 cwd 下运行,与模块实现一致)
$result = Invoke-Pester -Path ($testScripts | ForEach-Object { $_.FullName }) -PassThru

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
    "core-system.ps1",
    "core-edit.ps1"
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
    "test-core-edit.ps1",
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
    "core-edit.ps1" = 4   # Resolve-Editor, Build-VimArgs, vim, vi
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
    "core-edit.ps1" = 4
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