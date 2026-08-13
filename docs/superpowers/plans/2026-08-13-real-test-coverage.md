# 真实测试覆盖率改造实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: 使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 逐任务实施。步骤用复选框（`- [ ]`）跟踪。

**Goal:** 用 Pester 3.4.0 真实的 `-CodeCoverage` 命令级测量替换 `run-tests.ps1` 中过期的硬编码函数估算，并补齐高价值分支测试，最终覆盖率 ≥85% 且数字可信。

**Architecture:** 三个相互独立的工作流，每个都以绿色测试收尾：
1. **启用真实测量**：把 `awk` 测试从动态 `awk_copy` 改为直接调用 `awk`（`$f`/`$F` 参数冲突早已修复），消除 Pester 3.4.0 插桩下 7 个 awk 测试失败，使覆盖率测量可完整运行。
2. **补分支测试**：`grep -v`、`fg`/`bg` 最近作业路径、`nohup` 后台执行、`file` symlink 诚实记账、`tar -v/-j/-C/-help`。
3. **重写 `run-tests.ps1`**：用真实命令级覆盖率替代硬编码表，手动计算百分比（绕开 Pester 3.4.0 `CoveragePercent` 恒为 0 的显示 bug），并打印按文件/函数分级的未覆盖明细与已知归因伪影警告。

**Tech Stack:** Windows PowerShell 5.1、Pester 3.4.0、无第三方依赖（除 Pester 外）。

## Global Constraints

- PowerShell 5.1（`powershell.exe`），**不是** pwsh 7。所有命令在 `powershell.exe` 下验证。
- Pester **3.4.0**（本机唯一已装版本）。禁止使用 Pester 5 语法（如 `Should -Be`、`New-PesterConfiguration`）。断言一律 `Should Be` / `Should Not Throw` / `Should Match`。
- **测试文件必须 ASCII-only**（不得含非 ASCII 字面量）。`test-core-text-coverage.ps1` 头部明确标注此约定。
- 测试从仓库根目录 cwd 运行（`.NET` 进程当前目录不跟随 `Push-Location`，压缩类测试依赖此行为）。
- 测试输入一律放 `$env:TEMP`，`AfterAll` 清理，保持仓库根目录干净。
- 函数引用一律经 `& $script:<name>Func` 调用（绕过别名优先级）。
- 原生外部命令用 `Mock ... -ModuleName bash-aliases` 拦截（Pester Mock 特性，见 `test-core-compress-coverage.ps1` 注释）。
- 别名移除用 `Remove-Item "Global:Alias:..."`（点源文件用 Global:，模块函数靠模块导出）。
- 本次计划**不改任何生产代码**（`core-*.ps1` / `utils.ps1` / `args-parser.ps1`）。若测试暴露真实缺陷，单独开任务修复，不在本计划内修。
- 覆盖率目标：85%（命令级）。

---

### Task 1: awk 测试改为直接调用（消除插桩失败，启用真实覆盖）

**Files:**
- Modify: `tests/test-core-text-coverage.ps1:54`（删除 awk_copy 创建）
- Modify: `tests/test-core-text-coverage.ps1:335`（删除 awkCopy 引用）
- Modify: `tests/test-core-text-coverage.ps1:347-393`（9 处 `$script:awkCopy` → `$script:awkFunc`）
- Modify: `tests/test-core-text-coverage.ps1:28-39`（更新注释，说明 awk 已无需副本）

**背景（已验证）：**
- 注释声称 awk 存在 `foreach ($f in $files)` 与 `[switch]$F` 的运行时冲突（PS 变量大小写不敏感）。**当前实现已用 `$file`，冲突已修复**。
- 直接调用 `& (Get-Command awk) '{print $1}' file`、`-F ','`、`'print $2'`、`-v 'x=5'`、`'/red/ {print $1}'`、`'{print}'`、`'$0'`、多文件全部实测通过。
- awk 测试传**文件参数**（非管道），不依赖 `$input`，故副本本就不必要。
- 副本通过 `Invoke-Expression` 动态定义，Pester 3.4.0 插桩下读取到被改写过的定义 → 复制体参数绑定损坏 → 7 个测试失败且 awk 命令被记为未覆盖（归因到 `<No file>`）。
- 对照组：awk 的 help 测试用 `awkFunc`（直接调用）在插桩下**通过**，证明直接调用路径安全。

- [ ] **Step 1: 改写测试为直接调用**

  编辑 `tests/test-core-text-coverage.ps1`：

  - 第 54 行：删除 `Invoke-Expression (Get-CopySource -FuncName 'awk' -NewName 'awk_copy')`（保留 52、53 行的 tr/uniq 副本）。
  - 第 335 行：删除 `$script:awkCopy = Get-Command awk_copy -CommandType Function -ErrorAction SilentlyContinue`（保留 336 行 `$script:awkFunc`）。
  - 第 348、353、358、363、368、373、378、383、388、393 行：将 `& $script:awkCopy` 全部替换为 `& $script:awkFunc`。
  - 更新第 28-39 行注释：说明 tr/uniq 因 `ValueFromRemainingArguments` 高级函数拒绝管道输入仍需副本；awk 无此问题，直接调用以便 Pester 归因。

- [ ] **Step 2: 无插桩运行，确认全绿**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; Invoke-Pester -Path 'tests\test-core-text-coverage.ps1' -PassThru | Out-Host"`
  Expected: Failed: 0。awk Describe 全部 [+]（含 `{print $1}`、`-F`、`/red/`、`print $2`、`{print}`、`$0`、`-v`、多文件、两错误路径）。

- [ ] **Step 3: 带插桩运行，确认 awk 不再失败且被归因**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; Invoke-Pester -Path 'tests\test-core-text-coverage.ps1' -CodeCoverage 'core-text.ps1' -PassThru | Out-Host"`
  Expected: Failed: 0。输出中 awk 相关未覆盖命令数量**从 36 大幅下降到个位数**（只剩真正未执行的错误/边缘分支）。

- [ ] **Step 4: 跑完整套件回归**

  Run: `powershell -NoProfile -Command "& 'D:\Codes\powershell-bash-aliases\tests\run-tests.ps1' | Out-Null"`
  Expected: 结尾 `Failed: 0`（总计 ~671 测试，17 跳过）。

- [ ] **Step 5: Commit**

```bash
git add tests/test-core-text-coverage.ps1
git commit -m "refactor(test): call awk directly instead of awk_copy for reliable coverage
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: grep -v 反向匹配与 missing-pattern 测试

**Files:**
- Modify: `tests/test-core-search.ps1`（在 "grep parameter tests" Describe 内追加）

**背景：** `core-search.ps1` 被测试文件**点源**（`. core-search.ps1`），归因可靠。真实缺口：第 9 行（`-v` 旗标累计）、第 38 行（missing pattern）、第 59 行（`-v` 反向分支）。`testFile` 内容为 `"hello world"`, `"test line"`, `"HELLO again"`。

- [ ] **Step 1: 写失败测试**

  在 `tests/test-core-search.ps1` 的 "grep parameter tests" Describe 中追加：

```powershell
    It "Inverts matches with -v" {
        $result = grep -v 'hello' $testFile1
        @($result).Count | Should Be 2
        (@($result) -join '|') -match 'test line' | Should Be $true
    }

    It "Combines -i and -v for case-insensitive invert" {
        $result = grep -i -v 'hello' $testFile1
        @($result).Count | Should Be 1
        (@($result) -join '|') -match 'test line' | Should Be $true
    }

    It "Reports an error when no pattern is given" {
        $out = @(grep -ArgList @() 2>&1)
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }
```

  说明：`grep -v 'hello'` 大小写敏感反向 → 保留 `test line` 和 `HELLO again`（Count 2）；`grep -i -v` 大小写不敏感 → 仅保留 `test line`（Count 1）。`-ArgList @()` 强制空位置参数，触发第 38 行。

- [ ] **Step 2: 运行确认新测试通过**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; Invoke-Pester -Path 'tests\test-core-search.ps1' -PassThru | Out-Host"`
  Expected: Failed: 0。新 3 个测试 [+]（第 9、38、59 行被覆盖）。

- [ ] **Step 3: 跑完整套件回归**

  Run: `& 'D:\Codes\powershell-bash-aliases\tests\run-tests.ps1'`
  Expected: `Failed: 0`。

- [ ] **Step 4: Commit**

```bash
git add tests/test-core-search.ps1
git commit -m "test(core-search): cover grep -v invert and missing-pattern paths
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: fg/bg 最近作业路径与 job-not-found 测试

**Files:**
- Modify: `tests/test-core-process-coverage.ps1`（bg Describe、fg Describe 内追加）

**背景：** `test-core-process-coverage.ps1` 用 `Import-Module` + `Set-JobTable`/`Reset-JobTable` 助手操作模块作用域 `$script:JobTable`。真实缺口：bg/fg 的**无参取最近作业路径**（231-232 / 285-286 行）与 **job-not-found 回退**（255 / 312 行，`$job` 无 State 属性时）。现有测试已覆盖 help、无作业、越界、零、非数字、按 id 恢复。

- [ ] **Step 1: 写失败测试**

  在 "bg" Describe（现有 `Resumes an existing job without throwing` 之后）追加：

```powershell
    It "Resumes the most recent job when no id is given" {
        $job = Start-Job -ScriptBlock { Start-Sleep -Seconds 30 }
        Set-JobTable @{ 'j1' = $job }
        { & $script:bgFunc } | Should Not Throw
        (& $script:module { $script:JobTable.Count }) | Should Be 1
    }

    It "Reports job not found when the job has no State property" {
        Set-JobTable @{ 'j1' = @{ Id = 99 } }
        $result = @(& $script:bgFunc 1 2>&1)
        $result[0].ToString() -match 'job not found' | Should Be $true
    }
```

  在 "fg" Describe（现有 `Brings a job to the foreground and removes it` 之后）追加：

```powershell
    It "Brings the most recent job to the foreground when no id is given" {
        $job = Start-Job -ScriptBlock { Start-Sleep -Milliseconds 300; Write-Output 'fg-done' }
        Set-JobTable @{ 'j1' = $job }
        $result = @(& $script:fgFunc 2>&1)
        ($result -join "`n") -match 'Bringing job to foreground' | Should Be $true
        (& $script:module { $script:JobTable.Count }) | Should Be 0
    }

    It "Reports job not found when the job has no State property" {
        Set-JobTable @{ 'j1' = @{ Id = 99 } }
        $result = @(& $script:fgFunc 1 2>&1)
        $result[0].ToString() -match 'job not found' | Should Be $true
    }
```

  说明：`@{ Id = 99 }` 无 `State` 属性 → `$job.PSObject.Properties['State']` 为假 → 走 `Write-BashError 'job not found'`。fg 最近作业用 300ms 短任务，`Wait-Job -Timeout -1` 快速返回并从表移除（Count 0）。bg 用 30s 任务（与现有测试 131 同款，防提前完成导致 Receive-Job 行为差异）。

- [ ] **Step 2: 运行确认新测试通过**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; Invoke-Pester -Path 'tests\test-core-process-coverage.ps1' -PassThru | Out-Host"`
  Expected: Failed: 0。4 个新测试 [+]（231-232、255、285-286、312 行被覆盖）。

- [ ] **Step 3: 跑完整套件回归**

  Run: `& 'D:\Codes\powershell-bash-aliases\tests\run-tests.ps1'`
  Expected: `Failed: 0`。

- [ ] **Step 4: Commit**

```bash
git add tests/test-core-process-coverage.ps1
git commit -m "test(core-process): cover bg/fg most-recent-job and job-not-found paths
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: nohup 后台执行测试

**Files:**
- Modify: `tests/test-core-process-coverage.ps1`（"nohup" Describe 内追加）

**背景：** nohup 的 `Start-Job`/`Register-ObjectEvent`/`Receive-Job`/写 `nohup.out` 整条执行路径（348-374 行）未覆盖。此测试**有真实时序依赖**，是全部任务中风险最高者：事件处理器在后台线程触发。用轮询替代固定 sleep。

- [ ] **Step 1: 写测试（含事件订阅清理）**

  在 "nohup" Describe 内追加：

```powershell
    It "Starts a background job and appends output to nohup.out" {
        Reset-JobTable
        $nohupOut = Join-Path $PWD 'nohup.out'
        Remove-Item $nohupOut -Force -ErrorAction SilentlyContinue
        $r = @(& $script:nohupFunc Write-Output 'hello-nohup' 2>&1)
        ($r -join "`n") -match 'Started background job' | Should Be $true
        $deadline = (Get-Date).AddSeconds(15)
        while (-not (Test-Path $nohupOut) -and (Get-Date) -lt $deadline) {
            Start-Sleep -Milliseconds 250
        }
        Test-Path $nohupOut | Should Be $true
        (Get-Content $nohupOut -Raw) -match 'hello-nohup' | Should Be $true
        Remove-Item $nohupOut -Force -ErrorAction SilentlyContinue
        # Clean up the event subscription and completed jobs registered by nohup
        Get-EventSubscriber -ErrorAction SilentlyContinue | Unregister-Event -Force -ErrorAction SilentlyContinue
        Reset-JobTable
    }
```

  说明：`Write-Output 'hello-nohup'` 作为作业秒级完成 → StateChanged 事件 → `Receive-Job` → `Out-File nohup.out`。轮询最长 15s。测试尾部清理事件订阅与 JobTable，防止跨测试污染。

- [ ] **Step 2: 运行确认测试通过（可能需调试）**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; Invoke-Pester -Path 'tests\test-core-process-coverage.ps1' -PassThru | Out-Host"`
  Expected: Failed: 0。

  **若失败，按此顺序排查：**
  1. `nohup.out` 未生成 → 事件动作里 `Join-Path $PWD 'nohup.out'` 的 `$PWD` 在模块事件作用域可能解析异常。临时用 `Write-Host` 在事件动作加日志，或改用 `Get-Location` 调试。若确认 `$PWD` 问题，属生产缺陷，**记录但不修**，并将断言放宽为仅验证 `Started background job` 输出与 JobTable 计数（如实标注 348-374 行仍为已知缺口）。
  2. 作业未完成 → 检查命令拼写 `Write-Output` 在 `Start-Job -ScriptBlock { param($cmd,$args) & $cmd @args }` 中是否被正确转发。可改用 `'sleep'` 命令等更直观的载体（`& $script:nohupFunc sleep 1`）。

- [ ] **Step 3: 跑完整套件回归**

  Run: `& 'D:\Codes\powershell-bash-aliases\tests\run-tests.ps1'`
  Expected: `Failed: 0`。

- [ ] **Step 4: Commit**

```bash
git add tests/test-core-process-coverage.ps1
git commit -m "test(core-process): cover nohup background job execution and nohup.out
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: file symlink 诚实记账 + 短 -help 覆盖

**Files:**
- Modify: `tests/test-core-file-coverage.ps1:164-180`（symlink 测试）
- Modify: `tests/test-core-file-coverage.ps1`（"file command coverage" Describe 内追加短 -help 测试）

**背景（已验证的归因伪影）：** 隔离运行（仅 `test-core-file-coverage.ps1` + 仅测 `core-file.ps1`）确认：测试 137/142（未知扩展名文本→ASCII text、空文件→data）**通过**，但 Pester 仍报 803/805/808 未覆盖——这是 Pester 3.4.0 对模块导入函数部分分支的**归因缺陷**，代码确实执行，**非真实缺口**，无需补测试。真实缺口仅：第 698 行（短 `-help`）与 symlink 分支 736-737（本机若允许创建符号链接）。

- [ ] **Step 1: symlink 测试改用 Set-ItResult -Skipped 诚实记账**

  将现有 symlink 测试（164-180 行）的 else 分支 `$true | Should Be $true` 替换为：

```powershell
    It "reports a file symbolic link when creation is permitted" {
        $target = Join-Path $script:fileRoot "file.txt"
        $link = Join-Path $script:fileRoot "filelink.lnk"
        $created = $false
        try {
            New-Item -ItemType SymbolicLink -Path $link -Target $target -ErrorAction Stop | Out-Null
            $created = $true
        } catch {
            $created = $false
        }
        if (-not $created) {
            Set-ItResult -Skipped -Because "symlink creation requires admin or developer mode"
            return
        }
        $result = & $script:fileFunc $link
        @($result | Where-Object { $_ -match 'symbolic link' }).Count | Should Be 1
    }
```

  动机：原实现无权限时静默通过（`$true | Should Be $true`），掩盖 symlink 分支未被验证的事实；`Set-ItResult -Skipped` 让跳过可见、统计诚实。

- [ ] **Step 2: 追加短 -help 测试（覆盖 698/710 行）**

  在 "file command coverage" Describe 内追加：

```powershell
    It "shows usage with short -help" {
        $result = & $script:fileFunc -help
        (@($result -join '') -match 'Usage: file') | Should Be $true
    }
```

- [ ] **Step 3: 运行确认通过**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; Invoke-Pester -Path 'tests\test-core-file-coverage.ps1' -PassThru | Out-Host"`
  Expected: Failed: 0。Skipped 计数如实反映本机是否允许符号链接。

- [ ] **Step 4: 跑完整套件回归**

  Run: `& 'D:\Codes\powershell-bash-aliases\tests\run-tests.ps1'`
  Expected: `Failed: 0`。

- [ ] **Step 5: Commit**

```bash
git add tests/test-core-file-coverage.ps1
git commit -m "test(core-file): honest symlink skip accounting + short -help coverage
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: tar -v/-j/-C/-help 分支测试

**Files:**
- Modify: `tests/test-core-compress-coverage.ps1`（"tar coverage" Describe 内追加）

**背景：** tar 测试已 Mock `tar` 并覆盖 create/extract/list 主路径。真实缺口：第 16/18/19 行（`-v`/`-j`/`-help` 旗标累计）、第 47 行（`-C` 目标目录）。注意：`-v`/`-j` 当前**被解析但不会改变传给原生 tar 的参数**（create 路径仅 `-z` 会切换 `-cf`→`-czf`，见 core-compress.ps1:64-70）——这是既有行为，本计划测试**断言现状**，不修生产代码。

- [ ] **Step 1: 写失败测试**

  在 "tar coverage" Describe（现有 `tar create with -z passes -czf to native tar` 之后）追加：

```powershell
    It "tar accepts short -help and shows usage" {
        $r = & $script:tarFunc -help
        @($r)[0] -match 'Usage: tar' | Should Be $true
    }

    It "tar create accepts -v verbose flag" {
        $r = & $script:tarFunc -c -v -f $script:tarArch $script:tarSrc
        (@($r) -join ' ') -match '\-cf' | Should Be $true
    }

    It "tar create accepts -j bzip2 flag" {
        $r = & $script:tarFunc -c -j -f $script:tarArch $script:tarSrc
        (@($r) -join ' ') -match '\-cf' | Should Be $true
    }

    It "tar extract honors -C target directory" {
        $r = & $script:tarFunc -x -C $script:tarWork -f $script:tarArch
        (@($r) -join ' ') -match 'MOCK-TAR' | Should Be $true
    }
```

  说明：`-help` 绑定 `[switch]$help` → 第 19 行累计 + 走 help 分支。`-v`/`-j` 断言 `-cf` 出现在 Mock 收到的参数里（现状：`-v`/`-j` 不改变 flag）。`-C $script:tarWork` 走第 47 行 `Convert-BashPath` + extract 的 `Push-Location $targetDir`。

- [ ] **Step 2: 运行确认通过**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; Invoke-Pester -Path 'tests\test-core-compress-coverage.ps1' -PassThru | Out-Host"`
  Expected: Failed: 0。4 个新测试 [+]（16、18、19、47 行被覆盖）。

- [ ] **Step 3: 跑完整套件回归**

  Run: `& 'D:\Codes\powershell-bash-aliases\tests\run-tests.ps1'`
  Expected: `Failed: 0`。

- [ ] **Step 4: Commit**

```bash
git add tests/test-core-compress-coverage.ps1
git commit -m "test(core-compress): cover tar -v/-j/-C/-help branches
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: run-tests.ps1 用真实 -CodeCoverage 替代硬编码估算

**Files:**
- Modify: `tests/run-tests.ps1`（删除第 35-112 行的硬编码估算，替换为真实测量）

**背景：** 现状估算表（函数计数）漏掉 `core-compress.ps1`(7)、`args-parser.ps1`(3)，函数数过期（utils 实际 8 声称 5 等），且把"源码正则检查"测试也算作覆盖。真实命令级覆盖由 `Invoke-Pester -CodeCoverage` 提供。Pester 3.4.0 的 `CoveragePercent` 恒为 0（显示 bug），须手动 `Executed/Analyzed` 计算。**本任务依赖 Task 1**（否则 awk 7 测试在插桩下失败、数字失真）。

- [ ] **Step 1: 重写估算部分**

  将 `tests/run-tests.ps1` 第 35-112 行（`Write-Host "Coverage Estimation:"` 到目标检查结束）整体替换为：

```powershell
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
```

  说明：一次完整套件约 35s，带覆盖率约 40s；重跑一次以获得归因数据是必要开销（可接受）。

- [ ] **Step 2: 运行验证输出**

  Run: `& 'D:\Codes\powershell-bash-aliases\tests\run-tests.ps1'`
  Expected:
  - `Failed: 0`（awk 已在 Task 1 修复，插桩下不再失败）。
  - 输出 `Commands executed/analyzed: XXXX/XXXX = NN.N%`，NN.N ≥ 92（高于 85 目标）。
  - "Missed by function" 前几名为 watch / Show-PagedOutput / uniq（已知缺口或伪影）。
  - 三条 caveat 提示打印。

- [ ] **Step 3: 确认数值可信度（抽查）**

  Run: `powershell -NoProfile -Command "Set-Location 'D:\Codes\powershell-bash-aliases'; \$r = Invoke-Pester -Path 'tests\test-core-search.ps1' -CodeCoverage 'core-search.ps1' -PassThru; \$r.CodeCoverage.NumberOfCommandsMissed"`
  Expected: 相比 Task 2 之前，grep 的 missed 减少（`-v` 相关行已覆盖）。

- [ ] **Step 4: Commit**

```bash
git add tests/run-tests.ps1
git commit -m "feat(tests): replace hardcoded coverage estimate with real -CodeCoverage measurement
Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Self-Review

**Spec 覆盖（用户 4 项）：**
- 第 1 项（真实 -CodeCoverage 替代硬编码）→ **Task 7**。92.7% 基线被真实测量替代；`CoveragePercent=0` bug 通过手动计算规避。
- 第 2 项（修 run-tests.ps1 表：补 core-compress、args-parser、实际函数数）→ **Task 7**。硬编码表整体删除，改用真实命令级测量（涵盖全部 12 个源文件，含 core-compress 与 args-parser）；实际函数数由命令级数据隐式体现。
- 第 3 项（补高价值测试）→ **Tasks 2-6**。`grep -v`(2)、fg/bg(3)、nohup(4)、file symlink/MIME(5)、tar -v/-j(6)。其中 file 的 MIME 分支经实证为**归因伪影**（测试已存在且通过），故仅改进 symlink 诚实记账与补短 -help。
- 第 4 项（awk 可靠覆盖：升级 Pester 5+ 或接受 3.4.0 限制）→ **Task 1**。实证发现 awk 的 `$f`/`$F` 冲突已修复、可直接调用 → 采用"重构测试直接调用 awk"方案，**不需要**升级 Pester 5（会破坏全部 671 测试的 Pester 3 语法）。tr/uniq 的 `*_copy` 归因限制在 Task 7 输出中如实标注。

**占位符扫描：** 无 TBD/占位。所有测试代码与 run-tests.ps1 替换段为完整可粘贴内容。Task 4 的调试分支给出具体排查命令与降级断言，非占位。

**类型/命名一致性：**
- `$script:awkFunc`（Task 1）与 test 文件第 336 行一致；`$script:awkCopy` 全部替换，无残留引用。
- `Set-JobTable`/`Reset-JobTable`（Task 3/4）与文件现有助手签名一致；`$script:module` 沿用现有用法。
- `$script:tarWork`/`$script:tarArch`/`$script:tarSrc`（Task 6）与 "tar coverage" Describe 现有 BeforeAll 变量一致。
- `$script:fileRoot`（Task 5）与文件现有 BeforeAll 一致；`Set-ItResult -Skipped -Because` 为 Pester 3.4.0 支持语法。
- `$scriptDir`（Task 7）沿用 run-tests.ps1 顶部定义；`Join-Path $scriptDir "..\$_"` 解析到仓库根。

**依赖检查：** Task 1 是 Task 7 的前置（否则插桩下 awk 失败）。Task 2-6 相互独立、可任意次序。Task 7 放在最后以获得含新测试的完整数字。

---

## 实施交接

计划已保存至 `docs/superpowers/plans/2026-08-13-real-test-coverage.md`。两种执行方式：

**1. 子代理驱动（推荐）** — 每任务派发一个全新子代理，任务间审查，快速迭代
**2. 当前会话内联执行** — 用 executing-plans 批量执行，带检查点审查

选哪种？
