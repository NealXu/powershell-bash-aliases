# bash-aliases.psm1
# PowerShell Bash Aliases Module

. $PSScriptRoot\args-parser.ps1
. $PSScriptRoot\utils.ps1
. $PSScriptRoot\core-file.ps1
. $PSScriptRoot\core-text.ps1
. $PSScriptRoot\core-search.ps1
. $PSScriptRoot\core-process.ps1
. $PSScriptRoot\core-network.ps1
. $PSScriptRoot\core-view.ps1
. $PSScriptRoot\core-system.ps1
. $PSScriptRoot\core-utils.ps1
. $PSScriptRoot\core-compress.ps1

# 强制覆盖 PowerShell 内置别名（在全局作用域移除，确保函数优先于别名）
$aliases = @('ls', 'cat', 'rm', 'cp', 'mv', 'ps', 'kill', 'wget', 'sort', 'ping', 'curl', 'echo')
foreach ($a in $aliases) {
    # 使用全局作用域移除别名
    Remove-Item "Global:Alias:$a" -Force -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function ls, ll, cat, rm, mkdir, cp, mv, touch, head, tail, wc, sort, uniq, grep, find, which, ps, kill, curl, ping, less, df, du, uptime, uname, hostname, netstat, wget, killall, top, cut, tr, yolo, yoloc, echo, tee, history, time, watch, seq, yes, rev, shuf, xargs, tar, zip, unzip, gzip, gunzip, bzip2, bunzip2

# PSReadLine key bindings (align with WSL bash readline)
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardKillLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function KillLine
}

Write-Output "bash-aliases module loaded"