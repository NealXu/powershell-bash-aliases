# ls/ll Time & Reverse Sort Options (`-t` `-r` `-rt`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `ls` and `ll` honor GNU `-t` (sort by modification time, newest first), `-r` (reverse order), and their combination `-rt` (oldest first). Today the flags are silently dropped by `Parse-BashArgs` because neither `ls`'s nor `ll`'s OptionSpec declares them, and both functions hard-code `Sort-Object { $_.Name }`.

**Architecture:** Declare `-t`/`--time` and `-r`/`--reverse` as switch options in the `$spec` of `ls` and `ll` inside `core-file.ps1`. After parsing, choose the sort key (`LastWriteTime` when `-t`, else `Name`) and the direction (GNU semantics: time sorts **descending** by default so `-t` is newest-first; `-r` flips the direction; name sorts ascending by default). Replace the two hard-coded `Sort-Object { $_.Name }` calls with `Sort-Object $sortProp -Descending:$descending`. Update both `Usage` strings.

**Tech Stack:** Windows PowerShell 5.1, Pester 3.4.0, `core-file.ps1`, `tests/test-core-file.ps1`, `tests/test-ll.ps1`.

## Global Constraints

- Windows PowerShell 5.1 only; Pester 3.4.0; ASCII-safe test/plan text.
- **Do NOT modify** `args-parser.ps1`, `bash-aliases.psm1`, or any function other than `ls` and `ll` inside `core-file.ps1`. Tests only touch `tests/test-core-file.ps1` and `tests/test-ll.ps1`.
- **GNU `ls` sort semantics** (this is the contract the tests assert):
  - `-t` alone → sort by `LastWriteTime`, **descending** (newest first).
  - `-rt` (or `-t -r`) → sort by `LastWriteTime`, **ascending** (oldest first).
  - `-r` alone → reverse name order (descending names).
  - Default (no flags) → name ascending (unchanged).
- The hidden-file filter behavior is unchanged: `-a`/`--all` still reveals dotfiles; the sort applies to the full `Get-ChildItem` result before the dotfile filter, exactly as today.
- The combined short form `-rt` must work (Parse-BashArgs already iterates flag chars); `-t -r` as separate args must give the same result as `-rt`.
- Long forms `--time` and `--reverse` must work and be equivalent to `-t`/`-r`.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `tests/test-core-file.ps1` | Modify (Task 1) | Add `Describe "ls -t / -r / -rt sort options"` block with explicit-time fixtures and order assertions. |
| `tests/test-ll.ps1` | Modify (Task 1) | Add `Describe "ll -t / -r / -rt sort options"` block. |
| `core-file.ps1` | Modify (Task 2) | Add `-t`/`--time` + `-r`/`--reverse` to both `$spec`s; compute `$sortByTime`/`$reverse`; GNU direction; replace both `Sort-Object { $_.Name }`; update both `Usage` strings. |

---

### Task 1: Write failing tests for `ls`/`ll` time & reverse sorting (RED)

**Files:**
- Modify: `tests/test-core-file.ps1` (append a new `Describe` block — do not disturb existing tests), `tests/test-ll.ps1`.

**Interfaces:**
- Consumes: existing `$script:lsFunc` and `$script:llFunc` function references (already defined at the top of both test files), real files in a temp dir with explicitly-set `LastWriteTime`.
- Produces: new Pester `It` blocks that assert GNU ordering by extracting the trailing filename token from each long-format output line (skip the first `total N` header line).

**Test-data fixture (exact values, used verbatim in both files):**

Create a temp dir with three plain (non-hidden) `.txt` files whose names and write times are:
- `a.txt` → `LastWriteTime = Get-Date '2020-01-01'` (oldest)
- `c.txt` → `LastWriteTime = Get-Date '2021-01-01'`
- `b.txt` → `LastWriteTime = Get-Date '2023-01-01'` (newest)

Expected orders (by extracted names, joined with `,`):
- default (`-l`) → `a.txt,b.txt,c.txt` (name asc)
- `-l -t` → `b.txt,c.txt,a.txt` (time desc / newest first)
- `-l -rt` → `a.txt,c.txt,b.txt` (time asc / oldest first)
- `-l -r` → `c.txt,b.txt,a.txt` (name desc)
- `-l --time --reverse` → `a.txt,c.txt,b.txt` (long forms equal `-rt`)
- `-l -a -t` after adding hidden `.d.txt` with `LastWriteTime = Get-Date '2024-01-01'` → `.d.txt,b.txt,c.txt,a.txt` (hidden included, newest first)

Name-extraction helper used by every assertion:
```powershell
$names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
```
(plain `.txt` files get no ANSI color, so the last whitespace-delimited token is the filename).

`ll` assertions (same fixture; `ll` is already long-format and prints a `total N` header):
- `ll -t <dir>` → `b.txt,c.txt,a.txt`
- `ll -rt <dir>` → `a.txt,c.txt,b.txt`
- `ll -r <dir>` → `c.txt,b.txt,a.txt`

- [ ] **Step 1: Append the `ls` sort Describe block to `tests/test-core-file.ps1`**

Use `& $script:lsFunc` to call the function (bypasses PowerShell alias precedence). Exact block to append:

```powershell
Describe "ls -t / -r / -rt sort options" {
    BeforeAll {
        $sortDir = "test-ls-sort-temp"
        New-Item -ItemType Directory -Path $sortDir -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\a.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\b.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\c.txt" -Force | Out-Null
        (Get-Item "$sortDir\a.txt").LastWriteTime = Get-Date '2020-01-01'
        (Get-Item "$sortDir\c.txt").LastWriteTime = Get-Date '2021-01-01'
        (Get-Item "$sortDir\b.txt").LastWriteTime = Get-Date '2023-01-01'
    }
    AfterAll {
        Remove-Item $sortDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "defaults to name ascending" {
        $out = @(& $script:lsFunc -l $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,b.txt,c.txt'
    }
    It "-t sorts by time, newest first" {
        $out = @(& $script:lsFunc -l -t $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'b.txt,c.txt,a.txt'
    }
    It "-rt sorts by time reverse, oldest first" {
        $out = @(& $script:lsFunc -l -rt $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,c.txt,b.txt'
    }
    It "-r reverses name order" {
        $out = @(& $script:lsFunc -l -r $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'c.txt,b.txt,a.txt'
    }
    It "long forms --time --reverse equal -rt" {
        $out = @(& $script:lsFunc -l --time --reverse $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,c.txt,b.txt'
    }
    It "-a -t includes hidden files and sorts newest first" {
        New-Item -ItemType File -Path "$sortDir\.d.txt" -Force | Out-Null
        (Get-Item "$sortDir\.d.txt").LastWriteTime = Get-Date '2024-01-01'
        $out = @(& $script:lsFunc -l -a -t $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be '.d.txt,b.txt,c.txt,a.txt'
    }
}
```

- [ ] **Step 2: Append the `ll` sort Describe block to `tests/test-ll.ps1`**

```powershell
Describe "ll -t / -r / -rt sort options" {
    BeforeAll {
        $sortDir = "test-ll-sort-temp"
        New-Item -ItemType Directory -Path $sortDir -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\a.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\b.txt" -Force | Out-Null
        New-Item -ItemType File -Path "$sortDir\c.txt" -Force | Out-Null
        (Get-Item "$sortDir\a.txt").LastWriteTime = Get-Date '2020-01-01'
        (Get-Item "$sortDir\c.txt").LastWriteTime = Get-Date '2021-01-01'
        (Get-Item "$sortDir\b.txt").LastWriteTime = Get-Date '2023-01-01'
    }
    AfterAll {
        Remove-Item $sortDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    It "-t sorts by time, newest first" {
        $out = @(& $script:llFunc -t $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'b.txt,c.txt,a.txt'
    }
    It "-rt sorts by time reverse, oldest first" {
        $out = @(& $script:llFunc -rt $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'a.txt,c.txt,b.txt'
    }
    It "-r reverses name order" {
        $out = @(& $script:llFunc -r $sortDir)
        $names = @($out | Select-Object -Skip 1 | ForEach-Object { ($_ -split '\s+')[-1] })
        $names -join ',' | Should Be 'c.txt,b.txt,a.txt'
    }
}
```

- [ ] **Step 3: Run the two test files and verify the new tests FAIL for the right reason**

Run from the repo root (this is RED — expected to fail):
```powershell
Invoke-Pester .\tests\test-core-file.ps1, .\tests\test-ll.ps1 -PassThru
```
Confirm:
- The default-name-order `It` in the `ls` block **passes** (existing behavior).
- Every new `-t` / `-rt` / `-r` / `--time` / `--reverse` `It` **fails**, and the failure output shows the assertion got the alphabetical order (`a.txt,b.txt,c.txt`) instead of the expected time/reverse order — i.e. it fails because the option is ignored, NOT because of a test typo or a fixture error.
- Record the failing test count and one representative failure line in the task report.

- [ ] **Step 4: Commit**

```bash
git add tests/test-core-file.ps1 tests/test-ll.ps1
git commit -m "test(ls,ll): add failing tests for -t/-r/-rt sort options"
```

---

### Task 2: Implement `-t` / `-r` in `core-file.ps1` `ls` and `ll` (GREEN)

**Files:**
- Modify: `core-file.ps1` — only the `ls` function (lines ~15-42) and the `ll` function (lines ~338-356). Do not touch any other function.

**Interfaces:**
- Consumes: Task 1's failing tests (they define the required behavior). `Parse-BashArgs` already returns `Options`/`LongOptions` for any spec key; no changes to `args-parser.ps1`.
- Produces: `-t`/`--time`/`-r`/`--reverse` recognized by both commands; GNU sort direction; updated `Usage` strings.

- [ ] **Step 1: Extend the `ls` OptionSpec and add sort variables**

In `ls`, change the `$spec` hashtable to add two entries (keep existing keys):
```powershell
    $spec = @{
        'a' = @{ Long = 'all'; Type = 'switch' }
        'l' = @{ Long = 'long'; Type = 'switch' }
        'h' = @{ Long = 'human-readable'; Type = 'switch' }
        't' = @{ Long = 'time'; Type = 'switch' }
        'r' = @{ Long = 'reverse'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }
```
Update the help-return string to `'Usage: ls [-a] [-l] [-h] [-t] [-r] [--help] [PATH]'`.

After the existing `$humanReadable` line, add:
```powershell
    $sortByTime = $parsed.Options['t'] -or $parsed.LongOptions['time']
    $reverse = $parsed.Options['r'] -or $parsed.LongOptions['reverse']
    $sortProp = if ($sortByTime) { 'LastWriteTime' } else { 'Name' }
    $descending = if ($sortByTime) { -not $reverse } else { $reverse }
```

- [ ] **Step 2: Replace the `ls` sort call**

Replace `Get-ChildItem $Path -Force:$showAll | Sort-Object { $_.Name }` with:
```powershell
        $items = Get-ChildItem $Path -Force:$showAll | Sort-Object $sortProp -Descending:$descending
```
(The `if (-not $showAll) { ... dotfile filter ... }` line stays exactly as is.)

- [ ] **Step 3: Extend the `ll` OptionSpec, sort variables, and sort call**

In `ll`, add the same two entries to its `$spec`, update its help string to `'Usage: ll [-a] [-h] [-t] [-r] [--help] [PATH] (equivalent to ls -la)'`, add the same four `$sortByTime/$reverse/$sortProp/$descending` lines after the `$humanReadable` line, and replace `Get-ChildItem $p -Force:$showAll | Sort-Object { $_.Name }` with `Get-ChildItem $p -Force:$showAll | Sort-Object $sortProp -Descending:$descending`. The dotfile filter line stays unchanged.

- [ ] **Step 4: Verify Task 1 tests now pass (GREEN)**

Run from the repo root:
```powershell
Invoke-Pester .\tests\test-core-file.ps1, .\tests\test-ll.ps1 -PassThru
```
Confirm: all previously-failing `It` blocks pass, including the default-name-order one. Record Passed/Failed counts and one representative output line.

- [ ] **Step 5: Run the full suite to check for regressions**

Run the detached full suite and confirm 0 failures:
```powershell
.\run-tests-detached.ps1 -Wait
```
Expected: `Failed: 0` in the summary (baseline before this change was also 0 — confirm against the recorded baseline). If any pre-existing test now fails, stop and report — do not modify unrelated code to make it pass.

- [ ] **Step 6: Commit**

```bash
git add core-file.ps1
git commit -m "feat(ls,ll): support -t/--time and -r/--reverse sort options"
```

---

## Self-Review

**Spec coverage (the ask: make `-r -t -rt` work):** OptionSpec entries → Task 2 Steps 1/3. GNU direction (`-t` newest-first, `-rt` oldest-first, `-r` name-desc) → the `$descending` formula + Task 1 assertions. Long forms `--time`/`--reverse` → the `$parsed.LongOptions` reads + Task 1's long-form test. Combined `-rt` and separate `-t -r` → both feed the same `$reverse`/`$sortByTime` flags (Parse-BashArgs iterates flag chars). Hidden-file interplay → `-a -t` test in Task 1.

**Placeholder scan:** No TBD/TODO; all test fixtures, expected orders, exact code edits, verification commands, and expected results are concrete.

**Type/signature consistency:** `$parsed.Options['t']` and `$parsed.LongOptions['time']` are booleans (switch type); `-or` always yields a `$bool`, so `$reverse`/`$descending` are proper `[bool]`s usable as `-Descending:$descending` (no `$null` coercion edge). `Sort-Object` property names are real member names of `FileInfo`/`DirectoryInfo` (`LastWriteTime`, `Name`). No new cross-task contracts beyond Task 1 → Task 2 (the tests define behavior; the implementation satisfies them).

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-14-ls-ll-time-reverse-sort.md`.** Execute via superpowers:subagent-driven-development: Task 1 (RED tests) then Task 2 (GREEN implementation), each with a task review, then a final whole-branch review, then finish the branch.
