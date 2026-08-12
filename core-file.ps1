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
        if ([string]::IsNullOrWhiteSpace($Path)) { continue }
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

function basename {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'a' = @{ Long = 'multiple'; Type = 'switch' }
        's' = @{ Long = 'suffix'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: basename [-a] [-s SUFFIX] NAME [SUFFIX]... [--help]'
    }

    $multiple = $parsed.Options['a'] -or $parsed.LongOptions['multiple']
    $suffix = $parsed.Options['s']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'basename' -Message 'missing operand'
        return
    }

    foreach ($path in $parsed.Positional) {
        $p = Convert-BashPath $path
        $name = [System.IO.Path]::GetFileName($p)

        # Remove trailing slashes for directory paths
        $name = $name.TrimEnd('\', '/')

        # Remove suffix if specified
        if ($suffix -and $name.EndsWith($suffix)) {
            $name = $name.Substring(0, $name.Length - $suffix.Length)
        }

        Write-Output $name

        if (-not $multiple) {
            break
        }
    }
}

function dirname {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'z' = @{ Long = 'zero'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: dirname [-z] NAME... [--help]'
    }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'dirname' -Message 'missing operand'
        return
    }

    foreach ($path in $parsed.Positional) {
        $p = Convert-BashPath $path
        $dir = [System.IO.Path]::GetDirectoryName($p)

        # Handle root paths and paths without directory components
        if ([string]::IsNullOrEmpty($dir)) {
            $dir = '.'
        }

        Write-Output $dir
    }
}

function diff {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'q' = @{ Long = 'brief'; Type = 'switch' }
        's' = @{ Long = 'report-identical-files'; Type = 'switch' }
        'u' = @{ Long = 'unified'; Type = 'switch' }
        'r' = @{ Long = 'recursive'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: diff [-q] [-s] [-u] [-r] FILE1 FILE2 [--help]'
    }

    $brief = $parsed.Options['q'] -or $parsed.LongOptions['brief']
    $reportIdentical = $parsed.Options['s'] -or $parsed.LongOptions['report-identical-files']
    $unified = $parsed.Options['u'] -or $parsed.LongOptions['unified']
    $recursive = $parsed.Options['r'] -or $parsed.LongOptions['recursive']

    if ($parsed.Positional.Count -lt 2) {
        Write-BashError -Command 'diff' -Message 'missing file operand'
        return
    }

    $file1 = Convert-BashPath $parsed.Positional[0]
    $file2 = Convert-BashPath $parsed.Positional[1]

    if (-not (Test-Path $file1)) {
        Write-BashError -Command 'diff' -Message "cannot access '$file1'"
        return
    }

    if (-not (Test-Path $file2)) {
        Write-BashError -Command 'diff' -Message "cannot access '$file2'"
        return
    }

    # Check if both are directories
    $item1 = Get-Item $file1
    $item2 = Get-Item $file2

    if ($item1 -is [System.IO.DirectoryInfo] -and $item2 -is [System.IO.DirectoryInfo]) {
        if ($recursive) {
            # Compare directories recursively
            $files1 = Get-ChildItem $file1 -Recurse -File | Select-Object -ExpandProperty FullName
            $files2 = Get-ChildItem $file2 -Recurse -File | Select-Object -ExpandProperty FullName

            foreach ($f1 in $files1) {
                $relPath = $f1.Substring($file1.Length)
                $f2 = "$file2$relPath"

                if (Test-Path $f2) {
                    $content1 = Get-Content $f1
                    $content2 = Get-Content $f2

                    if (Compare-Object $content1 $content2) {
                        Write-Output "Files $f1 and $f2 differ"
                    }
                } else {
                    Write-Output "Only in ${file1}: $relPath"
                }
            }
        } else {
            Write-BashError -Command 'diff' -Message 'comparing directories requires -r'
        }
        return
    }

    # Compare files
    $content1 = Get-Content $file1
    $content2 = Get-Content $file2

    $diff = Compare-Object $content1 $content2

    if (-not $diff) {
        if ($reportIdentical) {
            Write-Output "Files $file1 and $file2 are identical"
        }
        return
    }

    if ($brief) {
        Write-Output "Files $file1 and $file2 differ"
        return
    }

    # Show unified diff format
    if ($unified) {
        Write-Output "--- $file1"
        Write-Output "+++ $file2"

        $lineNum = 1
        $diff | ForEach-Object {
            $prefix = if ($_.$_.SideIndicator -eq '<=') { '-' } else { '+' }
            Write-Output "$prefix$($_.InputObject)"
            $lineNum++
        }
    } else {
        # Show standard diff format
        $diff | ForEach-Object {
            if ($_.$_.SideIndicator -eq '<=') {
                Write-Output "< $($_.InputObject)"
            } else {
                Write-Output "> $($_.InputObject)"
            }
        }
    }
}

function ln {
    param(
        [switch]$s, [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($s) { $allArgs += '-s' }
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        's' = @{ Long = 'symbolic'; Type = 'switch' }
        'f' = @{ Long = 'force'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: ln [-s] [-f] TARGET LINK_NAME [--help]'
    }

    $symbolic = $parsed.Options['s'] -or $parsed.LongOptions['symbolic']
    $force = $parsed.Options['f'] -or $parsed.LongOptions['force']

    if ($parsed.Positional.Count -lt 2) {
        Write-BashError -Command 'ln' -Message 'missing target or link name'
        return
    }

    $target = Convert-BashPath $parsed.Positional[0]
    $linkName = Convert-BashPath $parsed.Positional[1]

    if (-not (Test-Path $target)) {
        Write-BashError -Command 'ln' -Message "cannot access '$target'"
        return
    }

    if (Test-Path $linkName) {
        if ($force) {
            Remove-Item $linkName -Force
        } else {
            Write-BashError -Command 'ln' -Message "'$linkName' already exists"
            return
        }
    }

    try {
        if ($symbolic) {
            # On Windows, New-Item -ItemType SymbolicLink requires admin rights
            # Fallback to junction for directories
            $targetItem = Get-Item $target
            if ($targetItem -is [System.IO.DirectoryInfo]) {
                New-Item -ItemType Junction -Path $linkName -Target $target | Out-Null
            } else {
                New-Item -ItemType SymbolicLink -Path $linkName -Target $target | Out-Null
            }
        } else {
            # Hard link (only works for files on same volume)
            $targetItem = Get-Item $target
            if ($targetItem -is [System.IO.DirectoryInfo]) {
                Write-BashError -Command 'ln' -Message 'hard link not supported for directories'
                return
            }
            New-Item -ItemType HardLink -Path $linkName -Target $target | Out-Null
        }
    } catch {
        Write-BashError -Command 'ln' -Message $_.Exception.Message
    }
}

function file {
    param(
        [switch]$i, [switch]$b, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($i) { $allArgs += '-i' }
    if ($b) { $allArgs += '-b' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'i' = @{ Long = 'mime'; Type = 'switch' }
        'b' = @{ Long = 'brief'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: file [-i] [-b] FILE... [--help]'
    }

    $mime = $parsed.Options['i'] -or $parsed.LongOptions['mime']
    $brief = $parsed.Options['b'] -or $parsed.LongOptions['brief']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'file' -Message 'missing operand'
        return
    }

    foreach ($f in $parsed.Positional) {
        $filePath = Convert-BashPath $f

        if (-not (Test-Path $filePath)) {
            Write-BashError -Command 'file' -Message "cannot access '$filePath'"
            continue
        }

        $item = Get-Item $filePath
        $fileType = ''

        if ($item -is [System.IO.DirectoryInfo]) {
            $fileType = 'directory'
            if ($mime) { $fileType = 'inode/directory' }
        } elseif ($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            $fileType = 'symbolic link'
            if ($mime) { $fileType = 'inode/symlink' }
        } else {
            # Detect file type by extension
            $ext = $item.Extension.ToLower()
            $content = $null

            # Try to read first few bytes for detection
            try {
                $bytes = [System.IO.File]::ReadAllBytes($filePath)
                if ($bytes.Length -ge 4) {
                    # Check magic numbers
                    if ($bytes[0] -eq 0x7F -and $bytes[1] -eq 0x45 -and $bytes[2] -eq 0x4C -and $bytes[3] -eq 0x46) {
                        $fileType = 'ELF executable'
                        if ($mime) { $fileType = 'application/x-executable' }
                    } elseif ($bytes[0] -eq 0x4D -and $bytes[1] -eq 0x5A) {
                        $fileType = 'PE32 executable (Windows)'
                        if ($mime) { $fileType = 'application/x-dosexec' }
                    } elseif ($bytes[0] -eq 0x25 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x44 -and $bytes[3] -eq 0x46) {
                        $fileType = 'PDF document'
                        if ($mime) { $fileType = 'application/pdf' }
                    } elseif ($bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50 -and $bytes[2] -eq 0x4E -and $bytes[3] -eq 0x47) {
                        $fileType = 'PNG image'
                        if ($mime) { $fileType = 'image/png' }
                    } elseif ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8) {
                        $fileType = 'JPEG image'
                        if ($mime) { $fileType = 'image/jpeg' }
                    } elseif ($bytes[0] -eq 0x47 -and $bytes[1] -eq 0x49 -and $bytes[2] -eq 0x46) {
                        $fileType = 'GIF image'
                        if ($mime) { $fileType = 'image/gif' }
                    } elseif ($bytes[0] -eq 0x1F -and $bytes[1] -eq 0x8B) {
                        $fileType = 'gzip compressed'
                        if ($mime) { $fileType = 'application/gzip' }
                    } elseif ($bytes[0] -eq 0x50 -and $bytes[1] -eq 0x4B -and $bytes[2] -eq 0x03 -and $bytes[3] -eq 0x04) {
                        $fileType = 'Zip archive'
                        if ($mime) { $fileType = 'application/zip' }
                    }
                }
            } catch {}

            if (-not $fileType) {
                # Fallback to extension-based detection
                $extMap = @{
                    '.txt' = @('ASCII text', 'text/plain')
                    '.ps1' = @('PowerShell script', 'text/x-powershell')
                    '.sh' = @('Bourne shell script', 'text/x-sh')
                    '.py' = @('Python script', 'text/x-python')
                    '.js' = @('JavaScript source', 'application/javascript')
                    '.json' = @('JSON data', 'application/json')
                    '.xml' = @('XML document', 'application/xml')
                    '.html' = @('HTML document', 'text/html')
                    '.css' = @('CSS stylesheet', 'text/css')
                    '.md' = @('Markdown source', 'text/markdown')
                    '.csv' = @('CSV data', 'text/csv')
                    '.exe' = @('Windows executable', 'application/x-dosexec')
                    '.dll' = @('Windows dynamic library', 'application/x-dosexec')
                    '.bat' = @('Windows batch script', 'application/x-bat')
                    '.cmd' = @('Windows command script', 'application/x-bat')
                }

                if ($extMap.ContainsKey($ext)) {
                    $fileType = if ($mime) { $extMap[$ext][1] } else { $extMap[$ext][0] }
                } else {
                    # Try to detect text files
                    try {
                        $content = Get-Content $filePath -First 1 -ErrorAction SilentlyContinue
                        if ($content) {
                            $fileType = if ($mime) { 'text/plain' } else { 'ASCII text' }
                        } else {
                            $fileType = if ($mime) { 'application/octet-stream' } else { 'data' }
                        }
                    } catch {
                        $fileType = if ($mime) { 'application/octet-stream' } else { 'data' }
                    }
                }
            }
        }

        if ($brief) {
            Write-Output $fileType
        } else {
            Write-Output "${filePath}: $fileType"
        }
    }
}

function stat {
    param(
        [switch]$c, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($c) { $allArgs += '-c' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'c' = @{ Long = 'format'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: stat [-c FORMAT] FILE... [--help]'
    }

    $format = $parsed.Options['c']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'stat' -Message 'missing operand'
        return
    }

    foreach ($f in $parsed.Positional) {
        $filePath = Convert-BashPath $f

        if (-not (Test-Path $filePath)) {
            Write-BashError -Command 'stat' -Message "cannot access '$filePath'"
            continue
        }

        $item = Get-Item $filePath

        $size = if ($item -is [System.IO.DirectoryInfo]) { 4096 } else { $item.Length }
        $mode = Format-UnixMode $item
        $access = $item.GetAccessControl()
        $owner = $access.Owner.Split('\')[-1]

        $statInfo = @{
            'File' = $item.Name
            'Size' = $size
            'Blocks' = [Math]::Ceiling($size / 512)
            'IO Block' = 4096
            'Device' = '0'
            'Inode' = $item.GetHashCode()
            'Links' = if ($item -is [System.IO.DirectoryInfo]) { 2 } else { 1 }
            'Access' = $item.LastAccessTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff zzz')
            'Modify' = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff zzz')
            'Change' = $item.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff zzz')
            'Birth' = $item.CreationTime.ToString('yyyy-MM-dd HH:mm:ss.fffffff zzz')
            'Uid' = $owner
            'Gid' = $owner
            'Access_mode' = $mode
        }

        if ($format) {
            # Parse format string
            $result = $format
            $result = $result -replace '%n', $statInfo['File']
            $result = $result -replace '%s', $statInfo['Size']
            $result = $result -replace '%b', $statInfo['Blocks']
            $result = $result -replace '%A', $statInfo['Access_mode']
            $result = $result -replace '%U', $statInfo['Uid']
            $result = $result -replace '%G', $statInfo['Gid']
            $result = $result -replace '%y', $statInfo['Modify']
            $result = $result -replace '%z', $statInfo['Change']
            $result = $result -replace '%w', $statInfo['Birth']
            $result = $result -replace '%%', '%'
            Write-Output $result
        } else {
            # Default output format
            Write-Output "  File: '$($item.Name)'"
            Write-Output "  Size: $($statInfo['Size'])       Blocks: $($statInfo['Blocks'])          $($statInfo['Access_mode'])"
            Write-Output "Device: $($statInfo['Device'])     Inode: $($statInfo['Inode'])  Links: $($statInfo['Links'])"
            Write-Output "Access: $($statInfo['Access'])"
            Write-Output "Modify: $($statInfo['Modify'])"
            Write-Output "Change: $($statInfo['Change'])"
            Write-Output " Birth: $($statInfo['Birth'])"
        }
    }
}

function realpath {
    param(
        [switch]$s, [switch]$m, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($s) { $allArgs += '-s' }
    if ($m) { $allArgs += '-m' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        's' = @{ Long = 'strip'; Type = 'switch' }
        'm' = @{ Long = 'missing'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: realpath [-s] [-m] PATH... [--help]'
    }

    $strip = $parsed.Options['s'] -or $parsed.LongOptions['strip']
    $missing = $parsed.Options['m'] -or $parsed.LongOptions['missing']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'realpath' -Message 'missing operand'
        return
    }

    foreach ($p in $parsed.Positional) {
        $path = Convert-BashPath $p

        if (-not (Test-Path $path)) {
            if ($missing) {
                # Resolve without requiring the path to exist
                $absPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
                Write-Output $absPath
            } else {
                Write-BashError -Command 'realpath' -Message "cannot access '$path'"
            }
            continue
        }

        # Get absolute path
        $item = Get-Item $path -ErrorAction SilentlyContinue
        if ($item) {
            $absPath = $item.FullName

            # Strip trailing symlink components if requested
            if ($strip) {
                # Keep only physical path
                $absPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($path)
            }

            Write-Output $absPath
        }
    }
}


