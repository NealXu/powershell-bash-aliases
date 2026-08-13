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
. $PSScriptRoot\core-edit.ps1

# Best-effort removal of built-in aliases from MODULE scope. Module scope CANNOT
# remove the global AllScope/ReadOnly built-in aliases (ls, cd, cat, ...) in
# PS 5.1 - only the caller's GLOBAL scope can - so for those aliases this loop
# is a silent no-op and Alias precedence still beats the exported functions.
# The authoritative cleanup is the manifest's ScriptsToProcess
# (alias-cleanup.ps1), which runs in the caller's session state before the
# module loads. This loop is kept because it still removes non-AllScope aliases
# and works on the dot-source path.
$aliases = @('cd', 'ls', 'cat', 'rm', 'cp', 'mv', 'ps', 'kill', 'wget', 'sort', 'ping', 'curl', 'echo', 'env', 'diff')
foreach ($a in $aliases) {
    Remove-Item "Alias:$a" -Force -ErrorAction SilentlyContinue
}

Export-ModuleMember -Function cd, ls, ll, cat, rm, mkdir, cp, mv, touch, head, tail, wc, sort, uniq, grep, find, which, ps, kill, curl, ping, less, df, du, uptime, uname, hostname, netstat, wget, killall, top, cut, tr, yolo, yoloc, echo, tee, history, time, watch, seq, yes, rev, shuf, xargs, tar, zip, unzip, gzip, gunzip, bzip2, bunzip2, basename, dirname, free, whoami, date, env, diff, awk, patch, jobs, bg, fg, nohup, more, sed, pgrep, pkill, ln, file, stat, realpath, vi, vim

# PSReadLine key bindings (align with WSL bash readline)
Import-Module PSReadLine -ErrorAction SilentlyContinue
if (Get-Module PSReadLine -ErrorAction SilentlyContinue) {
    Set-PSReadLineKeyHandler -Chord 'Ctrl+a' -Function BeginningOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+e' -Function EndOfLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+u' -Function BackwardKillLine
    Set-PSReadLineKeyHandler -Chord 'Ctrl+k' -Function KillLine
}

Write-Output "bash-aliases module loaded"