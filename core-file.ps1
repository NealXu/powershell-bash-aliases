function ls {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args)

    $spec = @{
        'a' = @{ Long = 'all'; Type = 'switch' }
        'l' = @{ Long = 'long'; Type = 'switch' }
        'h' = @{ Long = 'human-readable'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $Args -OptionSpec $spec

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
    param([string[]]$Path, [switch]$n, [switch]$Help)
    if ($Help) { return 'Usage: cat [-n] FILE...' }
    $i=1
    foreach ($p in $Path) {
        $p = Convert-BashPath $p
        if (-not (Test-Path $p)) { Write-Error "cat: cannot access '$p'"; continue }
        Get-Content $p | ForEach { if ($n) { Write-Output "{$i} $_"; $i++ } else { Write-Output $_ } }
    }
}
function rm {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Args2, [switch]$Help)
    if ($Help) { return 'Usage: rm [-r] [-f] [-rf] [-fr] FILE...' }
    # Parse combined flags (e.g. -rf, -fr) and separate paths
    $r = $false; $f = $false; $paths = @()
    foreach ($a in $Args2) {
        if ($a -match '^-(.+)$') {
            $flags = $Matches[1]
            if ($flags -match '[^rf]') { Write-Error "rm: invalid option '$a'"; return }
            if ($flags -match 'r') { $r = $true }
            if ($flags -match 'f') { $f = $true }
        } else {
            $paths += $a
        }
    }
    foreach ($p in $paths) {
        $p = Convert-BashPath $p
        $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p)
        if (-not (Test-Path $p)) { if (-not $f) { Write-Error "rm: cannot remove '$p'" }; continue }
        $item = Get-Item $p
        if ($item -is [System.IO.DirectoryInfo] -and -not $r) { Write-Error "rm: '$p' is a directory"; continue }
        if ($item -is [System.IO.DirectoryInfo]) {
            # Use .NET for reliable recursive delete (handles read-only, .git objects)
            foreach ($fi in [System.IO.Directory]::GetFiles($p, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { [System.IO.File]::SetAttributes($fi, 'Normal') } catch {}
            }
            foreach ($fi in [System.IO.Directory]::GetFiles($p, '*', [System.IO.SearchOption]::AllDirectories)) {
                try { [System.IO.File]::Delete($fi) } catch {}
            }
            foreach ($di in ([System.IO.Directory]::GetDirectories($p, '*', [System.IO.SearchOption]::AllDirectories) | Sort-Object { $_.Length } -Descending)) {
                try { [System.IO.Directory]::Delete($di, $false) } catch {}
            }
            try { [System.IO.Directory]::Delete($p, $true) } catch {}
        } else {
            if ($f -and (Get-Item $p).IsReadOnly) { (Get-Item $p).IsReadOnly = $false }
            Remove-Item $p -Force:$f
        }
    }
}
function mkdir {
    param([string[]]$Path, [switch]$p, [switch]$Help)
    if ($Help) { return 'Usage: mkdir [-p] DIR...' }
    foreach ($d in $Path) {
        $d = Convert-BashPath $d
        if ($p) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        else { New-Item -ItemType Directory -Path $d -ErrorAction SilentlyContinue | Out-Null }
    }
}
function cp {
    param([string]$Source, [string]$Dest, [switch]$r, [switch]$f, [switch]$Help)
    if ($Help) { return 'Usage: cp [-r] [-f] SOURCE DEST' }
    $s = Convert-BashPath $Source; $d = Convert-BashPath $Dest
    Copy-Item $s $d -Recurse:$r -Force:$f
}
function mv {
    param([string]$Source, [string]$Dest, [switch]$Help)
    if ($Help) { return 'Usage: mv SOURCE DEST' }
    Move-Item (Convert-BashPath $Source) (Convert-BashPath $Dest) -Force
}
function touch {
    param([string[]]$Path, [switch]$c, [switch]$Help)
    if ($Help) { return 'Usage: touch [-c] FILE...' }
    foreach ($f in $Path) {
        $fp = Convert-BashPath $f
        if (Test-Path $fp) { (Get-Item $fp).LastWriteTime = Get-Date }
        elseif (-not $c) { New-Item -ItemType File -Path $fp | Out-Null }
    }
}
function ll {
    param($Path='.', [switch]$a, [switch]$h, [switch]$Help)
    if ($Help) { return 'Usage: ll [-a] [-h] [PATH] (equivalent to ls -la)' }
    $p = Convert-BashPath $Path
    $items = Get-ChildItem $p -Force:$a | Sort-Object { $_.Name }
    if (-not $a) { $items = $items | Where-Object { -not $_.Name.StartsWith('.') } }
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
        $sz = Format-FileSize $s -HumanReadable:$h
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
}
