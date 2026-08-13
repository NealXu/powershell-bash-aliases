# Detached Test-Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `run-tests-detached.ps1` — a one-command wrapper that runs the full test suite in a separate PowerShell window (outside the Claude Code CLI), returns immediately so the CLI is never blocked, keeps a `Start-Transcript` log under `%TEMP%`, and document the workflow in the README.

**Architecture:** A single PowerShell script at the repo root. It builds a child command string that runs `Start-Transcript` (captures `Write-Host` + Pester host output, which `| Tee-Object` cannot), `Set-Location` to the repo, runs `tests/run-tests.ps1`, then `Stop-Transcript`; spawns it via `Start-Process powershell.exe -NoProfile -NoExit` in a new visible window and returns immediately. Placing the script at the repo ROOT (not under `tests/`) is deliberate: `tests/run-tests.ps1` discovers every `*.ps1` in `tests/` as a test file, so a `run-tests-detached.ps1` there would be executed by the suite itself and would pop a window mid-run.

**Tech Stack:** Windows PowerShell 5.1, existing `tests/run-tests.ps1`. No product files and no runner changes.

## Global Constraints

- Windows PowerShell 5.1 only (the suite targets 5.1); script ASCII-safe.
- **Do NOT modify `tests/run-tests.ps1`, any `core-*.ps1`, or any product file.** This adds one new script + a README note.
- The new script MUST live at the repo root (`run-tests-detached.ps1`), NOT under `tests/` — the test suite treats every `tests\*.ps1` (except `run-tests.ps1`) as a test file and would execute a detached runner, popping a window mid-suite.
- Transcript log MUST go to `$env:TEMP` (never the repo), so no `.gitignore` change is needed and the repo stays clean.
- The child process MUST run with `-NoProfile` (no user-profile side effects) and `-NoExit` (the window stays open so the user can read the final summary).
- The wrapper MUST return in ~1 s (non-blocking). It is NOT Pester-tested (opening terminal windows from a test is undesirable); it is verified functionally.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `run-tests-detached.ps1` | Create | Repo-root wrapper: spawn `tests/run-tests.ps1` in a new visible PowerShell window with `Start-Transcript` logging to `%TEMP%\bash-aliases-tests-<timestamp>.log`; return immediately. |
| `README.md` | Modify | Add a one-command note in the "### 运行测试" section explaining the detached run + where the transcript log goes. |

---

### Task 1: Create `run-tests-detached.ps1`

**Files:**
- Create: `run-tests-detached.ps1`

**Interfaces:**
- Consumes: `tests/run-tests.ps1` (existing, unchanged), `$env:TEMP`.
- Produces: the detached child window running the suite; a transcript log at `$env:TEMP\bash-aliases-tests-<yyyyMMdd-HHmmss>.log`; stdout messages `Test suite started in a separate window...` and `Transcript log: <path>`.

- [ ] **Step 1: Write `run-tests-detached.ps1`** at the repo root:

```powershell
# run-tests-detached.ps1
# Run the full test suite in a SEPARATE PowerShell window, detached from the
# Claude Code CLI. The CLI's blue "Processing" bar is only shown while a tool
# call is running, so a ~51 s suite run parks it; spawning a detached window
# makes this wrapper return in ~1 s and keeps the CLI responsive. The suite runs
# live in its own window and a full Start-Transcript log is written to $env:TEMP
# for later inspection.
# Windows PowerShell 5.1. ASCII-safe.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot  = Split-Path $scriptDir -Parent
$log       = Join-Path $env:TEMP ("bash-aliases-tests-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')

# Start-Transcript (not Tee-Object) is required: run-tests.ps1 and Pester write
# to the host (Write-Host), which never enters the pipeline, so piping cannot
# capture the colored summary. -NoProfile avoids user-profile side effects in
# the child; -NoExit keeps the window open so the results stay readable.
$childCmd = "Start-Transcript -Path '$log' -Force; Set-Location -LiteralPath '$repoRoot'; .\tests\run-tests.ps1; Stop-Transcript"

Start-Process powershell.exe -ArgumentList @('-NoProfile', '-NoExit', '-Command', $childCmd) -WorkingDirectory $repoRoot | Out-Null

Write-Output "Test suite started in a separate window (returns immediately)."
Write-Output "Live results are in that window."
Write-Output "Transcript log: $log"
```

- [ ] **Step 2: Verify it spawns detached, returns immediately, and completes with a readable log**

From the repo root in Windows PowerShell 5.1:
```powershell
.\run-tests-detached.ps1
```
Expected: the command prints the two `Write-Output` lines and returns within ~1–2 s (NOT blocked for the ~51 s suite). A new PowerShell window opens and runs the suite live. Then confirm the transcript log completes — poll for the suite summary inside it (allow up to 150 s for the suite):
```powershell
$log = Get-ChildItem $env:TEMP -Filter 'bash-aliases-tests-*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$deadline = (Get-Date).AddSeconds(150)
while ((Get-Date) -lt $deadline -and -not (Select-String -Path $log.FullName -Pattern 'Test Results Summary' -Quiet)) { Start-Sleep -Seconds 3 }
Select-String -Path $log.FullName -Pattern 'TotalCount|PassedCount|FailedCount|SkippedCount'
```
Expected: the log shows `TotalCount 709`, `PassedCount 691`, `FailedCount 0`, `SkippedCount 18` (the current suite baseline). If the summary never appears within 150 s, the detached child failed — investigate the child command (check `$env:TEMP` for a transcript with an error).

- [ ] **Step 3: Confirm the repo stays clean**

Run `git status --short`. Expected: only `?? run-tests-detached.ps1` (the transcript lives in `$env:TEMP`, so nothing in the repo). If a transcript/log file appears in the repo root, fix the `$log` path to `$env:TEMP` before committing.

- [ ] **Step 4: Commit**

```bash
git add run-tests-detached.ps1
git commit -m "feat(test): detached full-suite runner (separate window + transcript log)"
```

---

### Task 2: Document the detached run in the README

**Files:**
- Modify: `README.md` — in the "### 运行测试" block (currently ends at the `> run-tests.ps1 会自动收集 test-e2e.ps1...` blockquote).

**Interfaces:**
- Consumes: the script created in Task 1.

- [ ] **Step 1: Add the detached-run note to README**

After the existing blockquote that ends the "### 运行测试" section, add:

```markdown
# 在独立终端运行全量套件（避免在 Claude Code CLI 中阻塞/进度条驻留）：
.\run-tests-detached.ps1

# 该命令会新开一个 PowerShell 窗口并在其中运行 run-tests.ps1，立即返回；
# 完整输出（Start-Transcript）会写入 %TEMP%\bash-aliases-tests-<时间戳>.log。
```

- [ ] **Step 2: Verify the README section renders coherently**

Re-read the "### 运行测试" section; confirm the new lines sit inside the fenced code block and the blockquote follows it cleanly (no dangling fence).

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document detached full-suite run"
```

---

## Self-Review

**Spec coverage (the "run outside the CLI" direction):** Detached window runner → Task 1; transcript log for later inspection → Task 1 (captures `Write-Host`/Pester output that piping cannot); immediate return so the CLI stays free → Task 1 verified in Step 2 (returns in ~1–2 s); README documentation → Task 2. The manual alternative (user opens a terminal by hand) is noted in the plan's framing but needs no code — the wrapper is the implementable form.

**Placeholder scan:** No TBD/TODO; the script, verification commands, expected log values, and commit messages are concrete. The placement constraint (repo root, not `tests/`) and the `Start-Transcript`-vs-pipe rationale are stated so an implementer does not "improve" them into a bug (runner self-collection, or empty logs).

**Type/signature consistency:** `$scriptDir`/`$repoRoot`/`$log`/`$childCmd` are defined once and used consistently; `$log` is `Join-Path $env:TEMP (...)` in both the script and the verification snippet. `tests/run-tests.ps1` is invoked by its existing relative path from the child's `Set-Location`. No new module functions or cross-task contracts.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-13-detached-test-runner.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
