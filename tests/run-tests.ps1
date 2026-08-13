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

# 真实命令级覆盖率（Pester -CodeCoverage）
Write-Host ""
Write-Host "Coverage (Pester -CodeCoverage, command-level):" -ForegroundColor Yellow

$coreFiles = @(
    "args-parser.ps1", "utils.ps1", "core-file.ps1", "core-text.ps1",
    "core-search.ps1", "core-process.ps1", "core-network.ps1", "core-view.ps1",
    "core-system.ps1", "core-utils.ps1", "core-compress.ps1", "core-edit.ps1"
) | ForEach-Object { Join-Path $scriptDir "..\$_" }

# 需要重新带覆盖率跑一遍（上面第 25 行已跑过一次无覆盖的，为拿覆盖率结果再跑一次）
$covResult = Invoke-Pester -Path ($testScripts | ForEach-Object { $_.FullName }) -CodeCoverage $coreFiles -PassThru

if ($covResult.FailedCount -gt 0) {
    Write-Host "WARNING: $($covResult.FailedCount) test(s) failed during the coverage run (run 2)." -ForegroundColor Red
}

$cc = $covResult.CodeCoverage
if ($cc) {
    $executed = $cc.NumberOfCommandsExecuted
    $analyzed = $cc.NumberOfCommandsAnalyzed
    $pct = if ($analyzed -gt 0) { [Math]::Round(($executed / $analyzed) * 100, 1) } else { 0 }

    Write-Host "  Commands executed/analyzed: $executed/$analyzed = $pct%" -ForegroundColor $(if ($pct -ge 85) { "Green" } else { "Yellow" })

    $missed = @($cc.MissedCommands)
    Write-Host "  Missed by file (count):"
    $missed | Group-Object File | Sort-Object Count -Descending | ForEach-Object {
        Write-Host ("    {0}: {1}" -f (Split-Path $_.Name -Leaf), $_.Count)
    }

    Write-Host "  Missed by function (top 15):"
    $missed | Group-Object { "$(Split-Path $_.File -Leaf).$($_.Function)" } |
        Sort-Object Count -Descending | Select-Object -First 15 | ForEach-Object {
        Write-Host ("    {0}: {1}" -f $_.Name, $_.Count)
    }

    if ($pct -ge 85) {
        Write-Host ""
        Write-Host "Coverage target of 85% achieved: $pct%" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "Coverage $pct% below target of 85%. See Missed by function above." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Known caveats (Pester 3.4.0):" -ForegroundColor Gray
    Write-Host "  * CoveragePercent property reports 0; percentage computed manually." -ForegroundColor Gray
    Write-Host "  * tr/uniq are tested via dynamically-defined *_copy functions;" -ForegroundColor Gray
    Write-Host "    their execution is not attributed to core-text.ps1, so their" -ForegroundColor Gray
    Write-Host "    coverage is understated here. Real coverage is higher." -ForegroundColor Gray
    Write-Host "  * Some module branchy code (e.g. file content detection) executes" -ForegroundColor Gray
    Write-Host "    but is under-attributed. Treat the percentage as a lower bound." -ForegroundColor Gray
} else {
    Write-Host "  No coverage data returned by Pester." -ForegroundColor Yellow
}

# 返回结果
return $result