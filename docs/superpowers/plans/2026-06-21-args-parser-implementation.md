# 参数兼容性改进实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建统一的参数解析框架，实现高度 bash 兼容性（支持 `-la` 组合、`--long-option` 长参数）

**Architecture:** 新建 `args-parser.ps1` 模块，包含 `Parse-BashArgs`、`Get-PipelineInput`、`Write-BashError` 三个核心函数，然后逐步重构现有命令使用新解析器

**Tech Stack:** PowerShell 5.1+, Pester 3.4.0 测试框架

---

## 文件结构

| 文件 | 职责 | 状态 |
|------|------|------|
| `args-parser.ps1` | 参数解析核心模块 | 新建 |
| `bash-aliases.psm1` | 主模块入口 | 修改（导入新模块） |
| `core-file.ps1` | ls, cat, rm, mkdir, cp, mv, touch, ll | 修改（重构参数解析） |
| `core-text.ps1` | head, tail, wc, sort, uniq, cut, tr | 修改 |
| `core-search.ps1` | grep, find, which | 修改 |
| `tests/test-args-parser.ps1` | 参数解析器测试 | 新建 |
| `install.ps1` | 安装脚本 | 修改（添加新文件） |

---

## Phase 1: 创建参数解析模块

### Task 1.1: 创建 Parse-BashArgs 函数骨架

**Files:**
- Create: `args-parser.ps1`
- Test: `tests/test-args-parser.ps1`

- [ ] **Step 1: 创建 args-parser.ps1 文件骨架**

```powershell
# args-parser.ps1
# Bash-style argument parser for PowerShell

function Parse-BashArgs {
    param(
        [string[]]$ArgsArray,
        [hashtable]$OptionSpec
    )
    
    $result = @{
        Options = @{}
        LongOptions = @{}
        Positional = @()
        Errors = @()
    }
    
    return $result
}
```

- [ ] **Step 2: 创建测试文件**

```powershell
# tests\test-args-parser.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\args-parser.ps1")

Describe "Parse-BashArgs" {
    It "Returns empty result for empty input" {
        $result = Parse-BashArgs -ArgsArray @() -OptionSpec @{}
        $result.Options.Count | Should Be 0
        $result.Positional.Count | Should Be 0
    }
}
```

- [ ] **Step 3: 运行测试验证骨架**

Run: `powershell -Command "Invoke-Pester tests\test-args-parser.ps1"`
Expected: PASS (1 test)

- [ ] **Step 4: 提交骨架**

```bash
git add args-parser.ps1 tests/test-args-parser.ps1
git commit -m "feat: add args-parser.ps1 skeleton"
```

---

### Task 1.2: 实现 switch 参数解析

**Files:**
- Modify: `args-parser.ps1`
- Test: `tests/test-args-parser.ps1`

- [ ] **Step 1: 添加 switch 参数解析测试**

```powershell
    It "Parses single short switch -a" {
        $spec = @{ 'a' = @{ Long = 'all'; Type = 'switch' } }
        $result = Parse-BashArgs -ArgsArray @('-a') -OptionSpec $spec
        $result.Options['a'] | Should Be $true
        $result.LongOptions['all'] | Should Be $true
    }

    It "Parses combined short switches -la" {
        $spec = @{
            'l' = @{ Long = 'long'; Type = 'switch' }
            'a' = @{ Long = 'all'; Type = 'switch' }
        }
        $result = Parse-BashArgs -ArgsArray @('-la') -OptionSpec $spec
        $result.Options['l'] | Should Be $true
        $result.Options['a'] | Should Be $true
    }
```

- [ ] **Step 2: 实现 switch 参数解析**

```powershell
function Parse-BashArgs {
    param(
        [string[]]$ArgsArray,
        [hashtable]$OptionSpec
    )
    
    $result = @{
        Options = @{}
        LongOptions = @{}
        Positional = @()
        Errors = @()
    }
    
    $i = 0
    while ($i -lt $ArgsArray.Count) {
        $arg = $ArgsArray[$i]
        
        if ($arg.StartsWith('--')) {
            $longName = $arg.Substring(2)
            foreach ($key in $OptionSpec.Keys) {
                if ($OptionSpec[$key].Long -eq $longName) {
                    $result.Options[$key] = $true
                    $result.LongOptions[$longName] = $true
                    break
                }
            }
            $i++
        }
        elseif ($arg.StartsWith('-') -and $arg.Length -gt 1) {
            $flags = $arg.Substring(1)
            for ($j = 0; $j -lt $flags.Length; $j++) {
                $flag = $flags[$j]
                if ($OptionSpec.ContainsKey($flag)) {
                    $result.Options[$flag] = $true
                    if ($OptionSpec[$flag].Long) {
                        $result.LongOptions[$OptionSpec[$flag].Long] = $true
                    }
                }
            }
            $i++
        }
        else {
            $result.Positional += $arg
            $i++
        }
    }
    
    return $result
}
```

- [ ] **Step 3: 运行测试确认通过**

Run: `powershell -Command "Invoke-Pester tests\test-args-parser.ps1"`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git add args-parser.ps1 tests/test-args-parser.ps1
git commit -m "feat: implement switch parsing (-a, -la, --all)"
```

---

### Task 1.3: 实现 value 参数解析

**Files:**
- Modify: `args-parser.ps1`
- Test: `tests/test-args-parser.ps1`

- [ ] **Step 1: 添加 value 参数测试**

```powershell
Describe "Parse-BashArgs value parameters" {
    It "Parses -n 10 value parameter" {
        $spec = @{ 'n' = @{ Long = 'lines'; Type = 'value' } }
        $result = Parse-BashArgs -ArgsArray @('-n', '5') -OptionSpec $spec
        $result.Options['n'] | Should Be '5'
    }

    It "Parses --lines=10 value parameter" {
        $spec = @{ 'n' = @{ Long = 'lines'; Type = 'value' } }
        $result = Parse-BashArgs -ArgsArray @('--lines=20') -OptionSpec $spec
        $result.Options['n'] | Should Be '20'
    }
}
```

- [ ] **Step 2: 扩展 Parse-BashArgs 支持 value**

更新解析函数以处理值参数（检测 Type='value' 并取下一个参数）

- [ ] **Step 3: 运行测试**

Run: `powershell -Command "Invoke-Pester tests\test-args-parser.ps1"`
Expected: PASS

- [ ] **Step 4: 提交**

```bash
git commit -m "feat: implement value parameter parsing (-n 5, --lines=10)"
```

---

### Task 1.4: 实现 Get-PipelineInput 和 Write-BashError

**Files:**
- Modify: `args-parser.ps1`
- Test: `tests/test-args-parser.ps1`

- [ ] **Step 1: 添加 Get-PipelineInput 函数**

```powershell
function Get-PipelineInput {
    param([object]$InputObject, [string[]]$PathParams)
    
    if ($InputObject -and ($InputObject | Measure).Count -gt 0) {
        return @{ Source = 'pipeline'; Data = @($InputObject) }
    }
    elseif ($PathParams.Count -gt 0) {
        return @{ Source = 'file'; Paths = $PathParams }
    }
    return @{ Source = 'none' }
}
```

- [ ] **Step 2: 添加 Write-BashError 函数**

```powershell
function Write-BashError {
    param([string]$Command, [string]$Message)
    Write-Error "$Command: $Message" -ErrorAction Continue
}
```

- [ ] **Step 3: 提交**

```bash
git commit -m "feat: add Get-PipelineInput and Write-BashError"
```

---

### Task 1.5: 更新 bash-aliases.psm1 导入

**Files:**
- Modify: `bash-aliases.psm1`

- [ ] **Step 1: 添加导入**

在第 4 行添加: `. $PSScriptRoot\args-parser.ps1`

- [ ] **Step 2: 提交**

```bash
git commit -m "feat: import args-parser in main module"
```

---

## Phase 2: 重构高频命令

### Task 2.1: 重构 ls 命令

**Files:**
- Modify: `core-file.ps1`
- Test: `tests/test-core-file.ps1`

- [ ] **Step 1: 重构 ls 使用 Parse-BashArgs**

定义 `$spec` 参数规格，调用 `Parse-BashArgs`，使用解析结果

- [ ] **Step 2: 添加新参数测试**

测试 `-la`, `--all`, `-t`, `-r`

- [ ] **Step 3: 提交**

```bash
git commit -m "refactor: ls uses Parse-BashArgs"
```

---

### Task 2.2: 重构 grep 命令

**Files:**
- Modify: `core-search.ps1`
- Test: `tests/test-core-search.ps1`

- [ ] **Step 1: 重构 grep 使用 Parse-BashArgs**

添加 `-c`, `-l`, `-E` 参数支持

- [ ] **Step 2: 提交**

```bash
git commit -m "refactor: grep uses Parse-BashArgs, adds -c, -l"
```

---

## Phase 3: 重构中频命令

### Task 3.1: 重构 head/tail

- [ ] 重构使用 Parse-BashArgs

### Task 3.2: 重构 wc/sort/uniq

- [ ] 重构使用 Parse-BashArgs

---

## Phase 4: 重构其余命令

### Task 4.1: 重构 ps/kill

- [ ] 重构使用 Parse-BashArgs

### Task 4.2: 重构 curl/wget/ping

- [ ] 重构使用 Parse-BashArgs

---

## Phase 5: 更新安装和测试

### Task 5.1: 更新 install.ps1

- [ ] 添加 `args-parser.ps1` 到 `$files` 数组

### Task 5.2: 运行完整测试

- [ ] 运行 `Invoke-Pester tests\`
- [ ] 运行 `tests\run-tests.ps1`

---

## 验收检查清单

- [ ] `-la` 组合参数正常工作
- [ ] `--all` 长参数正常工作
- [ ] `-n 10` 值参数正常工作
- [ ] 错误消息符合 bash 格式
- [ ] 所有测试通过