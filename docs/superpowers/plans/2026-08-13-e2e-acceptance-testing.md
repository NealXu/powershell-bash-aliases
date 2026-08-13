# End-to-End Acceptance Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an automated end-to-end acceptance test (`tests/test-e2e.ps1`) that verifies the real user journey — `install.ps1` deploys the complete module layout, the *installed* module imports via its manifest with bash functions winning over built-in aliases, and representative commands (`ls`, `cat`, `nohup`) work against the installed copy.

**Architecture:** A single new Pester test file that (1) runs the real `install.ps1 -InstallPaths` into a temp dir, (2) imports that *installed* manifest with `Import-Module`, (3) asserts file layout, alias override, and three command smokes — all side effects confined to `$env:TEMP` and cleaned up. It is auto-discovered by the existing `tests/run-tests.ps1`; no runner changes needed.

**Tech Stack:** Pester 3.4.0, Windows PowerShell 5.1, existing `install.ps1` / `bash-aliases.psd1` / `alias-cleanup.ps1` (all unchanged unless a real defect surfaces).

## Global Constraints

- Windows PowerShell 5.1 + Pester 3.4.0 only — no Pester 5 / no new-style `-Should` syntax beyond what the codebase already uses.
- Test file MUST be ASCII-only (no non-ASCII literals) — the project rule stated in every test header.
- All e2e artifacts (temp install dir, smoke-test dirs/files) MUST live under `$env:TEMP` and be removed in teardown — never write into the repo root (regression from `09dbc43`).
- Follow the established test idiom: import the module at file top, grab function refs via `Get-Command X -CommandType Function`, call with `& $ref` to bypass alias precedence.
- The e2e MUST import the **installed copy via its manifest** (`<install>\bash-aliases.psd1`), not the repo `bash-aliases.psm1` — that is the whole point.
- `tests/run-tests.ps1` needs NO change: it collects every `test-*.ps1` except itself, so `test-e2e.ps1` joins the suite automatically.
- Coverage caveat: the `-CodeCoverage` pass measures repo `core-*.ps1` files, but the e2e runs code from the *installed* temp copy, so e2e executions are not attributed. This is consistent with the suite's existing documented "percentage is a lower bound" caveat (`tests/run-tests.ps1:81-87`).
- These are characterization/acceptance tests for *existing correct* behavior: the first run is EXPECTED to PASS. If any assertion fails, it exposes a genuine install/import/command defect — fix the product file (`install.ps1`, `bash-aliases.psd1`, `alias-cleanup.ps1`, or a `core-*.ps1`), never weaken the test.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `tests/test-e2e.ps1` | Create | The only new file. Top-level setup (install to temp + import installed manifest), three `Describe` blocks (layout / manifest import / command smoke), end-of-file teardown. |
| `README.md` | Modify | "运行测试" section: document how to run e2e alone and note it never touches real install/Profile. |
| `tests/run-tests.ps1` | (verify only) | No edit — confirm `test-e2e.ps1` is collected and the full suite stays green. |

---

### Task 1: Create `tests/test-e2e.ps1` — install layout + manifest import

**Files:**
- Create: `tests/test-e2e.ps1`

**Interfaces:**
- Consumes: `install.ps1` params (`-InstallPaths [string[]]`); installed `bash-aliases.psd1` (`RootModule = 'bash-aliases.psm1'`, `ScriptsToProcess = .\alias-cleanup.ps1`); the file list in `install.ps1:$files`.
- Produces: `$script:e2eInstall` (temp install dir), `$script:lsFunc` / `$script:catFunc` / `$script:nohupFunc` (installed function refs), `$script:expectedFiles` (layout manifest) — used by Task 2.

- [ ] **Step 1: Write `tests/test-e2e.ps1`** with the setup, the layout Describe, and the manifest-import Describe:

```powershell
# tests\test-e2e.ps1
# End-to-end acceptance: the REAL user journey against the INSTALLED module.
#   1. install.ps1 deploys the complete module layout to a temp install dir
#   2. importing the INSTALLED copy via its MANIFEST yields bash functions that
#      win over built-in aliases (ScriptsToProcess runs in the caller's scope)
#   3. representative commands (ls, cat, nohup) work against the installed copy
# Pester 3.4.0, Windows PowerShell 5.1. ASCII-only.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:e2eInstall = Join-Path $env:TEMP ('e2e-install-' + [guid]::NewGuid().ToString('N'))

# --- Setup: deploy a fresh install to a temp dir, then import it via manifest ---
$null = & (Join-Path $scriptDir '..\install.ps1') -InstallPaths $script:e2eInstall

Import-Module (Join-Path $script:e2eInstall 'bash-aliases.psd1') -Force

$script:lsFunc = Get-Command ls -CommandType Function -ErrorAction SilentlyContinue
$script:catFunc = Get-Command cat -CommandType Function -ErrorAction SilentlyContinue
$script:nohupFunc = Get-Command nohup -CommandType Function -ErrorAction SilentlyContinue

# File layout the install script MUST deploy (mirrors install.ps1's $files).
$script:expectedFiles = @(
    'bash-aliases.psm1', 'args-parser.ps1', 'utils.ps1', 'core-file.ps1',
    'core-text.ps1', 'core-search.ps1', 'core-process.ps1', 'core-network.ps1',
    'core-view.ps1', 'core-system.ps1', 'core-utils.ps1', 'core-compress.ps1',
    'core-edit.ps1', 'bash-aliases.psd1', 'alias-cleanup.ps1', 'profile-setup.ps1'
)

Describe "e2e: install deployment layout" {
    It "deploys every module file to the install dir" {
        foreach ($f in $script:expectedFiles) {
            Test-Path (Join-Path $script:e2eInstall $f) | Should Be $true
        }
    }

    It "installed manifest is valid and resolves its RootModule" {
        $m = Test-ModuleManifest -Path (Join-Path $script:e2eInstall 'bash-aliases.psd1')
        $m.RootModule | Should Be 'bash-aliases.psm1'
    }
}

Describe "e2e: installed module import via manifest" {
    It "ls resolves to the installed module function, not the built-in alias" {
        $script:lsFunc | Should Not Be $null
        $script:lsFunc.CommandType | Should Be Function
    }

    It "cd, cat, rm, cp, mv also resolve to module functions" {
        foreach ($name in @('cd', 'cat', 'rm', 'cp', 'mv')) {
            (Get-Command $name -CommandType Function -ErrorAction SilentlyContinue).Name | Should Be $name
        }
    }
}

# --- Teardown: remove the temp install (runs after all Describes above) ---
Remove-Item $script:e2eInstall -Recurse -Force -ErrorAction SilentlyContinue
```

- [ ] **Step 2: Run the e2e file and verify it passes**

Run from the repo root in Windows PowerShell 5.1:
```powershell
Import-Module Pester -ErrorAction Stop; Invoke-Pester -Path tests\test-e2e.ps1
```
Expected: 4 tests, all Passed. (If any fail, it is a real install/import defect — fix the product file, not the test.)

- [ ] **Step 3: Commit**

```bash
git add tests/test-e2e.ps1
git commit -m "feat(e2e): e2e install layout + manifest import acceptance tests"
```

---

### Task 2: Add the installed-command smoke Describe (ls / cat / nohup)

**Files:**
- Modify: `tests/test-e2e.ps1` — insert the new `Describe` between the manifest-import Describe and the teardown line.

**Interfaces:**
- Consumes: `$script:lsFunc`, `$script:catFunc`, `$script:nohupFunc` (installed function refs from Task 1); `$script:e2eInstall` teardown still runs last.
- Produces: three end-to-end smoke cases proving the installed module produces real output — the final acceptance gate.

- [ ] **Step 1: Add the smoke Describe**

Insert immediately above the teardown line (`Remove-Item $script:e2eInstall ...`):

```powershell
Describe "e2e: installed command smoke" {
    It "ls lists a temp directory's files" {
        $dir = Join-Path $env:TEMP ('e2e-ls-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $dir 'alpha.txt') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $dir 'sub') -Force | Out-Null
        try {
            Push-Location $dir
            $out = @(& $script:lsFunc)
            $out | Should Not BeNullOrEmpty
            ($out -join ' ') | Should Match 'alpha.txt'
            ($out -join ' ') | Should Match 'sub'
        } finally {
            Pop-Location
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It "cat prints file content" {
        $file = Join-Path $env:TEMP ('e2e-cat-' + [guid]::NewGuid().ToString('N') + '.txt')
        Set-Content -Path $file -Value @('line one', 'line two') -Encoding ASCII
        try {
            $out = @(& $script:catFunc $file)
            ($out -join ' ') | Should Match 'line one'
            ($out -join ' ') | Should Match 'line two'
        } finally {
            Remove-Item $file -Force -ErrorAction SilentlyContinue
        }
    }

    It "nohup starts a background job and writes nohup.out" {
        $dir = Join-Path $env:TEMP ('e2e-nohup-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Push-Location $dir
        try {
            $nohupOut = Join-Path $dir 'nohup.out'
            $r = @(& $script:nohupFunc Write-Output 'e2e-nohup-marker' 2>&1)
            ($r -join "`n") -match 'Started background job' | Should Be $true
            $deadline = (Get-Date).AddSeconds(15)
            while (-not (Test-Path $nohupOut) -and (Get-Date) -lt $deadline) {
                Start-Sleep -Milliseconds 250
            }
            Test-Path $nohupOut | Should Be $true
            (Get-Content $nohupOut -Raw) -match 'e2e-nohup-marker' | Should Be $true
        } finally {
            Pop-Location
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
            Get-EventSubscriber -ErrorAction SilentlyContinue | Unregister-Event -Force -ErrorAction SilentlyContinue
            Get-Job | Stop-Job -ErrorAction SilentlyContinue
            Get-Job | Remove-Job -Force -ErrorAction SilentlyContinue
        }
    }
}
```

- [ ] **Step 2: Run the e2e file and verify all 7 tests pass**

```powershell
Import-Module Pester -ErrorAction Stop; Invoke-Pester -Path tests\test-e2e.ps1
```
Expected: 7 tests, all Passed. The nohup case polls up to 15 s for `nohup.out` — allow the run to finish.

- [ ] **Step 3: Commit**

```bash
git add tests/test-e2e.ps1
git commit -m "feat(e2e): installed command smokes for ls/cat/nohup"
```

---

### Task 3: Full-suite verification + README documentation

**Files:**
- Modify: `README.md` — in the "### 运行测试" block (lines ~253-264).
- Verify only: `tests/run-tests.ps1` (no edit needed).

**Interfaces:**
- Consumes: Task 1 + Task 2 output (`tests/test-e2e.ps1`, 7 tests); existing `tests/run-tests.ps1` auto-discovery.

- [ ] **Step 1: Add the e2e run command and caveat to README**

After the line `Invoke-Pester tests\test-core-file.ps1` in the "### 运行测试" section, add:

```markdown
# 运行端到端验收测试（安装布局 -> manifest 导入 -> 命令冒烟）
Invoke-Pester tests\test-e2e.ps1

# run-tests.ps1 会自动收集 test-e2e.ps1。e2e 只操作 $env:TEMP 下的临时目录，
# 不会触碰真实安装目录或 Profile。
```

- [ ] **Step 2: Run the full suite and confirm green**

```powershell
.\tests\run-tests.ps1
```
Expected: every existing test passes AND the test count now includes the 7 new e2e tests; coverage % still reports (unchanged by e2e, per the lower-bound caveat). If the full suite fails anywhere unrelated to e2e, stop and fix that separately — do not mask it.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: document e2e acceptance test in run-tests section"
```

---

## Self-Review

**Spec coverage (agreed e2e scope: 安装布局 → manifest 导入 → 3 个代表性命令冒烟):**
- Install layout → Task 1 "e2e: install deployment layout" (all 16 files + manifest validity).
- Manifest import / alias override → Task 1 "e2e: installed module import via manifest" (imports the *installed* `.psd1`, asserts `ls/cd/cat/rm/cp/mv` resolve to Function via `ScriptsToProcess`).
- Command smokes → Task 2 (`ls`, `cat`, `nohup` — each runs the installed copy, not repo psm1).
- Auto-join the suite → Task 3 verifies via full `run-tests.ps1` (no runner edit).
- README docs → Task 3.

**Placeholder scan:** no TBD/TODO; every step has full file content, exact run command, and expected result. The `-AddToProfile` chain is intentionally NOT in e2e scope — profile-preamble correctness is already unit-covered by `tests/test-install-profile.ps1`, and redirecting `$PROFILE` for a child script is not possible (read-only automatic variable); adding a `-ProfilePath` param to `install.ps1` is a deliberate non-goal (YAGNI). Noted as a future extension.

**Type/signature consistency:** `cat` takes positional args via `[Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList` (verified `core-file.ps1:97-101`), so `& $script:catFunc $file` binds correctly. `nohup` smoke mirrors the proven poll pattern in `tests/test-core-process-coverage.ps1:320-344`. `ls` bare-call matches `tests/test-ls-bare.ps1`. `Test-ModuleManifest` returns a `PSModuleInfo` whose `RootModule` is `'bash-aliases.psm1'` (verified `bash-aliases.psd1:10`). All `$script:` names defined in Task 1 are consumed identically in Task 2.

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-13-e2e-acceptance-testing.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
