function head {
    param(
        [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: head [-n N] [--help] FILE'
    }

    $lines = $parsed.Options['n']
    if (-not $lines) { $lines = 10 }

    if ($parsed.Positional.Count -gt 0) {
        $path = Convert-BashPath $parsed.Positional[0]
        Read-BashFileContent $path | Select-Object -First ([int]$lines)
    }
}
function tail {
    param(
        [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($f) { $allArgs += '-f' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'lines'; Type = 'value' }
        'f' = @{ Long = 'follow'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: tail [-n N] [-f] [--help] FILE'
    }

    $lines = $parsed.Options['n']
    if (-not $lines) { $lines = 10 }
    $follow = $parsed.Options['f'] -or $parsed.LongOptions['follow']

    if ($parsed.Positional.Count -gt 0) {
        $path = Convert-BashPath $parsed.Positional[0]
        if ($follow) { Get-Content $path -Wait -Encoding UTF8 }
        else { Read-BashFileContent $path | Select-Object -Last ([int]$lines) }
    }
}
function wc {
    param(
        [switch]$l, [switch]$w, [switch]$c, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($l) { $allArgs += '-l' }
    if ($w) { $allArgs += '-w' }
    if ($c) { $allArgs += '-c' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'l' = @{ Long = 'lines'; Type = 'switch' }
        'w' = @{ Long = 'words'; Type = 'switch' }
        'c' = @{ Long = 'bytes'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: wc [-l] [-w] [-c] [--help] FILE...'
    }

    $showLines = $parsed.Options['l'] -or $parsed.LongOptions['lines']
    $showWords = $parsed.Options['w'] -or $parsed.LongOptions['words']
    $showBytes = $parsed.Options['c'] -or $parsed.LongOptions['bytes']

    foreach ($f in $parsed.Positional) {
        $fp = Convert-BashPath $f
        $content = Read-BashFileContent $fp
        $lineCount = $content.Count
        $wordCount = ($content | ForEach-Object { $_.Split(' ') } | Measure-Object).Count
        $byteCount = ($content | Measure-Object -Property Length -Sum).Sum

        if (-not $showLines -and -not $showWords -and -not $showBytes) {
            Write-Output "$lineCount $wordCount $byteCount $f"
        } else {
            $out = ''
            if ($showLines) { $out += "$lineCount " }
            if ($showWords) { $out += "$wordCount " }
            if ($showBytes) { $out += "$byteCount " }
            Write-Output "$out$f"
        }
    }
}
function sort {
    param(
        [switch]$n, [switch]$r, [switch]$u, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($n) { $allArgs += '-n' }
    if ($r) { $allArgs += '-r' }
    if ($u) { $allArgs += '-u' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'n' = @{ Long = 'numeric'; Type = 'switch' }
        'r' = @{ Long = 'reverse'; Type = 'switch' }
        'u' = @{ Long = 'unique'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: sort [-n] [-r] [-u] [--help] [FILE]'
    }

    $numeric = $parsed.Options['n'] -or $parsed.LongOptions['numeric']
    $reverse = $parsed.Options['r'] -or $parsed.LongOptions['reverse']
    $unique = $parsed.Options['u'] -or $parsed.LongOptions['unique']

    if ($parsed.Positional.Count -gt 0) {
        $content = Read-BashFileContent (Convert-BashPath $parsed.Positional[0])
    } else {
        $content = $input
    }

    $sorted = if ($numeric) { $content | Sort-Object {[double]$_} } else { $content | Sort-Object }
    if ($reverse) { $sorted = $sorted | Sort-Object -Descending }
    if ($unique) { $sorted = $sorted | Get-Unique }
    $sorted
}
function uniq {
    param(
        [switch]$c, [switch]$d, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($c) { $allArgs += '-c' }
    if ($d) { $allArgs += '-d' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'c' = @{ Long = 'count'; Type = 'switch' }
        'd' = @{ Long = 'repeated'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: uniq [-c] [-d] [--help]'
    }

    $showCount = $parsed.Options['c'] -or $parsed.LongOptions['count']
    $onlyRepeats = $parsed.Options['d'] -or $parsed.LongOptions['repeated']

    $input = $input | Sort-Object
    if ($onlyRepeats) {
        $input | Group-Object | Where-Object { $_.Count -gt 1 } | ForEach-Object { $_.Name }
    }
    elseif ($showCount) {
        $input | Group-Object | ForEach-Object { Write-Output "$($_.Count) $($_.Name)" }
    }
    else {
        $input | Get-Unique
    }
}
function cut {
    param(
        [switch]$d, [switch]$f, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $spec = @{
        'd' = @{ Long = 'delimiter'; Type = 'value'; DefaultValue = ' ' }
        'f' = @{ Long = 'fields'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    # Pair value switches with values from ArgList
    $remaining = @($ArgList)
    $allArgs = @()
    if ($d) { $allArgs += '-d'; if ($remaining.Count -gt 0) { $allArgs += $remaining[0]; $remaining = $remaining[1..($remaining.Count-1)] } }
    if ($f) { $allArgs += '-f'; if ($remaining.Count -gt 0) { $allArgs += $remaining[0]; $remaining = $remaining[1..($remaining.Count-1)] } }
    if ($help) { $allArgs += '-help' }
    $allArgs += $remaining

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: cut -d DELIM -f FIELDS [--help] FILE'
    }

    $delimiter = $parsed.Options['d']
    if (-not $delimiter) { $delimiter = ' ' }
    $fields = $parsed.Options['f']
    if (-not $fields) {
        Write-BashError -Command 'cut' -Message 'missing field specification'
        return
    }

    $fieldList = $fields.Split(',')

    if ($parsed.Positional.Count -gt 0) {
        $content = Read-BashFileContent (Convert-BashPath $parsed.Positional[0])
    } else {
        $content = $input
    }

    foreach ($line in $content) {
        $parts = $line.Split($delimiter)
        $out = ''
        foreach ($fld in $fieldList) {
            $idx = [int]$fld - 1
            if ($idx -ge 0 -and $idx -lt $parts.Count) { $out += $parts[$idx] + $delimiter }
        }
        Write-Output $out.TrimEnd($delimiter)
    }
}
function tr {
    param(
        [switch]$d, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($d) { $allArgs += '-d' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'd' = @{ Long = 'delete'; Type = 'switch' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: tr SET1 SET2 | tr -d SET1 [--help]'
    }

    $deleteMode = $parsed.Options['d'] -or $parsed.LongOptions['delete']

    if ($deleteMode) {
        if ($parsed.Positional.Count -eq 0) {
            Write-BashError -Command 'tr' -Message 'missing SET1'
            return
        }
        $SET1 = $parsed.Positional[0]
        $content = $input
        foreach ($c in $SET1.ToCharArray()) {
            $content = $content -replace $c, ''
        }
        Write-Output $content
    } else {
        if ($parsed.Positional.Count -lt 2) {
            Write-BashError -Command 'tr' -Message 'missing SET2'
            return
        }
        $SET1 = $parsed.Positional[0]
        $SET2 = $parsed.Positional[1]
        $content = $input
        for ($i = 0; $i -lt [Math]::Min($SET1.Length, $SET2.Length); $i++) {
            $content = $content -replace $SET1[$i], $SET2[$i]
        }
        Write-Output $content
    }
}

function sed {
    param(
        [switch]$i, [switch]$n, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($i) { $allArgs += '-i' }
    if ($n) { $allArgs += '-n' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'i' = @{ Long = 'in-place'; Type = 'switch' }
        'n' = @{ Long = 'quiet'; Type = 'switch' }
        'e' = @{ Long = 'expression'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: sed [-i] [-n] [-e SCRIPT] [--help] FILE'
    }

    $inPlace = $parsed.Options['i'] -or $parsed.LongOptions['in-place']
    $quiet = $parsed.Options['n'] -or $parsed.LongOptions['quiet']
    $script = $parsed.Options['e']

    if (-not $script -and $parsed.Positional.Count -gt 0) {
        # First positional argument is the script
        $script = $parsed.Positional[0]
        $parsed.Positional = $parsed.Positional[1..($parsed.Positional.Count - 1)]
    }

    if (-not $script) {
        Write-BashError -Command 'sed' -Message 'missing script'
        return
    }

    if ($parsed.Positional.Count -eq 0) {
        Write-BashError -Command 'sed' -Message 'missing file'
        return
    }

    $filePath = Convert-BashPath $parsed.Positional[0]
    if (-not (Test-Path $filePath)) {
        Write-BashError -Command 'sed' -Message "cannot access '$filePath'"
        return
    }

    $content = Read-BashFileContent $filePath
    $result = @()

    # Parse sed command (basic support for s/pattern/replacement/[flags])
    if ($script -match '^s(.)(.+?)\1(.*?)\1([gi]*)$') {
        $delimiter = $matches[1]
        $pattern = $matches[2]
        $replacement = $matches[3]
        $flags = $matches[4]

        foreach ($line in $content) {
            $newLine = $line

            # Check for global flag
            if ($flags -match 'g') {
                $newLine = $line -replace $pattern, $replacement
            } else {
                # Replace only first occurrence
                if ($line -match $pattern) {
                    $newLine = $line -replace $pattern, $replacement
                }
            }

            # If not quiet mode, output the line
            if (-not $quiet) {
                $result += $newLine
            }

            # Track if line was modified
            if ($inPlace) {
                $result[-1] = $newLine
            }
        }

        if ($inPlace) {
            $result | Set-Content $filePath -Encoding UTF8
        } else {
            $result
        }
    } else {
        # Unsupported sed command
        Write-BashError -Command 'sed' -Message "unsupported script: $script"
        return
    }
}

function awk {
    param(
        [switch]$F, [switch]$v, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($F) { $allArgs += '-F' }
    if ($v) { $allArgs += '-v' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'F' = @{ Long = 'field-separator'; Type = 'value'; DefaultValue = ' ' }
        'v' = @{ Long = 'assign'; Type = 'value' }
        'file' = @{ Long = 'script-file'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: awk [-F SEP] [-v VAR=VAL] "PROGRAM" [FILE] [--help]'
    }

    $separator = $parsed.Options['F']
    if (-not $separator) { $separator = ' ' }

    # Get the program/script
    $program = $null
    $files = @()

    # First positional arg is the program if it looks like a script
    if ($parsed.Positional.Count -gt 0) {
        $firstArg = $parsed.Positional[0]
        # If it contains { or looks like a pattern-action, it's the program
        if ($firstArg -match '[\{\}]' -or $firstArg -match '^\$' -or $firstArg -match 'BEGIN|END|print') {
            $program = $firstArg
            $files = $parsed.Positional[1..($parsed.Positional.Count - 1)]
        } else {
            # It's a file, program was passed via -f
            $files = $parsed.Positional
        }
    }

    if (-not $program -and -not $parsed.Options['file']) {
        Write-BashError -Command 'awk' -Message 'missing program'
        return
    }

    # If no files, read from pipeline/input
    $content = @()
    if ($files.Count -gt 0) {
        foreach ($f in $files) {
            $filePath = Convert-BashPath $f
            if (Test-Path $filePath) {
                $content += Read-BashFileContent $filePath
            } else {
                Write-BashError -Command 'awk' -Message "cannot access '$filePath'"
            }
        }
    } else {
        $content = @($input)
    }

    # Simplified awk implementation
    # Support basic patterns: /pattern/, BEGIN, END, NR, NF, $N, print
    $result = @()
    $lineNum = 0

    # Parse variable assignments from -v
    $variables = @{}
    if ($parsed.Options['v']) {
        $parsed.Options['v'] -split ',' | ForEach-Object {
            if ($_ -match '^(\w+)=(.+)$') {
                $variables[$matches[1]] = $matches[2]
            }
        }
    }

    foreach ($line in $content) {
        $lineNum++
        $fields = $line.Split($separator)
        $NF = $fields.Count
        $NR = $lineNum

        # Evaluate the program for each line
        $output = $line

        # Simple pattern matching and print support
        if ($program -match '/(.+)/\s*\{\s*print\s*(.*?)\s*\}') {
            $pattern = $matches[1]
            $printExpr = $matches[2]
            if ($line -match $pattern) {
                if ($printExpr -match '\$(\d+)') {
                    $fieldIdx = [int]$matches[1] - 1
                    if ($fieldIdx -ge 0 -and $fieldIdx -lt $fields.Count) {
                        $output = $fields[$fieldIdx]
                    }
                } elseif ($printExpr -eq '$0' -or $printExpr -eq '') {
                    $output = $line
                } else {
                    $output = $printExpr
                }
                $result += $output
            }
        } elseif ($program -match 'print\s+\$(\d+)') {
            # Simple print field
            $fieldIdx = [int]$matches[1] - 1
            if ($fieldIdx -ge 0 -and $fieldIdx -lt $fields.Count) {
                $result += $fields[$fieldIdx]
            }
        } elseif ($program -match 'print') {
            # Default print $0
            $result += $line
        } elseif ($program -match '\{(.+)\}') {
            # Generic block
            $block = $matches[1]
            if ($block -match 'print\s+(.+)') {
                $printContent = $matches[1]
                # Substitute $N with field values
                for ($i = $fields.Count; $i -ge 1; $i--) {
                    $printContent = $printContent -replace "\$$i", $fields[$i - 1]
                }
                $printContent = $printContent -replace '\$0', $line
                $printContent = $printContent -replace '\$NF', $NF
                $printContent = $printContent -replace '\$NR', $NR
                $result += $printContent
            }
        } else {
            # Just print the line
            $result += $line
        }
    }

    $result
}

function patch {
    param(
        [switch]$p, [switch]$R, [switch]$dry_run, [switch]$help,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$ArgList
    )

    $allArgs = @()
    if ($p) { $allArgs += '-p' }
    if ($R) { $allArgs += '-R' }
    if ($dry_run) { $allArgs += '--dry-run' }
    if ($help) { $allArgs += '-help' }
    $allArgs += $ArgList

    $spec = @{
        'p' = @{ Long = 'strip'; Type = 'value'; DefaultValue = '0' }
        'R' = @{ Long = 'reverse'; Type = 'switch' }
        'dry-run' = @{ Long = 'dry-run'; Type = 'switch' }
        'o' = @{ Long = 'output'; Type = 'value' }
        'i' = @{ Long = 'input'; Type = 'value' }
        'help' = @{ Long = 'help'; Type = 'switch' }
    }

    $parsed = Parse-BashArgs -ArgsArray $allArgs -OptionSpec $spec

    if ($parsed.Options['help']) {
        return 'Usage: patch [-p NUM] [-R] [--dry-run] [-i PATCH] [FILE] [--help]'
    }

    $stripLevel = [int]$parsed.Options['p']
    $reverse = $parsed.Options['R'] -or $parsed.LongOptions['reverse']
    $dryRun = $parsed.Options['dry-run'] -or $parsed.LongOptions['dry-run']
    $patchFile = $parsed.Options['i']
    $outputFile = $parsed.Options['o']

    # Determine target file and patch file
    $targetFile = $null

    if ($patchFile) {
        $patchPath = Convert-BashPath $patchFile
        if (-not (Test-Path $patchPath)) {
            Write-BashError -Command 'patch' -Message "cannot access patch file '$patchPath'"
            return
        }
        $patchContent = Read-BashFileContent $patchPath
    } elseif ($parsed.Positional.Count -gt 0) {
        # First positional is patch file
        $patchPath = Convert-BashPath $parsed.Positional[0]
        if (Test-Path $patchPath) {
            $patchContent = Read-BashFileContent $patchPath
        } else {
            Write-BashError -Command 'patch' -Message "cannot access '$patchPath'"
            return
        }
    } else {
        Write-BashError -Command 'patch' -Message 'missing patch file'
        return
    }

    # Parse unified diff format
    # Format:
    # --- a/file
    # +++ b/file
    # @@ -l,s +l,s @@ context
    # lines starting with - are removed
    # lines starting with + are added
    # lines starting with space are context

    $currentFile = $null
    $hunks = @()
    $currentHunk = $null

    foreach ($line in $patchContent) {
        if ($line -match '^---\s+(.+)') {
            # Old file
            $oldFile = $matches[1]
            # Strip a/ prefix if present
            if ($stripLevel -gt 0 -and $oldFile -match '^[ab]/') {
                $oldFile = $oldFile.Substring(2)
            }
        } elseif ($line -match '^\+\+\+\s+(.+)') {
            # New file (target)
            $newFile = $matches[1]
            if ($stripLevel -gt 0 -and $newFile -match '^[ab]/') {
                $newFile = $newFile.Substring(2)
            }
            if (-not $targetFile) {
                $targetFile = $newFile
            }
        } elseif ($line -match '^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@') {
            # Hunk header
            if ($currentHunk) {
                $hunks += $currentHunk
            }
            $currentHunk = @{
                OldStart = [int]$matches[1]
                OldCount = if ($matches[2]) { [int]$matches[2] } else { 1 }
                NewStart = [int]$matches[3]
                NewCount = if ($matches[4]) { [int]$matches[4] } else { 1 }
                Lines = @()
            }
        } elseif ($currentHunk) {
            # Hunk content
            $currentHunk.Lines += $line
        }
    }

    if ($currentHunk) {
        $hunks += $currentHunk
    }

    if ($hunks.Count -eq 0) {
        Write-BashError -Command 'patch' -Message 'no hunks found in patch'
        return
    }

    if (-not $targetFile) {
        Write-BashError -Command 'patch' -Message 'could not determine target file from patch'
        return
    }

    $targetPath = Convert-BashPath $targetFile
    if (-not (Test-Path $targetPath)) {
        Write-BashError -Command 'patch' -Message "cannot access '$targetPath'"
        return
    }

    $fileContent = Read-BashFileContent $targetPath

    if ($dryRun) {
        Write-Output "Dry run: would patch $targetFile"
        Write-Output "Found $($hunks.Count) hunk(s)"
        return
    }

    # Apply hunks (simplified - just handle basic cases)
    $result = @()
    $lineIdx = 0
    $hunkIdx = 0

    foreach ($hunk in $hunks) {
        # Add lines before this hunk
        $startLine = $hunk.NewStart - 1
        while ($lineIdx -lt $startLine -and $lineIdx -lt $fileContent.Count) {
            $result += $fileContent[$lineIdx]
            $lineIdx++
        }

        # Process hunk lines
        foreach ($hunkLine in $hunk.Lines) {
            if ($hunkLine -match '^\+(.*)') {
                # Added line
                if (-not $reverse) {
                    $result += $matches[1]
                }
            } elseif ($hunkLine -match '^-(.*)') {
                # Removed line
                if ($reverse) {
                    $result += $matches[1]
                } else {
                    $lineIdx++  # Skip this line in original
                }
            } elseif ($hunkLine -match '^\s(.*)') {
                # Context line
                $result += $matches[1]
                $lineIdx++
            }
        }
    }

    # Add remaining lines
    while ($lineIdx -lt $fileContent.Count) {
        $result += $fileContent[$lineIdx]
        $lineIdx++
    }

    if ($outputFile) {
        $result | Set-Content (Convert-BashPath $outputFile) -Encoding UTF8
        Write-Output "Patched content written to $outputFile"
    } else {
        $result | Set-Content $targetPath -Encoding UTF8
        Write-Output "Patched $targetFile"
    }
}
