# 参数兼容性优先改进方案设计文档

**日期**: 2026-06-21
**项目**: powershell-bash-aliases
**目标**: 建立统一的参数解析框架，实现高度 bash 兼容性

---

## 1. 背景

### 当前问题

现有参数处理存在以下问题：

1. **不支持参数组合**: `-la` 必须分开写成 `-l -a`
2. **不支持长参数**: `--all`, `--human-readable` 等 GNU 风格参数无法使用
3. **参数值处理不一致**: `-n 10` vs `--lines=10` 格式各异
4. **管道输入不统一**: 各函数自行处理 `$input`，逻辑分散
5. **错误消息格式各异**: 与 bash 错误格式不一致

### 设计目标

- 支持 POSIX 短参数 (`-a`, `-la` 组合)
- 支持 GNU 长参数 (`--all`, `--human-readable`)
- 支持参数值 (`-n 10`, `--lines=10`)
- 统一管道输入处理
- 统一错误消息格式 (模仿 bash)

---

## 2. 架构设计

### 新增模块

**文件**: `args-parser.ps1`

```
项目结构:
├── bash-aliases.psm1      # 主模块（更新导入 args-parser.ps1）
├── utils.ps1              # 工具函数（保持不变）
├── args-parser.ps1        # ★ 新增：参数解析器模块
├── core-file.ps1          # 文件命令（重构参数解析）
├── core-text.ps1          # 文本命令（重构）
├── core-search.ps1        # 搜索命令（重构）
├── core-process.ps1       # 进程命令（重构）
├── core-network.ps1       # 网络命令（重构）
├── core-view.ps1          # 视图命令（重构）
├── core-system.ps1        # 系统命令（重构）
└── install.ps1            # 安装脚本（更新文件列表）
```

### 模块依赖关系

```
bash-aliases.psm1
    └── args-parser.ps1  (新增)
    └── utils.ps1
    └── core-file.ps1
    └── core-text.ps1
    └── ...
```

---

## 3. 参数解析器设计

### 3.1 核心 API

```powershell
# Parse-BashArgs - 主要解析函数
function Parse-BashArgs {
    param(
        [string[]]$ArgsArray,     # 用户传入的参数数组
        [hashtable]$OptionSpec    # 参数规格定义
    )

    # 返回解析结果
    return @{
        Options = @{}      # 解析后的选项键值对 (短参数名 -> 值)
        LongOptions = @{}  # 长参数映射 (长参数名 -> 值)
        Positional = @()   # 位置参数列表
        Errors = @()       # 解析错误列表
    }
}
```

### 3.2 参数规格定义格式

```powershell
# 示例：ls 命令的参数规格
$lsOptionSpec = @{
    'a' = @{
        Long = 'all'
        Type = 'switch'           # switch: 无值的布尔参数
        Description = '显示隐藏文件'
    }
    'l' = @{
        Long = 'long'
        Type = 'switch'
        Description = '使用长格式'
    }
    'h' = @{
        Long = 'human-readable'
        Type = 'switch'
        Description = '人类可读的大小'
    }
    'n' = @{
        Long = 'lines'
        Type = 'value'            # value: 需要值的参数
        DefaultValue = 10
        Description = '显示 N 行'
    }
    'help' = @{
        Long = 'help'
        Type = 'switch'
        Description = '显示帮助'
    }
}
```

### 3.3 解析逻辑

```
输入: ['-la', '--human-readable', '-n', '5', 'file.txt']

解析过程:
1. '-la' -> 拆分为 '-l', '-a' -> 两个 switch 参数
2. '--human-readable' -> 长参数，映射到 'h'
3. '-n', '5' -> 参数值，n = 5
4. 'file.txt' -> 位置参数

输出:
{
    Options: { 'l': true, 'a': true, 'h': true, 'n': 5 },
    LongOptions: { 'long': true, 'all': true, 'human-readable': true, 'lines': 5 },
    Positional: ['file.txt'],
    Errors: []
}
```

---

## 4. 管道输入处理器

### 4.1 Get-PipelineInput 函数

```powershell
function Get-PipelineInput {
    param(
        [object]$InputObject,     # $input 自动变量
        [string[]]$PathParams     # 位置参数（路径）
    )

    # 判断输入来源优先级
    if ($InputObject -and ($InputObject | Measure).Count -gt 0) {
        # 有管道输入
        return @{
            Source = 'pipeline'
            Data = @($InputObject)
        }
    }
    elseif ($PathParams.Count -gt 0) {
        # 有文件路径参数
        return @{
            Source = 'file'
            Paths = $PathParams
        }
    }
    else {
        # 无输入
        return @{
            Source = 'none'
        }
    }
}
```

### 4.2 使用示例

```powershell
function grep {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'i' = @{ Long = 'ignore-case'; Type = 'switch' }
        'v' = @{ Long = 'invert-match'; Type = 'switch' }
        'n' = @{ Long = 'line-number'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    # 获取输入来源
    $inputInfo = Get-PipelineInput -InputObject $input -PathParams $parsed.Positional

    switch ($inputInfo.Source) {
        'pipeline' {
            # 从管道处理
            $content = $inputInfo.Data
        }
        'file' {
            # 从文件读取
            $content = Get-Content $inputInfo.Paths[0]
        }
        'none' {
            Write-BashError -Command 'grep' -Message 'missing pattern or file'
            return
        }
    }

    # ... 处理逻辑
}
```

---

## 5. 错误格式化器

### 5.1 Write-BashError 函数

```powershell
function Write-BashError {
    param(
        [string]$Command,         # 命令名
        [string]$Message,         # 错误消息
        [string]$ErrorCode = ''   # 可选错误码
    )

    # 模仿 bash 格式: command: error: message
    # 或: command: cannot access 'file': No such file or directory
    $errorLine = "$Command: $Message"

    Write-Error $errorLine -ErrorAction Continue
}
```

### 5.2 错误消息示例

```
bash 错误格式:
$ ls nonexistent
ls: cannot access 'nonexistent': No such file or directory

$ rm -x file
rm: invalid option -- 'x'

$ grep pattern nonexistent
grep: nonexistent: No such file or directory
```

---

## 6. 命令重构示例

### 6.1 ls 命令重构

```powershell
function ls {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    # 定义参数规格
    $spec = @{
        'a' = @{ Long = 'all'; Type = 'switch'; Description = '显示隐藏文件' }
        'l' = @{ Long = 'long'; Type = 'switch'; Description = '长格式' }
        'h' = @{ Long = 'human-readable'; Type = 'switch'; Description = '人类可读大小' }
        't' = @{ Long = 'time'; Type = 'switch'; Description = '按时间排序' }
        'r' = @{ Long = 'reverse'; Type = 'switch'; Description = '逆序' }
        'R' = @{ Long = 'recursive'; Type = 'switch'; Description = '递归' }
        'd' = @{ Long = 'directory'; Type = 'switch'; Description = '只显示目录' }
        'help' = @{ Long = 'help'; Type = 'switch'; Description = '显示帮助' }
    }

    # 解析参数
    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    # 处理错误
    if ($parsed.Errors.Count -gt 0) {
        foreach ($err in $parsed.Errors) {
            Write-BashError -Command 'ls' -Message $err
        }
        return
    }

    # 处理帮助
    if ($parsed.Options['help']) {
        return 'Usage: ls [-a] [-l] [-h] [-t] [-r] [-R] [-d] [--help] [FILE]...'
    }

    # 获取选项值 (同时支持短参数和长参数)
    $showAll = $parsed.Options['a'] -or $parsed.LongOptions['all']
    $longFormat = $parsed.Options['l'] -or $parsed.LongOptions['long']
    $humanReadable = $parsed.Options['h'] -or $parsed.LongOptions['human-readable']
    $sortByTime = $parsed.Options['t'] -or $parsed.LongOptions['time']
    $reverse = $parsed.Options['r'] -or $parsed.LongOptions['reverse']
    $recursive = $parsed.Options['R'] -or $parsed.LongOptions['recursive']
    $onlyDirs = $parsed.Options['d'] -or $parsed.LongOptions['directory']

    # 位置参数是路径列表
    $paths = $parsed.Positional
    if ($paths.Count -eq 0) { $paths = @('.') }

    # 处理每个路径
    foreach ($path in $paths) {
        $path = Convert-BashPath $path
        if (-not (Test-Path $path)) {
            Write-BashError -Command 'ls' -Message "cannot access '$path': No such file or directory"
            continue
        }

        # ... 核心实现逻辑
    }
}
```

### 6.2 grep 命令重构

```powershell
function grep {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'i' = @{ Long = 'ignore-case'; Type = 'switch' }
        'v' = @{ Long = 'invert-match'; Type = 'switch' }
        'n' = @{ Long = 'line-number'; Type = 'switch' }
        'c' = @{ Long = 'count'; Type = 'switch' }
        'l' = @{ Long = 'files-with-matches'; Type = 'switch' }
        'E' = @{ Long = 'extended-regexp'; Type = 'switch' }
        'e' = @{ Long = 'regexp'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: grep [-i] [-v] [-n] [-c] [-l] [-E] [-e PATTERN] [--help] PATTERN [FILE]...'
    }

    $ignoreCase = $parsed.Options['i'] -or $parsed.LongOptions['ignore-case']
    $invertMatch = $parsed.Options['v'] -or $parsed.LongOptions['invert-match']
    $showLineNumber = $parsed.Options['n'] -or $parsed.LongOptions['line-number']
    $onlyCount = $parsed.Options['c'] -or $parsed.LongOptions['count']
    $onlyFiles = $parsed.Options['l'] -or $parsed.LongOptions['files-with-matches']
    $extendedRegexp = $parsed.Options['E'] -or $parsed.LongOptions['extended-regexp']

    # Pattern 可来自 -e 参数或第一个位置参数
    $pattern = $parsed.Options['e']
    if (-not $pattern -and $parsed.Positional.Count -gt 0) {
        $pattern = $parsed.Positional[0]
        $files = $parsed.Positional[1..($parsed.Positional.Count - 1)]
    }

    if (-not $pattern) {
        Write-BashError -Command 'grep' -Message 'missing pattern'
        return
    }

    # ... 核心实现逻辑
}
```

---

## 7. 实施计划

### Phase 1: 创建参数解析模块

| 任务 | 内容 |
|------|------|
| 1.1 | 创建 `args-parser.ps1` 文件 |
| 1.2 | 实现 `Parse-BashArgs` 函数 |
| 1.3 | 实现 `Get-PipelineInput` 函数 |
| 1.4 | 实现 `Write-BashError` 函数 |
| 1.5 | 编写 `test-args-parser.ps1` 测试 |
| 1.6 | 更新 `bash-aliases.psm1` 导入 |

### Phase 2: 重构高频命令

| 任务 | 涉及函数 |
|------|----------|
| 2.1 | ls (增加 -t, -r, -R, -d, --color) |
| 2.2 | cat (增加 -n 格式改进) |
| 2.3 | rm (改进参数解析，支持 -v) |
| 2.4 | grep (增加 -c, -l, -E, -e) |

### Phase 3: 重构中频命令

| 任务 | 涉及函数 |
|------|----------|
| 3.1 | mkdir, cp, mv, touch, ll |
| 3.2 | head, tail (改进 -n 参数) |
| 3.3 | wc, sort, uniq (增加参数) |
| 3.4 | find (改进 -name, -type) |

### Phase 4: 重构其余命令

| 任务 | 涉及函数 |
|------|----------|
| 4.1 | ps, kill, killall, top |
| 4.2 | curl, wget, ping, netstat |
| 4.3 | less, df, du, uptime, uname, hostname |

### Phase 5: 更新安装和测试

| 任务 | 内容 |
|------|------|
| 5.1 | 更新 `install.ps1` 文件列表 |
| 5.2 | 更新所有测试文件适配新参数 |
| 5.3 | 运行完整测试套件 |

---

## 8. 验收标准

1. **参数解析**: 支持 `-la` 组合参数
2. **长参数**: 支持 `--all`, `--human-readable` 等
3. **参数值**: 支持 `-n 10` 和 `--lines=10`
4. **错误格式**: 错误消息模仿 bash 格式
5. **向后兼容**: 现有用法仍能正常工作
6. **测试通过**: 所有测试用例通过

---

## 9. 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| 参数冲突 | 保留 PowerShell 原生参数作为备选 |
| 性能影响 | 解析器保持轻量，避免复杂正则 |
| 兼容性破坏 | 渐进式迁移，保留旧接口过渡期 |
| 测试覆盖 | 每阶段完成后运行完整测试 |

---

## 10. 后续扩展

完成参数兼容性后，可进行以下扩展：

1. **命令扩展**: sed, awk, chmod, tar, diff 等
2. **配色系统**: 可配置的 dircolors
3. **帮助系统**: 增强 --help 输出
4. **Tab 补全**: ArgumentCompleter 支持
5. **配置文件**: ~/.bash_aliases_config