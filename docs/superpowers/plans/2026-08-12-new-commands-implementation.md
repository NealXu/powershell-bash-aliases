# 新增命令功能实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 35 个新增 bash 命令，分 4 批次完成

**Architecture:** 扩展现有模块 + 新增 core-utils.ps1 和 core-compress.ps1，遵循现有 Parse-BashArgs 参数解析框架

**Tech Stack:** PowerShell 5.1+, Pester 测试框架

## Global Constraints

- 遵循现有参数解析框架（Parse-BashArgs）
- 所有命令支持 --help 参数
- 使用 Write-BashError 输出错误
- 每个命令至少 3 个测试用例
- 遵循现有代码风格和命名规范

---

## Phase 1: 基础设施

### Task 1: 创建 core-utils.ps1 模块框架

**Files:**
- Create: `core-utils.ps1`
- Modify: `bash-aliases.psm1:12` (添加导入)
- Modify: `bash-aliases.psm1:22` (添加导出)

**Interfaces:**
- Consumes: `Parse-BashArgs`, `Write-BashError`, `Convert-BashPath` from existing modules
- Produces: `echo`, `tee`, `history`, `time`, `watch`, `seq`, `yes`, `rev`, `shuf`, `xargs` functions

- [ ] **Step 1: 创建 core-utils.ps1 文件框架**

```powershell
# core-utils.ps1
# Utility commands module

function echo {
    param(
        [switch]$n,
        [switch]$e,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # Placeholder - will be implemented in Task 3
}

function tee {
    param(
        [switch]$a,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # Placeholder - will be implemented in Task 3
}

# ... other function placeholders
```

- [ ] **Step 2: 更新 bash-aliases.psm1 导入**

在 `. $PSScriptRoot\core-system.ps1` 之后添加：
```powershell
. $PSScriptRoot\core-utils.ps1
```

- [ ] **Step 3: 更新 bash-aliases.psm1 导出**

在 Export-ModuleMember 添加：
```powershell
Export-ModuleMember -Function ..., echo, tee, history, time, watch, seq, yes, rev, shuf, xargs
```

- [ ] **Step 4: 验证模块加载**

```powershell
Import-Module ./bash-aliases.psm1 -Force
Get-Command echo
```

- [ ] **Step 5: 提交**

```bash
git add core-utils.ps1 bash-aliases.psm1
git commit -m "feat: add core-utils.ps1 module framework"
```

---

### Task 2: 创建 core-compress.ps1 模块框架

**Files:**
- Create: `core-compress.ps1`
- Modify: `bash-aliases.psm1:13` (添加导入)
- Modify: `bash-aliases.psm1:23` (添加导出)

**Interfaces:**
- Consumes: `Parse-BashArgs`, `Write-BashError`, `Convert-BashPath`
- Produces: `tar`, `zip`, `unzip`, `gzip`, `gunzip`, `bzip2`, `bunzip2` functions

- [ ] **Step 1: 创建 core-compress.ps1 文件框架**

```powershell
# core-compress.ps1
# Compression commands module

function tar {
    param(
        [switch]$c, [switch]$x, [switch]$t,
        [switch]$v, [switch]$z, [switch]$j,
        [string]$f,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # Placeholder
}

function zip {
    param(
        [switch]$r,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # Placeholder
}

# ... other function placeholders
```

- [ ] **Step 2: 更新 bash-aliases.psm1 导入和导出**

```powershell
. $PSScriptRoot\core-compress.ps1

Export-ModuleMember -Function ..., tar, zip, unzip, gzip, gunzip, bzip2, bunzip2
```

- [ ] **Step 3: 更新 install.ps1 文件列表**

在 `$files` 数组添加：
```powershell
'core-utils.ps1',
'core-compress.ps1'
```

- [ ] **Step 4: 提交**

```bash
git add core-compress.ps1 bash-aliases.psm1 install.ps1
git commit -m "feat: add core-compress.ps1 module framework"
```

---

## Phase 2: Batch 1 实现 (高价值低难度)

### Task 3: 实现 echo 命令

**Files:**
- Modify: `core-utils.ps1:1-20`
- Create: `tests/test-core-utils.ps1`

**Interfaces:**
- Consumes: `Parse-BashArgs`
- Produces: `echo` function with `-n`, `-e` support

- [ ] **Step 1: 编写 echo 测试**

在 `tests/test-core-utils.ps1` 添加：
```powershell
# tests/test-core-utils.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

Describe "echo" {
    It "Outputs text" {
        $result = echo "Hello World"
        $result | Should Be "Hello World"
    }
    It "Outputs without newline with -n" {
        { echo -n "test" } | Should Not Throw
    }
    It "Parses escape sequences with -e" {
        $result = echo -e "Line1\nLine2"
        $result | Should Be "Line1
Line2"
    }
    It "Shows help" {
        $result = echo --help
        $result | Should Match "Usage"
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

```powershell
Invoke-Pester tests/test-core-utils.ps1 -TestName 'echo'
```

Expected: FAIL (function placeholder returns nothing)

- [ ] **Step 3: 实现 echo 命令**

```powershell
function echo {
    param(
        [switch]$n,
        [switch]$e,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $spec = @{
        'n' = @{ Long = 'no-newline'; Type = 'switch' }
        'e' = @{ Long = 'enable-escape'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }
    $parsed = Parse-BashArgs -ArgsArray $ArgList -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: echo [-n] [-e] [STRING]...'
    }

    $noNewline = $parsed.Options['n'] -or $parsed.LongOptions['no-newline']
    $enableEscape = $parsed.Options['e'] -or $parsed.LongOptions['enable-escape']

    $output = $parsed.Positional -join ' '

    if ($enableEscape) {
        $output = $output -replace '\\n', "`n" `
                          -replace '\\t', "`t" `
                          -replace '\\\\', '\'
    }

    if ($noNewline) {
        Write-Host $output -NoNewline
    } else {
        Write-Output $output
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

```powershell
Invoke-Pester tests/test-core-utils.ps1 -TestName 'echo'
```

Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add core-utils.ps1 tests/test-core-utils.ps1
git commit -m "feat: implement echo command with -n and -e support"
```

---

### Task 4-9: Batch 1 其他命令

（详细步骤同 Task 3，包含 tee, diff, free, date, whoami, env, basename, dirname）

---

## Phase 3-6: Batch 2-4 概要

遵循相同 TDD 流程实现剩余命令：

### Batch 2 (Task 10-16)
- sed, tar, zip/unzip, gzip/gunzip, pgrep/pkill, ln, file, stat, realpath

### Batch 3 (Task 17-22)
- awk, patch, jobs/bg/fg/nohup, bzip2/bunzip2, more

### Batch 4 (Task 23-26)
- history, time, watch, seq, yes, rev, shuf, xargs

---

## 验收清单

- [ ] 35 个命令全部实现
- [ ] 每个命令有至少 3 个测试用例
- [ ] 所有测试通过
- [ ] README 更新包含新命令
- [ ] install.ps1 包含新文件