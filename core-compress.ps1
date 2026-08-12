# core-compress.ps1
# Compression commands module

function tar {
    param(
        [switch]$c, [switch]$x, [switch]$t,
        [switch]$v, [switch]$z, [switch]$j,
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($c) { $allArgs += '-c' }
    if ($x) { $allArgs += '-x' }
    if ($t) { $allArgs += '-t' }
    if ($v) { $allArgs += '-v' }
    if ($z) { $allArgs += '-z' }
    if ($j) { $allArgs += '-j' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'c' = @{ Long = 'create'; Type = 'switch' }
        'x' = @{ Long = 'extract'; Type = 'switch' }
        't' = @{ Long = 'list'; Type = 'switch' }
        'v' = @{ Long = 'verbose'; Type = 'switch' }
        'z' = @{ Long = 'gzip'; Type = 'switch' }
        'j' = @{ Long = 'bzip2'; Type = 'switch' }
        'f' = @{ Long = 'file'; Type = 'value' }
        'C' = @{ Long = 'directory'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: tar [-c|-x|-t] [-v] [-z|-j] -f ARCHIVE [-C DIR] [FILE]... [--help]'
    }

    $create = $parsed.Options['c'] -or $parsed.LongOptions['create']
    $extract = $parsed.Options['x'] -or $parsed.LongOptions['extract']
    $list = $parsed.Options['t'] -or $parsed.LongOptions['list']
    $verbose = $parsed.Options['v'] -or $parsed.LongOptions['verbose']
    $gzip = $parsed.Options['z'] -or $parsed.LongOptions['gzip']
    $bzip2 = $parsed.Options['j'] -or $parsed.LongOptions['bzip2']
    $archiveFile = $parsed.Options['f']
    $targetDir = if ($parsed.Options['C']) { Convert-BashPath $parsed.Options['C'] } else { $PWD }

    if (-not $archiveFile) {
        Write-BashError -Command 'tar' -Message 'missing archive file (-f)'
        return
    }

    $archivePath = Convert-BashPath $archiveFile

    # On Windows, use native tar (available on Windows 10+)
    if ($create) {
        $files = $parsed.Positional
        if ($files.Count -eq 0) {
            Write-BashError -Command 'tar' -Message 'missing files to archive'
            return
        }

        if (Get-Command 'tar' -ErrorAction SilentlyContinue) {
            if ($gzip) {
                $nativeArgs = @('-czf', $archivePath) + $files
            } else {
                $nativeArgs = @('-cf', $archivePath) + $files
            }
            & tar $nativeArgs
        } else {
            Write-BashError -Command 'tar' -Message 'native tar command not found'
        }
    } elseif ($extract) {
        if (-not (Test-Path $archivePath)) {
            Write-BashError -Command 'tar' -Message "cannot access '$archivePath'"
            return
        }

        if (Get-Command 'tar' -ErrorAction SilentlyContinue) {
            Push-Location $targetDir
            try {
                if ($gzip) {
                    $nativeArgs = @('-xzf', $archivePath)
                } else {
                    $nativeArgs = @('-xf', $archivePath)
                }
                & tar $nativeArgs
            } finally {
                Pop-Location
            }
        } else {
            Write-BashError -Command 'tar' -Message 'native tar command not found'
        }
    } elseif ($list) {
        if (-not (Test-Path $archivePath)) {
            Write-BashError -Command 'tar' -Message "cannot access '$archivePath'"
            return
        }

        if (Get-Command 'tar' -ErrorAction SilentlyContinue) {
            $nativeArgs = @('-tf', $archivePath)
            & tar $nativeArgs
        } else {
            Write-BashError -Command 'tar' -Message 'native tar command not found'
        }
    } else {
        Write-BashError -Command 'tar' -Message 'missing operation (-c, -x, or -t)'
    }
}

function zip {
    param(
        [switch]$r,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($r) { $allArgs += '-r' }
    $allArgs += $ArgList

    $spec = @{
        'r' = @{ Long = 'recurse'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: zip [-r] ARCHIVE PATH... [--help]'
    }

    $recurse = $parsed.Options['r'] -or $parsed.LongOptions['recurse']

    if ($parsed.Positional.Count -lt 2) {
        Write-BashError -Command 'zip' -Message 'missing archive name or files'
        return
    }

    $archiveName = Convert-BashPath $parsed.Positional[0]
    if (-not $archiveName.EndsWith('.zip')) {
        $archiveName += '.zip'
    }

    $paths = $parsed.Positional[1..($parsed.Positional.Count - 1)] | ForEach-Object { Convert-BashPath $_ }

    $validPaths = @()
    foreach ($p in $paths) {
        if (Test-Path $p) {
            $validPaths += $p
        } else {
            Write-BashError -Command 'zip' -Message "cannot access '$p'"
        }
    }

    if ($validPaths.Count -eq 0) {
        Write-BashError -Command 'zip' -Message 'no valid files to compress'
        return
    }

    # Use Compress-Archive
    try {
        if ($validPaths.Count -eq 1) {
            $item = Get-Item $validPaths[0]
            if ($item -is [System.IO.DirectoryInfo]) {
                if ($recurse) {
                    Compress-Archive -Path "$($validPaths[0])\*" -DestinationPath $archiveName -Force
                } else {
                    Compress-Archive -Path $validPaths[0] -DestinationPath $archiveName -Force
                }
            } else {
                Compress-Archive -Path $validPaths[0] -DestinationPath $archiveName -Force
            }
        } else {
            Compress-Archive -Path $validPaths -DestinationPath $archiveName -Force
        }
    } catch {
        Write-BashError -Command 'zip' -Message $_.Exception.Message
    }
}

function unzip {
    param(
        [switch]$l, [switch]$o,
        [string]$d,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($l) { $allArgs += '-l' }
    if ($o) { $allArgs += '-o' }
    if ($d) { $allArgs += '-d'; $allArgs += $d }
    $allArgs += $ArgList

    $spec = @{
        'l' = @{ Long = 'list'; Type = 'switch' }
        'o' = @{ Long = 'overwrite'; Type = 'switch' }
        'd' = @{ Long = 'directory'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: unzip [-l] [-o] [-d DIR] ARCHIVE [--help]'
    }

    $listOnly = $parsed.Options['l'] -or $parsed.LongOptions['list']
    $overwrite = $parsed.Options['o'] -or $parsed.LongOptions['overwrite']
    $targetDir = if ($parsed.Options['d']) { Convert-BashPath $parsed.Options['d'] } else { $PWD }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'unzip' -Message 'missing archive'
        return
    }

    $archivePath = Convert-BashPath $parsed.Positional[0]

    if (-not (Test-Path $archivePath)) {
        Write-BashError -Command 'unzip' -Message "cannot access '$archivePath'"
        return
    }

    if ($listOnly) {
        # List archive contents
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
            foreach ($entry in $zip.Entries) {
                $size = $entry.Length
                $name = $entry.FullName
                Write-Output "$size  $name"
            }
            $zip.Dispose()
        } catch {
            Write-BashError -Command 'unzip' -Message $_.Exception.Message
        }
    } else {
        # Extract archive
        try {
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }

            Add-Type -AssemblyName System.IO.Compression.FileSystem
            if ($overwrite) {
                # Extract with overwrite
                $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
                foreach ($entry in $zip.Entries) {
                    $destPath = Join-Path $targetDir $entry.FullName
                    $destDir = [System.IO.Path]::GetDirectoryName($destPath)
                    if (-not (Test-Path $destDir)) {
                        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                    }
                    if ($entry.Name -ne '') {
                        $entry.ExtractToFile($destPath, $true)
                    }
                }
                $zip.Dispose()
            } else {
                [System.IO.Compression.ZipFile]::ExtractToDirectory($archivePath, $targetDir)
            }
        } catch {
            Write-BashError -Command 'unzip' -Message $_.Exception.Message
        }
    }
}

function gzip {
    param(
        [switch]$d, [switch]$k, [switch]$v,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($d) { $allArgs += '-d' }
    if ($k) { $allArgs += '-k' }
    if ($v) { $allArgs += '-v' }
    $allArgs += $ArgList

    $spec = @{
        'd' = @{ Long = 'decompress'; Type = 'switch' }
        'k' = @{ Long = 'keep'; Type = 'switch' }
        'v' = @{ Long = 'verbose'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: gzip [-d] [-k] [-v] FILE... [--help]'
    }

    $decompress = $parsed.Options['d'] -or $parsed.LongOptions['decompress']
    $keep = $parsed.Options['k'] -or $parsed.LongOptions['keep']
    $verbose = $parsed.Options['v'] -or $parsed.LongOptions['verbose']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'gzip' -Message 'missing file'
        return
    }

    foreach ($file in $parsed.Positional) {
        $filePath = Convert-BashPath $file

        if (-not (Test-Path $filePath)) {
            Write-BashError -Command 'gzip' -Message "cannot access '$filePath'"
            continue
        }

        try {
            if ($decompress) {
                # Decompress .gz file
                $outFile = $filePath -replace '\.gz$', ''
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $inputStream = [System.IO.File]::OpenRead($filePath)
                $outputStream = [System.IO.File]::Create($outFile)
                $gzipStream = New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
                $gzipStream.CopyTo($outputStream)
                $gzipStream.Close()
                $outputStream.Close()
                $inputStream.Close()

                if (-not $keep) {
                    Remove-Item $filePath -Force
                }

                if ($verbose) {
                    Write-Output "$filePath -> $outFile"
                }
            } else {
                # Compress file
                $outFile = $filePath + '.gz'
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                $inputStream = [System.IO.File]::OpenRead($filePath)
                $outputStream = [System.IO.File]::Create($outFile)
                $gzipStream = New-Object System.IO.Compression.GZipStream($outputStream, [System.IO.Compression.CompressionLevel]::Optimal)
                $inputStream.CopyTo($gzipStream)
                $gzipStream.Close()
                $outputStream.Close()
                $inputStream.Close()

                if (-not $keep) {
                    Remove-Item $filePath -Force
                }

                if ($verbose) {
                    Write-Output "$filePath -> $outFile"
                }
            }
        } catch {
            Write-BashError -Command 'gzip' -Message $_.Exception.Message
        }
    }
}

function gunzip {
    param(
        [switch]$k, [switch]$v,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($k) { $allArgs += '-k' }
    if ($v) { $allArgs += '-v' }
    $allArgs += $ArgList

    $spec = @{
        'k' = @{ Long = 'keep'; Type = 'switch' }
        'v' = @{ Long = 'verbose'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: gunzip [-k] [-v] FILE... [--help]'
    }

    $keep = $parsed.Options['k'] -or $parsed.LongOptions['keep']
    $verbose = $parsed.Options['v'] -or $parsed.LongOptions['verbose']

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'gunzip' -Message 'missing file'
        return
    }

    foreach ($file in $parsed.Positional) {
        $filePath = Convert-BashPath $file

        if (-not (Test-Path $filePath)) {
            Write-BashError -Command 'gunzip' -Message "cannot access '$filePath'"
            continue
        }

        try {
            $outFile = $filePath -replace '\.gz$', ''
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $inputStream = [System.IO.File]::OpenRead($filePath)
            $outputStream = [System.IO.File]::Create($outFile)
            $gzipStream = New-Object System.IO.Compression.GZipStream($inputStream, [System.IO.Compression.CompressionMode]::Decompress)
            $gzipStream.CopyTo($outputStream)
            $gzipStream.Close()
            $outputStream.Close()
            $inputStream.Close()

            if (-not $keep) {
                Remove-Item $filePath -Force
            }

            if ($verbose) {
                Write-Output "$filePath -> $outFile"
            }
        } catch {
            Write-BashError -Command 'gunzip' -Message $_.Exception.Message
        }
    }
}

function bzip2 {
    param(
        [switch]$d, [switch]$k, [switch]$z, [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($d) { $allArgs += '-d' }
    if ($k) { $allArgs += '-k' }
    if ($z) { $allArgs += '-z' }
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'd' = @{ Long = 'decompress'; Type = 'switch' }
        'k' = @{ Long = 'keep'; Type = 'switch' }
        'z' = @{ Long = 'compress'; Type = 'switch' }
        'f' = @{ Long = 'force'; Type = 'switch' }
        'v' = @{ Long = 'verbose'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: bzip2 [-d|-z] [-k] [-f] FILE... [--help]'
    }

    $decompress = $parsed.Options['d'] -or $parsed.LongOptions['decompress']
    $compress = $parsed.Options['z'] -or $parsed.LongOptions['compress']
    $keep = $parsed.Options['k'] -or $parsed.LongOptions['keep']
    $force = $parsed.Options['f'] -or $parsed.LongOptions['force']
    $verbose = $parsed.Options['v'] -or $parsed.LongOptions['verbose']

    # Check if bzip2 is available (via WSL or Git Bash)
    $bzip2Cmd = Get-Command bzip2 -ErrorAction SilentlyContinue
    if (-not $bzip2Cmd) {
        Write-BashError -Command 'bzip2' -Message 'bzip2 command not found. Install via WSL or Git Bash.'
        return
    }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'bzip2' -Message 'missing file argument'
        return
    }

    foreach ($file in $parsed.Positional) {
        $path = Convert-BashPath $file

        if (-not (Test-Path $path)) {
            Write-BashError -Command 'bzip2' -Message "cannot access '$path'"
            continue
        }

        if ($decompress) {
            # Decompress .bz2 file
            $dest = $path -replace '\.bz2$', ''
            $bzipArgs = @('-d')
            if ($keep) { $bzipArgs += '-k' }
            if ($force) { $bzipArgs += '-f' }
            $bzipArgs += $path
            & bzip2 $bzipArgs
            if ($verbose) { Write-Output "Decompressed: $path -> $dest" }
        } else {
            # Compress to .bz2 (default behavior)
            $dest = "$path.bz2"
            $bzipArgs = @('-z')
            if ($keep) { $bzipArgs += '-k' }
            if ($force) { $bzipArgs += '-f' }
            $bzipArgs += $path
            & bzip2 $bzipArgs
            if ($verbose) { Write-Output "Compressed: $path -> $dest" }
        }
    }
}

function bunzip2 {
    param(
        [switch]$k, [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($k) { $allArgs += '-k' }
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'k' = @{ Long = 'keep'; Type = 'switch' }
        'f' = @{ Long = 'force'; Type = 'switch' }
        'v' = @{ Long = 'verbose'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: bunzip2 [-k] [-f] FILE... [--help]'
    }

    $keep = $parsed.Options['k'] -or $parsed.LongOptions['keep']
    $force = $parsed.Options['f'] -or $parsed.LongOptions['force']
    $verbose = $parsed.Options['v'] -or $parsed.LongOptions['verbose']

    # Check if bzip2 is available (via WSL or Git Bash)
    $bzip2Cmd = Get-Command bzip2 -ErrorAction SilentlyContinue
    if (-not $bzip2Cmd) {
        Write-BashError -Command 'bunzip2' -Message 'bzip2 command not found. Install via WSL or Git Bash.'
        return
    }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'bunzip2' -Message 'missing file argument'
        return
    }

    foreach ($file in $parsed.Positional) {
        $path = Convert-BashPath $file

        if (-not (Test-Path $path)) {
            Write-BashError -Command 'bunzip2' -Message "cannot access '$path'"
            continue
        }

        $dest = $path -replace '\.bz2$', ''

        $bzipArgs = @('-d')
        if ($keep) { $bzipArgs += '-k' }
        if ($force) { $bzipArgs += '-f' }
        $bzipArgs += $path
        & bzip2 $bzipArgs
        if ($verbose) { Write-Output "Decompressed: $path -> $dest" }
    }
}