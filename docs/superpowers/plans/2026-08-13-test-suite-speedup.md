# Test Suite Job-Test Speedup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Cut the wall-clock cost of the job-related Pester tests (`jobs`/`bg`/`fg`/`nohup`) in `test-core-process-coverage.ps1`, `test-core-process.ps1`, and `test-e2e.ps1` by removing the job scriptblock sleeps that add pure cost, sharing one `Start-Job` across the non-consuming `bg` resume tests, and tightening the `nohup.out` poll, without changing module behavior or making any assertion racy.

**Architecture:** Test-only changes. No product files touched. Measured floor: on this machine `Start-Job` process boot is ~1.7 s and irreducible in PS 5.1 (no `Start-ThreadJob`, no module to install). So the plan removes only the *additive* sleeps and spawns, keeps every sleep whose removal would race an assertion, and records before/after timings so the bounded gain (~1.5–2 s of a ~52 s suite) is verified, not assumed.

**Tech Stack:** Pester 3.4.0, Windows PowerShell 5.1, existing `tests/test-core-process-coverage.ps1`, `tests/test-core-process.ps1`, `tests/test-e2e.ps1`.

## Global Constraints

- Windows PowerShell 5.1 + Pester 3.4.0 only; test files stay ASCII-only.
- **Do NOT modify any product file** (`core-process.ps1`, `install.ps1`, etc.). These are test-speed changes only.
- **Do NOT shorten a job's sleep where an assertion depends on the job still being alive.** The only such case is `nohup` "Launches a command as a background job" (`test-core-process-coverage.ps1:304`): it asserts `$script:JobTable.Count -gt 0`, and the module's `Register-ObjectEvent` removes a completed job from the table. That sleep stays at `-Seconds 30` (measured boot can reach ~2.7 s, so even 3 s would be racy against the ~0.5 s assertion window).
- `bg`/`fg` do NOT rely on the job staying alive: `bg` calls non-blocking `Receive-Job`, `fg` calls `Wait-Job -Timeout -1` then removes the job from the table. Their sleeps are safe to shorten/remove. (Verified against `core-process.ps1:202-314`.)
- The `nohup.out` poll in both nohup tests must be **content-based** (wait for the marker inside the file, 100 ms interval) — not file-existence-based. The `*>>` redirection creates the file before the child flushes output, so `Test-Path` alone races an empty file (observed as a flaky failure under load during baseline). This fix is REQUIRED, not optional.
- Every task re-runs its file(s) and confirms all tests still pass; the `fg` and `jobs` waits keep their ~1.7 s boot floor — that is expected, not a regression.
- Expected gain is bounded (~1.5–2 s of ~52 s); the plan's verification must report the real before/after delta.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `tests/test-core-process-coverage.ps1` | Modify | Remove `fg` job sleeps (×2), shorten `bg` job sleeps 30 s→200 ms (×2), share one `bg` job via `BeforeAll`/`AfterAll`, tighten `nohup.out` poll 250→100 ms. Keep the `nohup`-launch 30 s and the `jobs`-cleanup wait (floors). |
| `tests/test-core-process.ps1` | Modify | Shorten the `bg` resume-test job sleep 30 s→200 ms. |
| `tests/test-e2e.ps1` | Modify | Tighten `nohup.out` poll 250→100 ms in the installed-module nohup smoke. |

---

### Task 1: Tune job tests in `test-core-process-coverage.ps1`

**Files:**
- Modify: `tests/test-core-process-coverage.ps1` — `bg` Describe (`:103`), `fg` jobs (`:182`, `:190`), `nohup` append poll (`:331`).

**Interfaces:**
- Consumes: `$script:bgFunc`, `$script:fgFunc`, `$script:nohupFunc`, `$script:module` (existing refs), `Reset-JobTable`/`Set-JobTable` (existing helpers, `:34-41`).
- Produces: `$script:sharedBgJob` (a single `Start-Job` object created in the `bg` Describe's `BeforeAll`, consumed by both resume tests, removed in `AfterAll`).

- [ ] **Step 1: Record the baseline timings for this file**

Run:
```powershell
Import-Module Pester -ErrorAction Stop; Invoke-Pester -Path tests\test-core-process-coverage.ps1
```
Note the per-test timings printed in the `[+]` lines for: `bg` "Resumes an existing job without throwing", `bg` "Resumes the most recent job when no id is given", `fg` "Brings a job to the foreground and removes it", `fg` "Brings the most recent job to the foreground when no id is given", `nohup` "Starts a background job and appends its output to nohup.out". (Expected baseline ≈ 0.5 s, 0.4 s, 2.1 s, 2.0 s, 2.1 s.) Record them for the Task 3 comparison.

- [ ] **Step 2: Remove the sleeps from the two `fg` jobs**

In the `fg` Describe, replace the job scriptblock in both `It` blocks (`:182` and `:190`):

```powershell
$job = Start-Job -ScriptBlock { Start-Sleep -Milliseconds 300; Write-Output 'fg-done' }
```

with:

```powershell
# No sleep needed: Start-Job's process boot (~1.7 s) keeps the job 'Running'
# when fg is called immediately after; the sleep only added pure wait time.
$job = Start-Job -ScriptBlock { Write-Output 'fg-done' }
```

- [ ] **Step 3: Shorten the `bg` job sleeps and share one job**

In the `bg` Describe, right after the opening line `Describe "bg" {`, add a shared-job setup/teardown:

```powershell
Describe "bg" {
    # One Start-Job serves both resume tests: bg never consumes the job (it only
    # calls non-blocking Receive-Job), so re-adding the same job per test is safe.
    # Short sleep so the job process exits quickly instead of lingering 30 s.
    BeforeAll { $script:sharedBgJob = Start-Job -ScriptBlock { Start-Sleep -Milliseconds 200 } }
    AfterAll  { Remove-Job $script:sharedBgJob -Force -ErrorAction SilentlyContinue }
```

Then replace the two `It` bodies that currently each create their own `Start-Job -ScriptBlock { Start-Sleep -Seconds 30 }` to use the shared job instead:

```powershell
    It "Resumes an existing job without throwing" {
        Set-JobTable @{ 'j1' = $script:sharedBgJob }
        # bg must not throw. Receive-Job without -Wait on a running job returns
        # the output available so far (none) and does not error.
        { & $script:bgFunc 1 } | Should Not Throw
        (& $script:module { $script:JobTable.Count }) | Should Be 1
    }

    It "Resumes the most recent job when no id is given" {
        Set-JobTable @{ 'j1' = $script:sharedBgJob }
        # -ArgList @() is required: invoking a Get-Command function reference with
        # no arguments on PowerShell 5.1 binds a phantom empty string into the
        # ValueFromRemainingArguments param, which would hit the "invalid job ID"
        # branch instead of the most-recent-job path.
        { & $script:bgFunc -ArgList @() } | Should Not Throw
        (& $script:module { $script:JobTable.Count }) | Should Be 1
    }
```

(Keep every other `bg` `It` unchanged. The `BeforeEach { Reset-JobTable }` already in the Describe stays.)

- [ ] **Step 4: Make the `nohup.out` poll content-based (fixes a race, speeds up)**

Baseline finding: under load this test flakes — `Test-Path $nohupOut` returns true the moment the `*>>` redirection creates the file, but the child's output is flushed slightly later, so an immediate `Get-Content` reads an empty file. Fix the race AND speed up by polling for the marker inside the file with a 100 ms interval.

At `test-core-process-coverage.ps1:329-335`, replace:

```powershell
            $deadline = (Get-Date).AddSeconds(15)
            while (-not (Test-Path $nohupOut) -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 250
            }
            Test-Path $nohupOut | Should Be $true
            (Get-Content $nohupOut -Raw) -match 'hello-nohup' | Should Be $true
```

with:

```powershell
            # Poll for the MARKER inside nohup.out, not just the file: the *>>
            # redirection creates the file before the child's output is flushed,
            # so Test-Path alone races an empty file (flaked under load).
            $deadline = (Get-Date).AddSeconds(15)
            $content = ''
            while ($content -notmatch 'hello-nohup' -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 100
                if (Test-Path $nohupOut) { $content = Get-Content $nohupOut -Raw }
            }
            $content | Should Match 'hello-nohup'
```

(Do NOT touch the `nohup` "Launches a command" `It` at `:304` — its `Start-Sleep -Seconds 30` arg keeps the job alive for the `JobTable.Count -gt 0` assertion; shortening it would be racy. Do NOT touch the `jobs` "Removes completed jobs" wait at `:93` — that is a ~1.7 s boot floor.)

- [ ] **Step 5: Run the file and verify all tests pass with lower timings**

Run:
```powershell
Import-Module Pester -ErrorAction Stop; Invoke-Pester -Path tests\test-core-process-coverage.ps1
```
Expected: all tests Passed, and the two `fg` tests dropped from ~2.1/2.0 s to ~1.7 s each; the two `bg` tests total ~0.5 s combined; the `nohup` append test is ~0.2 s faster. If a test now FAILS, do not ship it — investigate (the only expected state change is lower timings).

- [ ] **Step 6: Commit**

```bash
git add tests/test-core-process-coverage.ps1
git commit -m "perf(test): trim job-test sleeps and share one bg Start-Job"
```

---

### Task 2: Tune `test-core-process.ps1` and `test-e2e.ps1`

**Files:**
- Modify: `tests/test-core-process.ps1` — `bg` resume test (`:213`).
- Modify: `tests/test-e2e.ps1` — nohup smoke poll (`:94`).

**Interfaces:**
- Consumes: the existing `bg` test structure in `test-core-process.ps1`; the e2e nohup smoke's polling loop in `test-e2e.ps1`.
- Produces: hygiene-only change in `test-core-process.ps1` (no timing gain — `bg` doesn't wait); a ~0.2 s saving in `test-e2e.ps1`.

- [ ] **Step 1: Shorten the `bg` job sleep in `test-core-process.ps1`**

At `tests/test-core-process.ps1:214`, replace:

```powershell
        $job = Start-Job -ScriptBlock { Start-Sleep -Seconds 30 }
```

with:

```powershell
        $job = Start-Job -ScriptBlock { Start-Sleep -Milliseconds 200 }
```

Add a one-line comment above it: `# Short sleep: bg never waits on the job; the process exits fast instead of lingering 30 s.`

- [ ] **Step 2: Make the e2e nohup smoke poll content-based**

Same race as Task 1 Step 4 (file created before output flush), same fix. At `tests/test-e2e.ps1:93-98`, replace:

```powershell
            $deadline = (Get-Date).AddSeconds(15)
            while (-not (Test-Path $nohupOut) -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 250
            }
            Test-Path $nohupOut | Should Be $true
            (Get-Content $nohupOut -Raw) -match 'e2e-nohup-marker' | Should Be $true
```

with:

```powershell
            # Poll for the MARKER inside nohup.out, not just the file: the *>>
            # redirection creates the file before the child's output is flushed,
            # so Test-Path alone races an empty file (flaked under load).
            $deadline = (Get-Date).AddSeconds(15)
            $content = ''
            while ($content -notmatch 'e2e-nohup-marker' -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 100
                if (Test-Path $nohupOut) { $content = Get-Content $nohupOut -Raw }
            }
            $content | Should Match 'e2e-nohup-marker'
```

- [ ] **Step 3: Run both files and verify they pass**

Run:
```powershell
Import-Module Pester -ErrorAction Stop; Invoke-Pester -Path tests\test-core-process.ps1, tests\test-e2e.ps1
```
Expected: all tests Passed; `test-core-process.ps1` timing unchanged (hygiene only); the e2e nohup smoke drops from ~2.4 s to ~2.2 s.

- [ ] **Step 4: Commit**

```bash
git add tests/test-core-process.ps1 tests/test-e2e.ps1
git commit -m "perf(test): shorten bg job sleep (hygiene) and e2e nohup poll"
```

---

### Task 3: Full-suite verification and honest before/after delta

**Files:**
- Verify only: `tests/run-tests.ps1` (no edit).

**Interfaces:**
- Consumes: Task 1 + Task 2 edits; the Task 1 baseline timings recorded in Task 1 Step 1.

- [ ] **Step 1: Run the full suite and record total time**

Run:
```powershell
.\tests\run-tests.ps1
```
Expected: all tests Passed, 0 Failed, 18 Skipped, coverage ≈ 93.9% (unchanged — no product code touched). Note the reported `TotalCount` (should be 709) and the total `Time` (expected ≈ 50 s vs the ~52 s baseline).

- [ ] **Step 2: Report the real delta**

Compare the Task 1 baseline job-test timings against the Task 3 full-suite run. State plainly: expected saving ≈ 1.5–2 s; the `jobs`-cleanup and both `fg` tests and the `nohup`-append waits retain their ~1.7 s `Start-Job` boot floor, so the CLI's blue progress bar will still briefly park on those ~5 tests — that is the documented PS 5.1 `Start-Job` floor, not a regression.

- [ ] **Step 3: Commit (only if any doc/comment touch was needed)**

If Step 1 revealed an actual test failure or a timing regression, fix it first and re-run. If everything is green and only timings changed, there is nothing new to commit beyond Task 1–2; skip this step.

---

## Self-Review

**Spec coverage:** Shorter `Start-Sleep` → fg sleeps removed (Task 1), bg 30 s→200 ms (Task 1 + Task 2), poll 250→100 ms (Task 1 + Task 2). Share one `Start-Job` → bg `BeforeAll` shared job (Task 1). Every assertion checked for race safety: the one racy sleep (`nohup`-launch 30 s) is explicitly kept and documented; `jobs`-cleanup wait is a documented floor. Verification → Task 3 with real before/after delta.

**Placeholder scan:** No TBD/TODO; every edit has exact `old`/`new` content, exact run commands, and expected timing deltas. The `nohup`-launch and `jobs`-cleanup exclusions are stated with their line numbers so an implementer does not "improve" them into a race.

**Type/signature consistency:** `$script:sharedBgJob` is created in `BeforeAll`, referenced in both `bg` `It` blocks, and removed in `AfterAll` — same object name throughout. `Reset-JobTable`/`Set-JobTable`/`$script:module` already exist in the file (`:34-41`). No new functions introduced.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-13-test-suite-speedup.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
