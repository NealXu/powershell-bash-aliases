# PowerShell Bash-Aliases 项目文档

> PowerShell 模块，提供 31 个 bash 命令的 PowerShell 实现

## 安装部署

```powershell
.\install.ps1 -AddToProfile -Force  # 安装并添加到 Profile
```

目标路径：`$HOME\Documents\PowerShell\Modules\bash-aliases\`

## 用户使用

自动加载后直接使用：
```powershell
ls -la
cat -n file.txt
grep pattern *.txt
df -h
```

## 系统影响

### ⚠️ 关键风险：别名覆盖

| 原生别名 | 被覆盖后 |
|----------|----------|
| `ls` → Get-ChildItem | `ls` → bash-aliases 函数 |
| `cat` → Get-Content | `cat` → bash-aliases 函数 |

**影响：**
- `-Filter`、`-Recurse` 等 PowerShell 参数失效
- 输出是文本而非对象

## 卸载

```powershell
Remove-Item "$HOME\Documents\PowerShell\Modules\bash-aliases" -Recurse
notepad $PROFILE  # 删除 Import-Module 行
```

## 命令列表（31个）

文件：ls, cat, rm, mkdir, cp, mv, touch
文本：head, tail, wc, sort, uniq, cut, tr
搜索：grep, find, which
系统：df, du, uptime, uname, hostname
进程：ps, kill, killall, top
网络：curl, ping, netstat, wget
视图：less