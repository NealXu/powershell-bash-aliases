# PowerShell Bash-Aliases

> 在 Windows PowerShell 中使用熟悉的 Linux 命令

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)](https://github.com/PowerShell/PowerShell)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## 简介

PowerShell Bash-Aliases 是一个 PowerShell 模块，提供 **66 个** bash 风格命令的 PowerShell 实现。让你在 Windows 上使用熟悉的 Linux 命令操作文件系统、查看系统信息、管理进程等。

## 特性

- ✅ **66 个常用 bash 命令** - 覆盖文件、文本、搜索、系统、进程、网络、压缩、工具八大类别
- ✅ **参数风格兼容** - 支持 `-a`、`-l`、`--help` 等 bash 风格参数
- ✅ **彩色输出** - 目录和可执行文件自动着色，与 WSL dircolors 一致
- ✅ **自动加载** - 安装后自动导入，开箱即用
- ✅ **单元测试** - 完整的 Pester 测试覆盖

## 快速开始

### 安装

```powershell
# 克隆仓库
git clone https://github.com/NealXu/powershell-bash-aliases.git
cd powershell-bash-aliases

# 安装并添加到 Profile
.\install.ps1 -AddToProfile -Force
```

安装脚本会自动识别本机安装的 PowerShell 类型,只部署到实际存在的 shell 对应目录:
- Windows PowerShell 5.1 → `$HOME\Documents\WindowsPowerShell\Modules\bash-aliases\`
- PowerShell 7+ (pwsh) → `$HOME\Documents\PowerShell\Modules\bash-aliases\`

也可用 `-InstallPaths` 手动指定安装位置。

### 验证

```powershell
# 重新打开 PowerShell 或手动导入
Import-Module bash-aliases

# 测试命令
ls -la
```

## 命令列表

### 📁 文件操作 (8个)

| 命令 | 说明 | 示例 |
|------|------|------|
| `ls` | 列出目录内容 | `ls -la`, `ls -lh` |
| `ll` | 详细列表（ls -l 别名） | `ll -h` |
| `cat` | 查看文件内容 | `cat -n file.txt` |
| `rm` | 删除文件/目录 | `rm -rf dir/` |
| `mkdir` | 创建目录 | `mkdir -p a/b/c` |
| `cp` | 复制文件/目录 | `cp -r src dest` |
| `mv` | 移动/重命名 | `mv old new` |
| `touch` | 创建/更新文件 | `touch file.txt` |

### 📝 文本处理 (7个)

| 命令 | 说明 | 示例 |
|------|------|------|
| `head` | 显示文件开头 | `head -n 20 file` |
| `tail` | 显示文件末尾 | `tail -f logfile` |
| `wc` | 统计行数/字数 | `wc -l *.txt` |
| `sort` | 排序 | `sort file.txt` |
| `uniq` | 去重 | `uniq -c file.txt` |
| `cut` | 按列切割 | `cut -d: -f1 file` |
| `tr` | 字符替换 | `tr 'a-z' 'A-Z'` |

### 🔍 搜索 (3个)

| 命令 | 说明 | 示例 |
|------|------|------|
| `grep` | 搜索文本 | `grep pattern *.txt` |
| `find` | 查找文件 | `find . -name "*.ps1"` |
| `which` | 查找命令位置 | `which python` |

### 💻 系统信息 (6个)

| 命令 | 说明 | 示例 |
|------|------|------|
| `df` | 磁盘使用情况 | `df -h` |
| `du` | 目录大小 | `du -sh dir/` |
| `uptime` | 系统运行时间 | `uptime` |
| `uname` | 系统信息 | `uname -a` |
| `hostname` | 主机名 | `hostname` |
| `yolo` | Codex 快捷命令 | `yolo "your prompt"` |

### ⚙️ 进程管理 (4个)

| 命令 | 说明 | 示例 |
|------|------|------|
| `ps` | 进程列表 | `ps aux` |
| `kill` | 终止进程 | `kill -9 PID` |
| `killall` | 按名终止进程 | `killall node` |
| `top` | 实时进程监控 | `top` |

### 🌐 网络 (4个)

| 命令 | 说明 | 示例 |
|------|------|------|
| `curl` | HTTP 请求 | `curl https://example.com` |
| `wget` | 下载文件 | `wget https://example.com/file` |
| `ping` | 网络测试 | `ping google.com` |
| `netstat` | 网络连接 | `netstat -an` |

### 👁️ 视图 (1个)

| 命令 | 说明 | 示例 |
|------|------|------|
| `less` | 分页查看 | `less file.txt` |

## 参数说明

命令支持常见的 bash 风格参数：

```powershell
# 短参数
ls -a          # 显示隐藏文件
ls -l          # 详细列表
ls -h          # 人类可读大小

# 组合参数
ls -la         # 等同于 ls -l -a
rm -rf         # 等同于 rm -r -f

# 长参数
ls --help      # 显示帮助
mkdir --parents dir/subdir   # 创建父目录

# 带值参数
head -n 20 file.txt
cut -d: -f1 /etc/passwd
find . -name "*.txt"
```

## 使用示例

```powershell
# 文件管理
ls -la                    # 详细列表，包含隐藏文件
ll -h                     # 详细列表，人类可读大小
cat -n config.txt         # 带行号查看
rm -rf temp/              # 强制删除目录
cp -r src/ dest/          # 递归复制
mv old.txt new.txt        # 重命名
touch README.md           # 创建空文件

# 文本处理
head -n 50 log.txt        # 查看前50行
tail -f app.log           # 实时跟踪日志
wc -l *.ps1               # 统计所有ps1文件行数
sort names.txt | uniq -c  # 排序并去重计数
grep "error" *.log        # 搜索所有日志中的error

# 系统信息
df -h                     # 磁盘使用情况
du -sh *                  # 当前目录各子目录大小
uptime                    # 系统运行时间
uname -a                  # 完整系统信息

# 进程管理
ps aux                    # 所有进程
kill -9 1234              # 强制终止进程PID 1234
killall chrome            # 终止所有chrome进程

# 网络
curl https://api.github.com    # HTTP GET
ping google.com                # 测试连通性
netstat -an                    # 所有网络连接
```

## ⚠️ 重要说明

### 别名覆盖

安装后，以下 PowerShell 别名会被 bash-aliases 函数覆盖：

| 原生别名 | 被覆盖后 |
|----------|----------|
| `ls` → Get-ChildItem | `ls` → bash-aliases 函数 |
| `cat` → Get-Content | `cat` → bash-aliases 函数 |
| `rm` → Remove-Item | `rm` → bash-aliases 函数 |
| ... | ... |

### 功能差异

- **输出类型**：bash-aliases 输出文本，原生命令输出对象
- **参数差异**：PowerShell 特有参数（如 `-Filter`、`-Recurse`）不可用
- **管道行为**：部分命令的管道行为与原生不同

### 恢复原生功能

如需临时恢复原生功能：

```powershell
# 移除模块
Remove-Module bash-aliases

# 恢复单个别名
Remove-Item Alias:ls -Force
```

## 卸载

```powershell
# 删除模块目录
Remove-Item "$HOME\Documents\WindowsPowerShell\Modules\bash-aliases" -Recurse

# 编辑 Profile 删除导入语句
notepad $PROFILE
```

删除以下内容：
```powershell
# Bash-aliases module - remove conflicting aliases before import
foreach ($a in @('cd','ls','cat','rm','cp','mv','ps','kill','sort','ping','wget','curl','echo','env','diff')) { Remove-Item Alias:$a -Force -ErrorAction SilentlyContinue }
Import-Module bash-aliases -Force -ErrorAction SilentlyContinue
```

## 开发

### 项目结构

```
powershell-bash-aliases/
├── bash-aliases.psd1    # 模块清单/入口（ScriptsToProcess 先运行 alias-cleanup.ps1）
├── bash-aliases.psm1    # 模块主文件
├── alias-cleanup.ps1    # 导入前清理内置别名（由 psd1 的 ScriptsToProcess 调用）
├── profile-setup.ps1    # 安装时向 Profile 写入/去重 preamble 块
├── install.ps1          # 安装脚本
├── args-parser.ps1      # Bash 参数解析器
├── utils.ps1            # 工具函数
├── core-file.ps1        # 文件命令
├── core-text.ps1        # 文本命令
├── core-search.ps1      # 搜索命令
├── core-process.ps1     # 进程命令
├── core-network.ps1     # 网络命令
├── core-view.ps1        # 视图命令
├── core-system.ps1      # 系统命令
└── tests/               # 测试文件
    ├── run-tests.ps1
    ├── test-core-file.ps1
    └── ...
```

### 运行测试

```powershell
# 安装 Pester（如未安装）
Install-Module Pester -Force -Scope CurrentUser

# 运行所有测试
.\tests\run-tests.ps1

# 运行单个测试文件
Invoke-Pester tests\test-core-file.ps1

# 运行端到端验收测试（安装布局 -> manifest 导入 -> 命令冒烟）
Invoke-Pester tests\test-e2e.ps1
```

> run-tests.ps1 会自动收集 test-e2e.ps1。e2e 只操作 `$env:TEMP` 下的临时目录，不会触碰真实安装目录或 Profile。

```powershell
# 在后台无窗口运行全量套件（避免在 Claude Code CLI 中阻塞/进度条驻留）：
.\run-tests-detached.ps1

# 该命令会在后台（headless，不弹窗）运行 run-tests.ps1 并立即返回，完成后进程自行退出；
# 完整输出（Start-Transcript）会写入 %TEMP%\bash-aliases-tests-<时间戳>.log。
```

## 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

## 许可证

[MIT License](LICENSE)

## 致谢

灵感来源于在 Windows 上使用 bash 命令的需求，感谢 PowerShell 社区的支持。