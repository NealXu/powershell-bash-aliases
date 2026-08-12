# 新增命令功能设计文档

**日期**: 2026-08-12
**项目**: powershell-bash-aliases
**目标**: 扩展 35 个 bash 标准命令，提升命令覆盖完整度

---

## 1. 背景

### 当前状态

项目已实现 31 个 bash 命令，覆盖文件、文本、搜索、系统、进程、网络六大类别。

### 功能缺口

| 类别 | 缺失常用命令 |
|------|--------------|
| 文件操作 | ln, file, stat, realpath, basename, dirname |
| 文本处理 | sed, awk, diff, patch, tee |
| 搜索 | locate (可选) |
| 系统信息 | free, date, whoami, id, env |
| 进程管理 | pgrep, pkill, jobs, bg, fg, nohup |
| 压缩 | tar, zip, unzip, gzip, bzip2 |
| 工具 | echo, history, time, watch, seq, yes, rev, shuf, xargs |

### 设计目标

- 新增 35 个 bash 标准命令
- 保持现有架构风格
- 分批实现，渐进交付
- 测试覆盖每个新命令

---

## 2. 架构设计

### 模块结构

```
bash-aliases.psm1
    ├── args-parser.ps1 (现有)
    ├── utils.ps1 (现有)
    ├── core-file.ps1 (扩展 +150 行)
    ├── core-text.ps1 (扩展 +250 行)
    ├── core-search.ps1 (不变)
    ├── core-process.ps1 (扩展 +180 行)
    ├── core-network.ps1 (不变)
    ├── core-view.ps1 (扩展 +40 行)
    ├── core-system.ps1 (扩展 +120 行)
    ├── core-compress.ps1 (新增 ~250 行)
    └── core-utils.ps1 (新增 ~200 行)
```

### 新增模块

#### core-compress.ps1

压缩解压命令模块，包含：
- tar - 归档工具
- zip/unzip - ZIP 压缩
- gzip/gunzip - GZIP 压缩
- bzip2/bunzip2 - BZIP2 压缩

#### core-utils.ps1

通用工具命令模块，包含：
- echo - 增强版输出
- tee - 管道分流
- history - 命令历史
- time - 命令计时
- watch - 周期执行
- seq - 序列生成
- yes - 重复输出
- rev - 反转行
- shuf - 随机排序
- xargs - 参数构建

### 现有模块扩展

| 模块 | 新增命令 |
|------|----------|
| core-file.ps1 | ln, file, stat, realpath, basename, dirname |
| core-text.ps1 | sed, awk, diff, patch, tee |
| core-process.ps1 | pgrep, pkill, jobs, bg, fg, nohup |
| core-system.ps1 | free, date, whoami, id, env |
| core-view.ps1 | more |

---

## 3. 分批实现计划

### Batch 1: 高价值低难度 (8 命令)

| 命令 | 说明 | 难度 |
|------|------|------|
| echo | 增强版输出，支持 -n -e | 低 |
| tee | 管道分流 | 低 |
| diff | 文件对比 | 低 |
| free | 内存查看 | 低 |
| date | 日期时间 | 低 |
| whoami | 当前用户 | 低 |
| env | 环境变量 | 低 |
| basename/dirname | 路径处理 | 低 |

**预计工作量**: 1-2 天

### Batch 2: 中等难度 (10 命令)

| 命令 | 说明 | 难度 |
|------|------|------|
| sed | 流编辑器 | 中 |
| tar | 归档工具 | 中 |
| zip/unzip | ZIP 压缩 | 低 |
| gzip/gunzip | GZIP 压缩 | 中 |
| pgrep/pkill | 进程搜索/终止 | 低 |
| ln | 链接创建 | 低 |
| file | 文件类型 | 低 |
| stat | 文件状态 | 低 |
| realpath | 绝对路径 | 低 |

**预计工作量**: 2-3 天

### Batch 3: 复杂命令 (9 命令)

| 命令 | 说明 | 难度 |
|------|------|------|
| awk | 文本处理语言 | 高 |
| patch | 补丁应用 | 中 |
| jobs/bg/fg/nohup | 任务管理 | 中 |
| bzip2/bunzip2 | BZIP2 压缩 | 中 |
| more | 分页查看 | 低 |

**预计工作量**: 2-3 天

### Batch 4: 辅助命令 (8 命令)

| 命令 | 说明 | 难度 |
|------|------|------|
| history | 命令历史 | 低 |
| time | 命令计时 | 低 |
| watch | 周期执行 | 低 |
| seq | 序列生成 | 低 |
| yes | 重复输出 | 低 |
| rev | 反转行 | 低 |
| shuf | 随机排序 | 低 |
| xargs | 参数构建 | 中 |

**预计工作量**: 1-2 天

---

## 4. 命令详细设计

### 4.1 Batch 1 命令

#### echo - 增强版输出

```powershell
function echo {
    param(
        [switch]$n,           # 不换行
        [switch]$e,           # 启用转义解析
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # 支持 -n (不换行), -e (转义: \n, \t, \\)
}
```

**参数**:
- `-n`, `--no-newline` - 不输出换行
- `-e`, `--enable-escape` - 解析转义字符

**示例**:
```powershell
echo "Hello World"           # Hello World
echo -n "No newline"         # 不换行
echo -e "Line1\nLine2"       # 解析换行
```

#### tee - 管道分流

```powershell
function tee {
    param(
        [switch]$a,           # 追加模式
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # 从管道读取，输出到文件和标准输出
}
```

**参数**:
- `-a`, `--append` - 追加到文件

**示例**:
```powershell
ls | tee output.txt           # 输出到屏幕和文件
cat file | tee -a log.txt     # 追加到日志
```

#### diff - 文件对比

```powershell
function diff {
    param(
        [switch]$u,           # unified 格式
        [switch]$q,           # 仅报告是否不同
        [switch]$r,           # 递归比较目录
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

**参数**:
- `-u`, `--unified` - unified 格式
- `-q`, `--brief` - 仅报告是否不同
- `-r`, `--recursive` - 递归比较

#### free - 内存查看

```powershell
function free {
    param(
        [switch]$h,           # 人类可读
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # 显示内存使用情况
}
```

#### date - 日期时间

```powershell
function date {
    param(
        [string]$d,           # 指定日期
        [string]$u,           # UTC
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # 支持格式化输出 +FORMAT
}
```

**参数**:
- `-d DATE` - 指定日期
- `+FORMAT` - 格式字符串 (%Y, %m, %d, %H, %M, %S)

#### whoami - 当前用户

```powershell
function whoami {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 输出 $env:USERNAME
}
```

#### env - 环境变量

```powershell
function env {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 显示所有或指定环境变量
}
```

#### basename/dirname - 路径处理

```powershell
function basename {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 提取文件名，支持去除后缀
}

function dirname {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 提取目录路径
}
```

---

### 4.2 Batch 2 命令

#### sed - 流编辑器

```powershell
function sed {
    param(
        [string]$e,           # 表达式
        [switch]$i,           # 原地编辑
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # 支持 s/pattern/replacement/[gi] 语法
}
```

**参数**:
- `-e SCRIPT` - 编辑脚本
- `-i`, `--in-place` - 原地编辑

**示例**:
```powershell
sed 's/old/new/g' file.txt    # 全局替换
sed -i 's/foo/bar/' file      # 原地编辑
```

#### tar - 归档工具

```powershell
function tar {
    param(
        [switch]$c,           # 创建
        [switch]$x,           # 解压
        [switch]$t,           # 列出
        [switch]$v,           # 详细
        [switch]$z,           # gzip
        [switch]$j,           # bzip2
        [string]$f,           # 文件名
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

**参数**:
- `-c` 创建, `-x` 解压, `-t` 列出
- `-z` gzip, `-j` bzip2
- `-f ARCHIVE` 归档文件

#### zip/unzip - ZIP 压缩

```powershell
function zip {
    param(
        [switch]$r,           # 递归
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}

function unzip {
    param(
        [switch]$l,           # 列出
        [switch]$o,           # 覆盖
        [string]$d,           # 目标目录
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### gzip/gunzip - GZIP 压缩

```powershell
function gzip {
    param(
        [switch]$d,           # 解压
        [switch]$k,           # 保留原文件
        [switch]$v,           # 详细输出
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### pgrep/pkill - 进程搜索/终止

```powershell
function pgrep {
    param(
        [switch]$l,           # 显示进程名
        [switch]$f,           # 匹配完整命令行
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}

function pkill {
    param(
        [switch]$f,           # 匹配完整命令行
        [switch]$9,           # 强制终止
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### ln - 链接创建

```powershell
function ln {
    param(
        [switch]$s,           # 符号链接
        [switch]$f,           # 强制覆盖
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### file - 文件类型

```powershell
function file {
    param(
        [switch]$b,           # 简短输出
        [switch]$i,           # MIME 类型
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### stat - 文件状态

```powershell
function stat {
    param(
        [string]$c,           # 格式化输出
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### realpath - 绝对路径

```powershell
function realpath {
    param(
        [switch]$s,           # 解析符号链接
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

---

### 4.3 Batch 3 命令

#### awk - 文本处理语言

```powershell
function awk {
    param(
        [string]$F,           # 字段分隔符
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # 支持基本 print 和字段访问 $1, $2...
}
```

**参数**:
- `-F SEP` - 字段分隔符

**示例**:
```powershell
awk '{print $1}' file.txt     # 打印第一列
awk -F: '{print $1}' file     # 指定分隔符
```

#### patch - 补丁应用

```powershell
function patch {
    param(
        [switch]$p,           # 去除路径前缀
        [switch]$R,           # 反向应用
        [string]$i,           # 补丁文件
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### jobs/bg/fg/nohup - 任务管理

```powershell
function jobs {
    # 列出后台任务
}

function bg {
    param([int]$jobId = 1)
    # 恢复任务到后台
}

function fg {
    param([int]$jobId = 1)
    # 恢复任务到前台
}

function nohup {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 后台运行，忽略挂断信号
}
```

#### bzip2/bunzip2 - BZIP2 压缩

```powershell
function bzip2 {
    param(
        [switch]$d,           # 解压
        [switch]$k,           # 保留原文件
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### more - 分页查看

```powershell
function more {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 分页显示文件内容
}
```

---

### 4.4 Batch 4 命令

#### history - 命令历史

```powershell
function history {
    param(
        [int]$n,             # 显示最近 N 条
        [switch]$c,          # 清除历史
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### time - 命令计时

```powershell
function time {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 执行命令并报告时间
}
```

#### watch - 周期执行

```powershell
function watch {
    param(
        [int]$n,             # 间隔秒数
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### seq - 序列生成

```powershell
function seq {
    param(
        [string]$s,           # 分隔符
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
    # 生成数字序列
}
```

#### yes - 重复输出

```powershell
function yes {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 无限重复输出字符串
}
```

#### rev - 反转行

```powershell
function rev {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList)
    # 反转每行字符
}
```

#### shuf - 随机排序

```powershell
function shuf {
    param(
        [int]$n,             # 输出前 N 行
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

#### xargs - 参数构建

```powershell
function xargs {
    param(
        [int]$n,             # 每次参数数
        [string]$I,          # 替换字符串
        [string]$d,          # 分隔符
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )
}
```

---

## 5. 实施计划

### Phase 1: 基础设施

| 任务 | 说明 |
|------|------|
| 1.1 | 创建 `core-compress.ps1` 文件框架 |
| 1.2 | 创建 `core-utils.ps1` 文件框架 |
| 1.3 | 更新 `bash-aliases.psm1` 导入 |
| 1.4 | 更新 `install.ps1` 文件列表 |

### Phase 2: Batch 1 实现

| 任务 | 说明 |
|------|------|
| 2.1 | 实现 echo, tee |
| 2.2 | 实现 diff, free |
| 2.3 | 实现 date, whoami, env |
| 2.4 | 实现 basename, dirname |
| 2.5 | 编写测试 `test-core-utils.ps1` |
| 2.6 | 运行测试验证 |

### Phase 3: Batch 2 实现

| 任务 | 说明 |
|------|------|
| 3.1 | 实现 sed |
| 3.2 | 实现 tar, zip/unzip |
| 3.3 | 实现 gzip/gunzip |
| 3.4 | 实现 pgrep, pkill |
| 3.5 | 实现 ln, file, stat, realpath |
| 3.6 | 编写测试 `test-core-compress.ps1` |
| 3.7 | 更新 `test-core-file.ps1` |

### Phase 4: Batch 3 实现

| 任务 | 说明 |
|------|------|
| 4.1 | 实现 awk |
| 4.2 | 实现 patch |
| 4.3 | 实现 jobs/bg/fg/nohup |
| 4.4 | 实现 bzip2/bunzip2 |
| 4.5 | 实现 more |
| 4.6 | 更新测试文件 |

### Phase 5: Batch 4 实现

| 任务 | 说明 |
|------|------|
| 5.1 | 实现 history, time, watch |
| 5.2 | 实现 seq, yes, rev, shuf |
| 5.3 | 实现 xargs |
| 5.4 | 更新测试文件 |

### Phase 6: 集成测试

| 任务 | 说明 |
|------|------|
| 6.1 | 运行完整测试套件 |
| 6.2 | 更新 README 文档 |
| 6.3 | 版本发布 |

---

## 6. 测试策略

### 测试文件

| 文件 | 覆盖模块 |
|------|----------|
| test-core-utils.ps1 | core-utils.ps1 (新增) |
| test-core-compress.ps1 | core-compress.ps1 (新增) |
| test-core-file.ps1 | core-file.ps1 (扩展) |
| test-core-text.ps1 | core-text.ps1 (扩展) |
| test-core-process.ps1 | core-process.ps1 (扩展) |
| test-core-system.ps1 | core-system.ps1 (扩展) |
| test-core-view.ps1 | core-view.ps1 (扩展) |

### 测试覆盖

- 每个命令至少 3 个测试用例
- 覆盖正常用法、边界情况、错误处理
- 参数组合测试

---

## 7. 风险与缓解

| 风险 | 缓解措施 |
|------|----------|
| Windows 权限限制 | ln 符号链接需要管理员权限，提供友好提示 |
| 压缩格式兼容 | tar.gz/bzip2 依赖 7-Zip，提示用户安装 |
| awk 复杂度 | 仅实现基本功能，复杂场景建议使用 PowerShell |
| nohup 行为差异 | Windows 无真正 nohup，用 Start-Job 模拟 |

---

## 8. 验收标准

1. **功能完整**: 35 个命令全部实现
2. **参数兼容**: 支持 bash 风格参数
3. **测试通过**: 所有测试用例通过
4. **文档更新**: README 包含新命令
5. **向后兼容**: 现有命令行为不变

---

## 9. 后续扩展

完成本设计后，可考虑：

1. **Tab 补全** - ArgumentCompleter 支持
2. **配置文件** - ~/.bash_aliases 配置
3. **帮助系统** - 增强 --help 输出
4. **性能优化** - 大文件处理优化
5. **Windows 特有** - open, clip 等命令