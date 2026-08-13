# Detached Test-Runner Default + `-Wait` Summary Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `-Wait` mode to `run-tests-detached.ps1` that blocks on the child process handle (not polling) and prints a clean result summary (Total/Passed/Failed/Skipped/Coverage) with a proper exit code, then standardize `.\run-tests-detached.ps1` as the documented default way to run the full suite.

**Architecture:** The existing headless runner stays the default (spawn hidden child, return immediately). New `-Wait` switch: `Start-Process -PassThru` → `$proc.WaitForExit()` (deterministic, no polling) → read the transcript once, strip ANSI (`"\x1b\[[0-9;]*[A-Za-z]"`), extract the summary via run-tests.ps1's own stable labels, print it, and exit 1 if run-1 `Failed` > 0. README's "运行测试" section is restructured to lead with the detached runner.

**Tech Stack:** Windows PowerShell 5.1, existing `run-tests-detached.ps1`, `tests/run-tests.ps1` (unchanged), `README.md`.

## Global Constraints

- Windows PowerShell 5.1 only; script ASCII-safe.
- **Do NOT modify `tests/run-tests.ps1` or any test/product file.** Only `run-tests-detached.ps1` and `README.md`.
- `-Wait` uses `WaitForExit()` on the child handle — NOT a polling loop (that is the whole point of the design).
- Summary extraction parses the transcript with run-tests.ps1's stable labels (`Total Tests:`, `Passed:`, `Failed:`, `Skipped:`, `= <pct>%`); ANSI is stripped first so `-ForegroundColor` codes do not break the regexes.
- Default (no `-Wait`) behavior is unchanged: return immediately, print the log path.
- The `-Wait` run takes ~3 min (run-tests.ps1 runs the suite twice); that is expected and documented.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `run-tests-detached.ps1` | Modify | Add `[switch]$Wait`; `-PassThru`; `-Wait` blocks then prints the parsed summary and exits with a failure code. |
| `README.md` | Modify | "运行测试" section leads with `.\run-tests-detached.ps1` (default detached; `-Wait` for inline summary); `tests\run-tests.ps1` documented as the low-level runner. |

---

### Task 1: Add `-Wait` + auto-printed summary to `run-tests-detached.ps1`

**Files:**
- Modify: `run-tests-detached.ps1`

**Interfaces:**
- Consumes: existing headless child command (`Start-Transcript` + `Set-Location` + `.\tests\run-tests.ps1` + `Stop-Transcript`).
- Produces: `-Wait` prints `Test Results Summary:` with Total/Passed/Failed/Skipped/Coverage, then exits 0 (all passed) or 1 (run-1 failures > 0). Default still prints `Transcript log: <path>` and returns immediately.

- [ ] **Step 1: Replace `run-tests-detached.ps1` with the `-Wait`-capable version**

```powershell
# run-tests-detached.ps1
# Run the full test suite in the BACKGROUND, detached from the Claude Code CLI.
# The CLI's blue "Processing" bar is only shown while a tool call is running, so
# a ~51 s suite run parks it; spawning a hidden background process makes this
# wrapper return in ~1 s and keeps the CLI responsive. No window is left behind:
# the child runs headless (-WindowStyle Hidden) to completion and exits, and a
# full Start-Transcript log is written to $env:TEMP for later inspection.
# Usage:
#   .\run-tests-detached.ps1            # detached: returns immediately, log path printed
#   .\run-tests-detached.ps1 -Wait      # blocks on the child, then prints a clean summary
# Windows PowerShell 5.1. ASCII-safe.

param(
    [switch]$Wait   # wait for the suite to finish, then print the result summary
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# The wrapper lives AT the repo root, so the repo root is the script's own dir.
$repoRoot  = $scriptDir
$log       = Join-Path $env:TEMP ("bash-aliases-tests-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')

# Start-Transcript (not Tee-Object) is required: run-tests.ps1 and Pester write
# to the host (Write-Host), which never enters the pipeline, so piping cannot
# capture the colored summary. -NoProfile avoids user-profile side effects.
# No -NoExit: the child runs the suite to completion and exits, so no window
# lingers afterward. -WindowStyle Hidden keeps it fully headless.
$childCmd = "Start-Transcript -Path '$log' -Force; Set-Location -LiteralPath '$repoRoot'; .\tests\run-tests.ps1; Stop-Transcript"

$proc = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-Command', $childCmd) -WindowStyle Hidden -WorkingDirectory $repoRoot -PassThru

if (-not $Wait) {
    Write-Output "Test suite started in the background (headless, returns immediately)."
    Write-Output "Transcript log: $log"
    exit 0
}

# -Wait: block on the PROCESS HANDLE (not a poll), then read the transcript once.
$proc.WaitForExit()

# Strip ANSI color codes so Write-Host -ForegroundColor output parses cleanly.
$clean = (Get-Content $log -Raw -ErrorAction SilentlyContinue) -replace "\x1b\[[0-9;]*[A-Za-z]", ""

$total   = if ($clean -match 'Total Tests:\s*(\d+)')     { $matches[1] } else { '?' }
$passed  = if ($clean -match 'Passed:\s*(\d+)')          { $matches[1] } else { '?' }
$failed  = if ($clean -match 'Failed:\s*(\d+)')          { $matches[1] } else { '?' }
$skipped = if ($clean -match 'Skipped:\s*(\d+)')         { $matches[1] } else { '?' }
$coverage= if ($clean -match '= ([\d.]+)%')              { $matches[1] } else { '?' }
$covWarn = if ($clean -match 'failed during the coverage run') { ' (run-2 warning)' } else { '' }

Write-Output "Test Results Summary:"
Write-Output "  Total Tests: $total"
Write-Output "  Passed: $passed"
Write-Output "  Failed: $failed"
Write-Output "  Skipped: $skipped"
Write-Output "  Coverage: $coverage%$covWarn"
Write-Output "Transcript log: $log"

if ($failed -match '^\d+$' -and [int]$failed -gt 0) { exit 1 } else { exit 0 }
```

- [ ] **Step 2: Verify default mode still returns immediately**

Run from the repo root:
```powershell
.\run-tests-detached.ps1
```
Expected: prints `Test suite started in the background...` and `Transcript log: <path>`, returns within ~1 s (NOT blocked), no visible window, no lingering process after.

- [ ] **Step 3: Verify `-Wait` prints the summary and exits correctly**

Run:
```powershell
.\run-tests-detached.ps1 -Wait; Write-Output "EXITCODE=$LASTEXITCODE"
```
Expected: this blocks ~3 min (two suite passes), then prints:
```
Test Results Summary:
  Total Tests: 709
  Passed: 691
  Failed: 0
  Skipped: 18
  Coverage: 93.9%
Transcript log: C:\...\bash-aliases-tests-<ts>.log
EXITCODE=0
```
Confirm: the numbers match the current suite baseline, `$LASTEXITCODE` is 0, and afterwards no `run-tests` powershell process lingers (the child exited on its own).

- [ ] **Step 4: Commit**

```bash
git add run-tests-detached.ps1
git commit -m "feat(test): add -Wait mode with auto-printed summary to detached runner"
```

---

### Task 2: Standardize the detached runner as the default in README

**Files:**
- Modify: `README.md` — the "### 运行测试" section.

**Interfaces:**
- Consumes: the `-Wait`-capable runner from Task 1.

- [ ] **Step 1: Restructure the "运行测试" section**

Replace the current detached-run note (the fenced block that begins `# 在后台无窗口运行全量套件...`) with a restructured section that leads with the detached runner. Read the current section first to place the edit precisely. New content (replace the existing detached-run fenced block, keep the `> run-tests.ps1 会自动收集 test-e2e.ps1...` blockquote):

```markdown
> 运行全量套件默认使用 detached 方式（headless，不弹窗、不阻塞 Claude Code CLI、无进度条驻留）：

```powershell
# 默认：后台无窗口运行，立即返回；结果写入 %TEMP% 日志
.\run-tests-detached.ps1

# 交互式：等待套件跑完，自动打印汇总（Total/Passed/Failed/Skipped/Coverage + 退出码）
.\run-tests-detached.ps1 -Wait

# 读取最近一次日志
Get-ChildItem $env:TEMP -Filter 'bash-aliases-tests-*.log' |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1 | Get-Content
```

> `tests\run-tests.ps1` 仍是低层运行器（含命令级覆盖率），需要直接跑原始输出时使用。
```

- [ ] **Step 2: Verify the README renders coherently**

Re-read the "### 运行测试" section; confirm the fenced code blocks and blockquotes nest cleanly (no dangling fence, no orphaned text).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: make detached runner the default full-suite command"
```

---

## Self-Review

**Spec coverage (the ask: "better than polling" + make it the default):** `-Wait` uses `WaitForExit()` on the process handle, not a poll → Task 1 Step 1. Auto-printed summary with coverage and exit code → Task 1. Default stays detached/non-blocking → Task 1 Step 2 verifies. Default documentation → Task 2. The "structured sidecar" (Approach C) was deliberately NOT chosen — the transcript's stable labels + ANSI-stripping cover it with fewer moving parts.

**Placeholder scan:** No TBD/TODO; the full script, verification commands, expected summary values (709/691/0/18/93.9%), and exit-code expectations are concrete.

**Type/signature consistency:** `$proc.WaitForExit()` is called only in `-Wait`; `$clean` is the ANSI-stripped transcript used by all regexes; `$matches[1]` is used immediately after each `-match` on `$clean`. The regex labels (`Total Tests:`, `Passed:`, `Failed:`, `Skipped:`, `= <pct>%`) match run-tests.ps1's own output verbatim (verified against `tests/run-tests.ps1:29-33,56`). No new cross-task contracts.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-13-run-tests-default.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
