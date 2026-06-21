function ls {
    # PowerShell 参数绑定：先声明可能的参数名，避免被解析为未知参数
    param(
        [switch]$a, [switch]$l, [switch]$h,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    # 合并所有参数到数组
    $allArgs = @()
    if ($a) { $allArgs += '-a' }
    if ($l) { $allArgs += '-l' }
    if ($h) { $allArgs += '-h' }
    $allArgs += $ArgList

    $spec = @{
        'a' = @{ Long = 'all'; Type = 'switch' }
        'l' = @{ Long = 'long'; Type = 'switch' }
        'h' = @{ Long = 'human-readable'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: ls [-a] [-l] [-h] [--help] [PATH]'
    }

    $showAll = $parsed.Options['a'] -or $parsed.LongOptions['all']
    $longFormat = $parsed.Options['l'] -or $parsed.LongOptions['long']
    $humanReadable = $parsed.Options['h'] -or $parsed.LongOptions['human-readable']

    $paths = $parsed.Positional
    if ($paths.Count -eq 0) { $paths = @('.') }

    foreach ($Path in $paths) {
        $Path = Convert-BashPath $Path
        if (-not (Test-Path $Path)) {
            Write-BashError -Command 'ls' -Message "cannot access '$Path'"
            continue
        }
        $items = Get-ChildItem $Path -Force:$showAll | Sort-Object { $_.Name }
        if (-not $showAll) { $items = $items | Where-Object { -not $_.Name.StartsWith('.') } }
        if ($longFormat) {
            # ANSI color codes (matching WSL dircolors defaults)
            $E = [char]27
            $C_DIR = "$E[1;34m"   # bold blue - directories
            $C_EXE = "$E[1;32m"   # bold green - executables
            $C_LNK = "$E[1;36m"   # bold cyan - symlinks
            $C_RST = "$E[0m"
            $exeExts = @('.exe','.bat','.cmd','.ps1','.sh','.py','.pl','.rb')
            # Collect rows first to determine column widths
            $rows = @()
            foreach ($item in $items) {
                $m = Format-UnixMode $item
                $links = if ($item -is [System.IO.DirectoryInfo]) { 2 } else { 1 }
                $owner = $item.GetAccessControl().Owner.Split('\')[-1]
                $s = if ($item -is [System.IO.DirectoryInfo]) { 4096 } else { $item.Length }
                $sz = Format-FileSize $s -HumanReadable:$humanReadable
                $t = Format-FileTime $item.LastWriteTime
                $isDir = $item -is [System.IO.DirectoryInfo]
                $isExe = -not $isDir -and $exeExts -contains $item.Extension.ToLower()
                $color = if ($isDir) { $C_DIR } elseif ($isExe) { $C_EXE } else { '' }
                $rows += [PSCustomObject]@{
                    Mode=$m; Links=$links; Owner=$owner; Group=$owner; Size=$sz; Time=$t; Name=$item.Name; Color=$color
                }
            }
            # Compute column widths (right-aligned for links, size; left-aligned for owner, group)
            $wLinks = if ($rows.Count) { ($rows | ForEach { "$($_.Links)".Length } | Measure -Max).Maximum } else { 1 }
            $wOwner = if ($rows.Count) { ($rows | ForEach { $_.Owner.Length } | Measure -Max).Maximum } else { 1 }
            $wGroup = if ($rows.Count) { ($rows | ForEach { $_.Group.Length } | Measure -Max).Maximum } else { 1 }
            $wSize  = if ($rows.Count) { ($rows | ForEach { $_.Size.Length } | Measure -Max).Maximum } else { 1 }
            # Total line
            $totalSize = ($items | ForEach {
                if ($_ -is [System.IO.DirectoryInfo]) { 4096 } else { $_.Length }
            } | Measure -Sum).Sum
            if (-not $totalSize) { $totalSize = 0 }
            Write-Output "total $([Math]::Ceiling($totalSize / 1024))"
            # Format rows with alignment and color
            foreach ($r in $rows) {
                $linkStr = "$($r.Links)".PadLeft($wLinks)
                $ownerStr = $r.Owner.PadRight($wOwner)
                $groupStr = $r.Group.PadRight($wGroup)
                $sizeStr = $r.Size.PadLeft($wSize)
                $prefix = "$($r.Mode) $linkStr $ownerStr $groupStr $sizeStr $($r.Time) "
                if ($r.Color) {
                    Write-Output "$prefix$($r.Color)$($r.Name)$C_RST"
                } else {
                    Write-Output "$prefix$($r.Name)"
                }
            }
        } else {
            Format-Columns $items.Name
        }
    }
}
function cat {
    param(
        [switch]$n, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'number'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: cat [-n] [--help] FILE...'
    }

    $showNumbers = $parsed.Options['n'] -or $parsed.LongOptions['number']

    $lineNum = 1
    foreach ($p in $parsed.Positional) {
        $fp = Convert-BashPath $p
        if (-not (Test-Path $fp)) {
            Write-BashError -Command 'cat' -Message "cannot access '$fp'"
            continue
        }
        Get-Content $fp | ForEach-Object {
            if ($showNumbers) {
                Write-Output "$lineNum $_"
                $lineNum++
            } else {
                Write-Output $_
            }
        }
    }
}
function rm {
    param(
        [switch]$r, [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($r) { $allArgs += '-r' }
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'r' = @{ Long = 'recursive'; Type = 'switch' }
        'f' = @{ Long = 'force'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: rm [-r] [-f] [-rf] [--help] FILE...'
    }

    $recursive = $parsed.Options['r'] -or $parsed.LongOptions['recursive']
    $force = $parsed.Options['f'] -or $parsed.LongOptions['force']

    foreach ($p in $parsed.Positional) {
        $fp = Convert-BashPath $p
        $fp = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($fp)
        if (-not (Test-Path $fp)) {
            if (-not $force) { Write-BashError -Command 'rm' -Message "cannot remove '$fp'" }
            continue
        }
        $item = Get-Item $fp
        if ($item -is [System.IO.DirectoryInfo] -and -not $recursive) {
            Write-BashError -Command 'rm' -Message "'$fp' is a directory"
            continue
        }
        if ($item -is [System.IO.DirectoryInfo]) {
            # Use .NET for reliable recursive delete (handles read-only, .git objects)
            foreach ($fi in [System.IO.Directory]::GetFiles($fp, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { [System.IO.File]::SetAttributes($fi, 'Normal') } catch {}
            }
            foreach ($fi in [System.IO.Directory]::GetFiles($fp, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { [System.IO.File]::Delete($fi) } catch {}
            }
            foreach ($di in ([System.IO.Directory]::GetDirectories($fp, '*', [System.IO.SearchOption]::AllDirectories) | Sort-Object { $_.Length } -Descending)) {
                try { [System.IO.Directory]::Delete($di, $false) } catch {}
            }
            try { [System.IO.Directory]::Delete($fp, $true) } catch {}
        } else {
            if ($force -and (Get-Item $fp).IsReadOnly) { (Get-Item $fp).IsReadOnly = $false }
            Remove-Item $fp -Force:$force
        }
    }
}
function mkdir {
    param(
        [switch]$p,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    # 合并参数
    $allArgs = @()
    if ($p) { $allArgs += '-p' }
    $allArgs += $ArgList

    $spec = @{
        'p' = @{ Long = 'parents'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: mkdir [-p] [--help] DIR...'
    }

    $createParents = $parsed.Options['p'] -or $parsed.LongOptions['parents']

    foreach ($d in $parsed.Positional) {
        $dp = Convert-BashPath $d
        if ($createParents) {
            New-Item -ItemType Directory -Path $dp -Force | Out-Null
        } else {
            New-Item -ItemType Directory -Path $dp -ErrorAction SilentlyContinue | Out-Null
        }
    }
}
function cp {
    param(
        [switch]$r, [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($r) { $allArgs += '-r' }
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'r' = @{ Long = 'recursive'; Type = 'switch' }
        'f' = @{ Long = 'force'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: cp [-r] [-f] [--help] SOURCE DEST'
    }

    $recursive = $parsed.Options['r'] -or $parsed.LongOptions['recursive']
    $force = $parsed.Options['f'] -or $parsed.LongOptions['force']

    if ($parsed.Positional.Count -lt 2) {
        Write-BashError -Command 'cp' -Message 'missing source or destination'
        return
    }

    $source = Convert-BashPath $parsed.Positional[0]
    $dest = Convert-BashPath $parsed.Positional[1]
    Copy-Item $source $dest -Recurse:$recursive -Force:$force
}
function mv {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: mv [--help] SOURCE DEST'
    }

    if ($parsed.Positional.Count -lt 2) {
        Write-BashError -Command 'mv' -Message 'missing source or destination'
        return
    }

    $source = Convert-BashPath $parsed.Positional[0]
    $dest = Convert-BashPath $parsed.Positional[1]
    Move-Item $source $dest -Force
}
function touch {
    param(
        [switch]$c, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($c) { $allArgs += '-c' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'c' = @{ Long = 'no-create'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: touch [-c] [--help] FILE...'
    }

    $noCreate = $parsed.Options['c'] -or $parsed.LongOptions['no-create']

    foreach ($f in $parsed.Positional) {
        $fp = Convert-BashPath $f
        if (Test-Path $fp) {
            (Get-Item $fp).LastWriteTime = Get-Date
        } elseif (-not $noCreate) {
            New-Item -ItemType File -Path $fp | Out-Null
        }
    }
}
function ll {
    param(
        [switch]$a, [switch]$h,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    # 合并参数
    $allArgs = @()
    if ($a) { $allArgs += '-a' }
    if ($h) { $allArgs += '-h' }
    $allArgs += $ArgList

    $spec = @{
        'a' = @{ Long = 'all'; Type = 'switch' }
        'h' = @{ Long = 'human-readable'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: ll [-a] [-h] [--help] [PATH] (equivalent to ls -la)'
    }

    $showAll = $parsed.Options['a'] -or $parsed.LongOptions['all']
    $humanReadable = $parsed.Options['h'] -or $parsed.LongOptions['human-readable']

    $path = if ($parsed.Positional.Count -gt 0) { $parsed.Positional[0] } else { '.' }
    $p = Convert-BashPath $path

    $items = Get-ChildItem $p -Force:$showAll | Sort-Object { $_.Name }
    if (-not $showAll) { $items = $items | Where-Object { -not $_.Name.StartsWith('.') } }

    # ANSI color codes (matching WSL dircolors defaults)
    $E = [char]27
    $C_DIR = "$E[1;34m"   # bold blue - directories
    $C_EXE = "$E[1;32m"   # bold green - executables
    $C_RST = "$E[0m"
    $exeExts = @('.exe','.bat','.cmd','.ps1','.sh','.py','.pl','.rb')

    # Collect rows first to determine column widths
    $rows = @()
    foreach ($item in $items) {
        $m = Format-UnixMode $item
        $links = if ($item -is [System.IO.DirectoryInfo]) { 2 } else { 1 }
        $owner = $item.GetAccessControl().Owner.Split('\')[-1]
        $s = if ($item -is [System.IO.DirectoryInfo]) { 4096 } else { $item.Length }
        $sz = Format-FileSize $s -HumanReadable:$humanReadable
        $t = Format-FileTime $item.LastWriteTime
        $isDir = $item -is [System.IO.DirectoryInfo]
        $isExe = -not $isDir -and $exeExts -contains $item.Extension.ToLower()
        $color = if ($isDir) { $C_DIR } elseif ($isExe) { $C_EXE } else { '' }
        $rows += [PSCustomObject]@{
            Mode=$m; Links=$links; Owner=$owner; Group=$owner; Size=$sz; Time=$t; Name=$item.Name; Color=$color
        }
    }
    # Compute column widths (right-aligned for links, size; left-aligned for owner, group)
    $wLinks = if ($rows.Count) { ($rows | ForEach-Object { "$($_.Links)".Length } | Measure-Object -Maximum).Maximum } else { 1 }
    $wOwner = if ($rows.Count) { ($rows | ForEach-Object { $_.Owner.Length } | Measure-Object -Maximum).Maximum } else { 1 }
    $wGroup = if ($rows.Count) { ($rows | ForEach-Object { $_.Group.Length } | Measure-Object -Maximum).Maximum } else { 1 }
    $wSize  = if ($rows.Count) { ($rows | ForEach-Object { $_.Size.Length } | Measure-Object -Maximum).Maximum } else { 1 }
    # Total line
    $totalSize = ($items | ForEach-Object {
        if ($_ -is [System.IO.DirectoryInfo]) { 4096 } else { $_.Length }
    } | Measure-Object -Sum).Sum
    if (-not $totalSize) { $totalSize = 0 }
    Write-Output "total $([Math]::Ceiling($totalSize / 1024))"
    # Format rows with alignment and color
    foreach ($r in $rows) {
        $linkStr = "$($r.Links)".PadLeft($wLinks)
        $ownerStr = $r.Owner.PadRight($wOwner)
        $groupStr = $r.Group.PadRight($wGroup)
        $sizeStr = $r.Size.PadLeft($wSize)
        $prefix = "$($r.Mode) $linkStr $ownerStr $groupStr $sizeStr $($r.Time) "
        if ($r.Color) {
            Write-Output "$prefix$($r.Color)$($r.Name)$C_RST"
        } else {
            Write-Output "$prefix$($r.Name)"
        }
    }
}


