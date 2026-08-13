# tests\test-core-file-coverage.ps1 (compatible with Pester 3.4.0 / Windows PowerShell 5.1)
# Coverage tests for previously-uncovered branches in core-file.ps1:
#   file (magic numbers, extension map, dir/mime, data fallback, error paths)
#   diff (-u unified, standard markers, -r recursive dirs, silent identical, errors)
#   ln (hard links, junction fallback, force overwrite, error paths)
#   ll / ls (flags -a -l -h, multiple paths, default path, colors)
#   rm (recursive .NET delete, read-only, error paths)
#   stat (format tokens, directory, error paths)
#   realpath (-s, multiple paths, error paths)
#
# Conventions:
#   - ASCII only (no non-ASCII literals)
#   - All inputs created under $env:TEMP and removed in AfterAll
#   - Function refs invoked via & $script:<name>Func to bypass aliases
#   - In Pester 3.4, script-scoped temp paths must be assigned inside
#     BeforeAll (Describe-body $script: assignments are not visible there).

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Force remove conflicting aliases BEFORE importing module
Remove-Item "Global:Alias:ls" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:cat" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:rm" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:cp" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:mv" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:diff" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:ln" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:file" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:stat" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:realpath" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:ll" -Force -ErrorAction SilentlyContinue

# Import module to get properly exported functions
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Get function references to bypass PowerShell alias priority
$script:lsFunc = Get-Command ls -CommandType Function -ErrorAction SilentlyContinue
$script:rmFunc = Get-Command rm -CommandType Function -ErrorAction SilentlyContinue
$script:diffFunc = Get-Command diff -CommandType Function -ErrorAction SilentlyContinue
$script:lnFunc = Get-Command ln -CommandType Function -ErrorAction SilentlyContinue
$script:fileFunc = Get-Command file -CommandType Function -ErrorAction SilentlyContinue
$script:statFunc = Get-Command stat -CommandType Function -ErrorAction SilentlyContinue
$script:realpathFunc = Get-Command realpath -CommandType Function -ErrorAction SilentlyContinue
$script:llFunc = Get-Command ll -CommandType Function -ErrorAction SilentlyContinue

# Script-scope test data: visible to BeforeAll (which does not see Describe-body
# variables in Pester 3.4) and to It -TestCases.
$script:extCases = @(
    @{ FileName = 'file.txt';    Expected = 'ASCII text' }
    @{ FileName = 'script.ps1';  Expected = 'PowerShell script' }
    @{ FileName = 'script.sh';   Expected = 'Bourne shell script' }
    @{ FileName = 'script.py';   Expected = 'Python script' }
    @{ FileName = 'app.js';      Expected = 'JavaScript source' }
    @{ FileName = 'data.json';   Expected = 'JSON data' }
    @{ FileName = 'doc.xml';     Expected = 'XML document' }
    @{ FileName = 'page.html';   Expected = 'HTML document' }
    @{ FileName = 'style.css';   Expected = 'CSS stylesheet' }
    @{ FileName = 'readme.md';   Expected = 'Markdown source' }
    @{ FileName = 'data.csv';    Expected = 'CSV data' }
    @{ FileName = 'app.exe';     Expected = 'Windows executable' }
    @{ FileName = 'lib.dll';     Expected = 'Windows dynamic library' }
    @{ FileName = 'run.bat';     Expected = 'Windows batch script' }
    @{ FileName = 'run.cmd';     Expected = 'Windows command script' }
)

$script:magicCases = @(
    @{ FileName = 'elf.bin';   Bytes = @(0x7F,0x45,0x4C,0x46,0x02,0x01,0x01,0x00); Expected = 'ELF executable';        Mime = 'application/x-executable' }
    @{ FileName = 'pe.exe';    Bytes = @(0x4D,0x5A,0x90,0x00,0x03,0x00,0x00,0x00); Expected = 'PE32 executable (Windows)'; Mime = 'application/x-dosexec' }
    @{ FileName = 'doc.pdf';   Bytes = @(0x25,0x50,0x44,0x46,0x2D,0x31,0x2E,0x34); Expected = 'PDF document';          Mime = 'application/pdf' }
    @{ FileName = 'img.png';   Bytes = @(0x89,0x50,0x4E,0x47,0x0D,0x0A,0x1A,0x0A); Expected = 'PNG image';            Mime = 'image/png' }
    @{ FileName = 'img.jpg';   Bytes = @(0xFF,0xD8,0xFF,0xE0,0x00,0x10,0x4A,0x46); Expected = 'JPEG image';           Mime = 'image/jpeg' }
    @{ FileName = 'img.gif';   Bytes = @(0x47,0x49,0x46,0x38,0x39,0x61,0x00,0x00); Expected = 'GIF image';            Mime = 'image/gif' }
    @{ FileName = 'data.gz';   Bytes = @(0x1F,0x8B,0x08,0x00,0x00,0x00,0x00,0x00); Expected = 'gzip compressed';      Mime = 'application/gzip' }
    @{ FileName = 'data.zip';  Bytes = @(0x50,0x4B,0x03,0x04,0x14,0x00,0x00,0x00); Expected = 'Zip archive';          Mime = 'application/zip' }
)

Describe "file command coverage" {
    BeforeAll {
        $script:fileRoot = Join-Path $env:TEMP ("pba-cov-file-" + $PID)
        $script:fileDir = Join-Path $script:fileRoot "adirectory"
        New-Item -ItemType Directory -Path $script:fileRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:fileDir -Force | Out-Null

        # Extension-mapped text files (content avoids all magic numbers)
        foreach ($c in $script:extCases) {
            Set-Content -Path (Join-Path $script:fileRoot $c.FileName) -Value "sample content" -Encoding UTF8
        }
        # Magic-number binary files
        foreach ($c in $script:magicCases) {
            [System.IO.File]::WriteAllBytes((Join-Path $script:fileRoot $c.FileName), [byte[]]$c.Bytes)
        }
        # Unknown-extension files for fallback detection
        Set-Content -Path (Join-Path $script:fileRoot "sample.bin") -Value "plain text bytes" -Encoding UTF8
        New-Item -ItemType File -Path (Join-Path $script:fileRoot "empty.bin") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:fileRoot "empty.txt") -Force | Out-Null
    }
    AfterAll {
        Remove-Item $script:fileRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "reports a directory type" {
        $result = & $script:fileFunc $script:fileDir
        @($result | Where-Object { $_ -match 'directory' }).Count | Should Be 1
    }

    It "reports MIME type for a directory with -i" {
        $result = & $script:fileFunc -i $script:fileDir
        @($result | Where-Object { $_ -match 'inode/directory' }).Count | Should Be 1
    }

    It "detects <FileName> by extension as <Expected>" -TestCases $script:extCases {
        param($FileName, $Expected)
        $path = Join-Path $script:fileRoot $FileName
        $result = & $script:fileFunc -b $path
        @($result | Where-Object { $_ -match [regex]::Escape($Expected) }).Count | Should Be 1
    }

    It "detects <FileName> by magic number as <Expected>" -TestCases $script:magicCases {
        param($FileName, $Expected)
        $path = Join-Path $script:fileRoot $FileName
        $result = & $script:fileFunc -b $path
        @($result | Where-Object { $_ -match [regex]::Escape($Expected) }).Count | Should Be 1
    }

    It "reports MIME type <Mime> for magic file <FileName> with -i" -TestCases $script:magicCases {
        param($FileName, $Mime)
        $path = Join-Path $script:fileRoot $FileName
        $result = & $script:fileFunc -b -i $path
        @($result | Where-Object { $_ -match [regex]::Escape($Mime) }).Count | Should Be 1
    }

    It "reports MIME type by extension with -i" {
        $result = & $script:fileFunc -b -i (Join-Path $script:fileRoot "script.ps1")
        @($result | Where-Object { $_ -match 'text/x-powershell' }).Count | Should Be 1
    }

    It "detects unknown extension with text content as ASCII text" {
        $result = & $script:fileFunc -b (Join-Path $script:fileRoot "sample.bin")
        @($result | Where-Object { $_ -match 'ASCII text' }).Count | Should Be 1
    }

    It "reports empty unknown-extension file as data" {
        $result = & $script:fileFunc -b (Join-Path $script:fileRoot "empty.bin")
        @($result | Where-Object { $_ -match 'data' }).Count | Should Be 1
    }

    It "reports empty known-extension file via extension map" {
        $result = & $script:fileFunc -b (Join-Path $script:fileRoot "empty.txt")
        @($result | Where-Object { $_ -match 'ASCII text' }).Count | Should Be 1
    }

    It "warns when called without an operand" {
        # Explicit empty ArgList avoids the $null -> '' remaining-args coercion
        # that otherwise turns a no-argument call into an empty-string path.
        $out = & $script:fileFunc -ArgList @() 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns on a nonexistent file" {
        $out = & $script:fileFunc (Join-Path $script:fileRoot "ghost.txt") 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    # Pester 3.4.0 has no Set-ItResult; the only "Skipped" result path is the
    # It -Skip switch, decided at invocation time. Probe symlink capability
    # here (Describe body runs top-to-bottom) and skip when not permitted.
    $script:symlinkPermitted = $false
    $script:symlinkLink = Join-Path $script:fileRoot "filelink.lnk"
    $script:symlinkTarget = Join-Path $script:fileRoot "file.txt"
    try {
        New-Item -ItemType SymbolicLink -Path $script:symlinkLink -Target $script:symlinkTarget -ErrorAction Stop | Out-Null
        $script:symlinkPermitted = $true
    } catch {
        $script:symlinkPermitted = $false
    }

    It "reports a file symbolic link when creation is permitted" -Skip:(-not $script:symlinkPermitted) {
        $result = & $script:fileFunc $script:symlinkLink
        @($result | Where-Object { $_ -match 'symbolic link' }).Count | Should Be 1
    }

    It "shows usage with short -help" {
        $result = & $script:fileFunc -help
        (@($result -join '') -match 'Usage: file') | Should Be $true
    }
}

Describe "diff command coverage" {
    BeforeAll {
        $script:diffRoot = Join-Path $env:TEMP ("pba-cov-diff-" + $PID)
        $script:diffFile1 = Join-Path $script:diffRoot "file1.txt"
        $script:diffFile2 = Join-Path $script:diffRoot "file2.txt"
        $script:diffFile3 = Join-Path $script:diffRoot "file3.txt"
        $script:diffDir1 = Join-Path $script:diffRoot "dir1"
        $script:diffDir2 = Join-Path $script:diffRoot "dir2"
        New-Item -ItemType Directory -Path $script:diffRoot -Force | Out-Null
        Set-Content -Path $script:diffFile1 -Value "line1", "line2", "line3" -Encoding UTF8
        Set-Content -Path $script:diffFile2 -Value "line1", "line2-modified", "line3" -Encoding UTF8
        Copy-Item $script:diffFile1 $script:diffFile3

        New-Item -ItemType Directory -Path $script:diffDir1 -Force | Out-Null
        New-Item -ItemType Directory -Path $script:diffDir2 -Force | Out-Null
        Set-Content -Path (Join-Path $script:diffDir1 "a.txt") -Value "x" -Encoding UTF8
        Set-Content -Path (Join-Path $script:diffDir2 "a.txt") -Value "z" -Encoding UTF8
        Set-Content -Path (Join-Path $script:diffDir1 "same.txt") -Value "y" -Encoding UTF8
        Set-Content -Path (Join-Path $script:diffDir2 "same.txt") -Value "y" -Encoding UTF8
        Set-Content -Path (Join-Path $script:diffDir1 "only1.txt") -Value "o" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:diffRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "shows unified diff header with -u" {
        $result = & $script:diffFunc -u $script:diffFile1 $script:diffFile2
        @($result | Where-Object { $_ -match '^---' }).Count | Should Be 1
        @($result | Where-Object { $_ -match '^\+\+\+' }).Count | Should Be 1
        @($result | Where-Object { $_ -match '^\+' }).Count | Should BeGreaterThan 0
    }

    It "shows standard diff marker lines" {
        $result = & $script:diffFunc $script:diffFile1 $script:diffFile2
        @($result | Where-Object { $_ -match '^>' }).Count | Should BeGreaterThan 0
    }

    It "stays silent for identical files without -s" {
        $result = & $script:diffFunc $script:diffFile1 $script:diffFile3
        $result | Should Be $null
    }

    It "recursively compares directories with -r" {
        $result = & $script:diffFunc -r $script:diffDir1 $script:diffDir2
        @($result | Where-Object { $_ -match 'differ' }).Count | Should BeGreaterThan 0
        @($result | Where-Object { $_ -match 'Only in' }).Count | Should BeGreaterThan 0
    }

    It "warns when comparing directories without -r" {
        $out = & $script:diffFunc $script:diffDir1 $script:diffDir2 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns when missing a file operand" {
        $out = & $script:diffFunc $script:diffFile1 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns when the first file does not exist" {
        $out = & $script:diffFunc (Join-Path $script:diffRoot "ghost.txt") $script:diffFile2 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns when the second file does not exist" {
        $out = & $script:diffFunc $script:diffFile1 (Join-Path $script:diffRoot "ghost.txt") 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }
}

Describe "ln command coverage" {
    BeforeAll {
        $script:lnRoot = Join-Path $env:TEMP ("pba-cov-ln-" + $PID)
        $script:lnTarget = Join-Path $script:lnRoot "target.txt"
        $script:lnDir = Join-Path $script:lnRoot "targetdir"
        New-Item -ItemType Directory -Path $script:lnRoot -Force | Out-Null
        Set-Content -Path $script:lnTarget -Value "link content" -Encoding UTF8
        New-Item -ItemType Directory -Path $script:lnDir -Force | Out-Null
    }
    AfterAll {
        Remove-Item $script:lnRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "creates a hard link without -s" {
        $link = Join-Path $script:lnRoot "hard.txt"
        & $script:lnFunc $script:lnTarget $link
        Test-Path $link | Should Be $true
    }

    It "warns when creating a hard link to a directory" {
        $link = Join-Path $script:lnRoot "harddir.txt"
        $out = & $script:lnFunc $script:lnDir $link 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns when the target does not exist" {
        $link = Join-Path $script:lnRoot "ghost.txt"
        $out = & $script:lnFunc (Join-Path $script:lnRoot "missing.txt") $link 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns when the link name is missing" {
        $out = & $script:lnFunc $script:lnTarget 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns when the link already exists without -f" {
        $link = Join-Path $script:lnRoot "exists.txt"
        New-Item -ItemType HardLink -Path $link -Target $script:lnTarget | Out-Null
        $out = & $script:lnFunc $script:lnTarget $link 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
        Test-Path $link | Should Be $true
    }

    It "overwrites an existing link with -f" {
        $link = Join-Path $script:lnRoot "overwrite.txt"
        New-Item -ItemType HardLink -Path $link -Target $script:lnTarget | Out-Null
        & $script:lnFunc -f $script:lnTarget $link
        Test-Path $link | Should Be $true
    }

    It "creates a junction for a symbolic directory link" {
        $link = Join-Path $script:lnRoot "dirjunc"
        & $script:lnFunc -s $script:lnDir $link
        Test-Path $link | Should Be $true
    }

    It "handles symbolic file link without a terminating error" {
        $link = Join-Path $script:lnRoot "symlink.txt"
        { & $script:lnFunc -s $script:lnTarget $link } | Should Not Throw
    }
}

Describe "rm command coverage" {
    BeforeAll {
        $script:rmRoot = Join-Path $env:TEMP ("pba-cov-rm-" + $PID)
        New-Item -ItemType Directory -Path $script:rmRoot -Force | Out-Null
    }
    AfterAll {
        Remove-Item $script:rmRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "warns when removing a nonexistent file without -f" {
        $out = & $script:rmFunc (Join-Path $script:rmRoot "ghost.txt") 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns when removing a nonexistent directory without -f" {
        $out = & $script:rmFunc (Join-Path $script:rmRoot "ghostdir") 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "removes a read-only file with -f" {
        $file = Join-Path $script:rmRoot "ro.txt"
        Set-Content -Path $file -Value "read only" -Encoding UTF8
        (Get-Item $file).IsReadOnly = $true
        & $script:rmFunc -f $file
        Test-Path $file | Should Be $false
    }

    It "removes nested directories recursively with -rf including read-only files" {
        $dir = Join-Path $script:rmRoot "nested"
        New-Item -ItemType Directory -Path (Join-Path $dir "sub\deep") -Force | Out-Null
        Set-Content -Path (Join-Path $dir "top.txt") -Value "t" -Encoding UTF8
        Set-Content -Path (Join-Path $dir "sub\normal.txt") -Value "n" -Encoding UTF8
        Set-Content -Path (Join-Path $dir "sub\deep\ro.txt") -Value "r" -Encoding UTF8
        (Get-Item (Join-Path $dir "sub\deep\ro.txt")).IsReadOnly = $true
        & $script:rmFunc -rf $dir
        Test-Path $dir | Should Be $false
    }

    It "warns when removing a directory without -r" {
        $dir = Join-Path $script:rmRoot "dir-no-r"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $out = & $script:rmFunc $dir 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
        Test-Path $dir | Should Be $true
        Remove-Item $dir -Force -ErrorAction SilentlyContinue
    }
}

Describe "ls command coverage" {
    BeforeAll {
        $script:lsRoot = Join-Path $env:TEMP ("pba-cov-ls-" + $PID)
        $script:lsDir1 = Join-Path $script:lsRoot "dir1"
        $script:lsDir2 = Join-Path $script:lsRoot "dir2"
        $script:lsEmpty = Join-Path $script:lsRoot "empty"
        $script:lsPlain = Join-Path $script:lsRoot "plain"
        New-Item -ItemType Directory -Path $script:lsRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:lsDir1 -Force | Out-Null
        New-Item -ItemType Directory -Path $script:lsDir2 -Force | Out-Null
        New-Item -ItemType Directory -Path $script:lsEmpty -Force | Out-Null
        New-Item -ItemType Directory -Path $script:lsPlain -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:lsDir1 ".hidden") -Force | Out-Null
        Set-Content -Path (Join-Path $script:lsDir1 "visible.txt") -Value "v" -Encoding UTF8
        Set-Content -Path (Join-Path $script:lsDir1 "plain.txt") -Value "p" -Encoding UTF8
        Set-Content -Path (Join-Path $script:lsDir2 "two.txt") -Value "t" -Encoding UTF8
        Set-Content -Path (Join-Path $script:lsPlain "solo.txt") -Value "s" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:lsRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "warns on a nonexistent path" {
        $out = & $script:lsFunc (Join-Path $script:lsRoot "ghostdir") 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "lists multiple paths" {
        $result = & $script:lsFunc $script:lsDir1 $script:lsDir2
        @($result | Where-Object { $_ -match 'visible.txt' }).Count | Should Be 1
        @($result | Where-Object { $_ -match 'two.txt' }).Count | Should Be 1
    }

    It "lists the current directory by default" {
        $result = & $script:lsFunc -ArgList @()
        @($result | Where-Object { $_ -and $_ -match '\S' }).Count | Should Be 1
    }

    It "shows hidden files with --all" {
        $result = & $script:lsFunc --all $script:lsDir1
        @($result | Where-Object { $_ -match '\.hidden' }).Count | Should Be 1
    }

    It "shows long format with --long" {
        $result = & $script:lsFunc --long $script:lsDir1
        @($result | Where-Object { $_ -match 'total' }).Count | Should Be 1
    }

    It "shows human readable sizes with -l --human-readable" {
        $result = & $script:lsFunc -l --human-readable $script:lsDir1
        @($result | Where-Object { $_ -match 'B|K|M|G' }).Count | Should BeGreaterThan 0
    }

    It "shows hidden files in long format with -a -l" {
        $result = & $script:lsFunc -a -l $script:lsDir1
        @($result | Where-Object { $_ -match '\.hidden' }).Count | Should Be 1
    }

    It "shows no color codes for plain files in long format" {
        $result = & $script:lsFunc -l $script:lsPlain
        @($result | Where-Object { $_ -match '\[1;3' }).Count | Should Be 0
    }

    It "shows total 0 for an empty directory with -l" {
        $result = & $script:lsFunc -l $script:lsEmpty
        @($result | Where-Object { $_ -match 'total 0' }).Count | Should Be 1
    }
}

Describe "ll command coverage" {
    BeforeAll {
        $script:llRoot = Join-Path $env:TEMP ("pba-cov-ll-" + $PID)
        $script:llDir = Join-Path $script:llRoot "dir"
        New-Item -ItemType Directory -Path $script:llRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:llDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:llDir "subdir") -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $script:llDir ".hidden") -Force | Out-Null
        Set-Content -Path (Join-Path $script:llDir "visible.txt") -Value "v" -Encoding UTF8
        Set-Content -Path (Join-Path $script:llDir "prog.ps1") -Value "Write-Host hi" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:llRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "hides hidden files by default" {
        $result = & $script:llFunc $script:llDir
        @($result | Where-Object { $_ -match '\.hidden' }).Count | Should Be 0
    }

    It "lists the current directory by default" {
        $result = & $script:llFunc -ArgList @()
        @($result | Where-Object { $_ -match 'total' }).Count | Should Be 1
    }

    It "colors directories" {
        $result = & $script:llFunc $script:llDir
        @($result | Where-Object { $_ -match '\[1;34m' }).Count | Should Be 1
    }

    It "colors executable files" {
        $result = & $script:llFunc $script:llDir
        @($result | Where-Object { $_ -match '\[1;32m' }).Count | Should Be 1
    }

    It "does not color plain file rows" {
        $result = & $script:llFunc $script:llDir
        @($result | Where-Object { $_ -match 'visible\.txt' -and $_ -match '\[1;3' }).Count | Should Be 0
    }
}

Describe "stat command coverage" {
    BeforeAll {
        $script:statRoot = Join-Path $env:TEMP ("pba-cov-stat-" + $PID)
        $script:statFile = Join-Path $script:statRoot "data.txt"
        $script:statDir = Join-Path $script:statRoot "dir"
        New-Item -ItemType Directory -Path $script:statRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:statDir -Force | Out-Null
        [System.IO.File]::WriteAllText($script:statFile, "content")
    }
    AfterAll {
        Remove-Item $script:statRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "warns when called without an operand" {
        $out = & $script:statFunc -ArgList @() 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns on a nonexistent path" {
        $out = & $script:statFunc (Join-Path $script:statRoot "ghost.txt") 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "formats size and blocks for a file with -c" {
        $result = & $script:statFunc -c "%s %b" $script:statFile
        $first = @($result)[0]
        $first -match '^7 1$' | Should Be $true
    }

    It "formats size and mode for a directory with -c" {
        $result = & $script:statFunc -c "%s %A" $script:statDir
        $first = @($result)[0]
        $first -match '4096' | Should Be $true
        $first -match 'drwxr-xr-x' | Should Be $true
    }

    It "formats owner and group with -c" {
        $result = & $script:statFunc -c "%U %G" $script:statFile
        $first = @($result)[0]
        $first.Trim().Length | Should BeGreaterThan 0
    }

    It "formats modification time with -c" {
        $result = & $script:statFunc -c "%y" $script:statFile
        $first = @($result)[0]
        $first -match '\d{4}' | Should Be $true
    }

    It "shows default format for a directory" {
        $result = & $script:statFunc $script:statDir
        @($result | Where-Object { $_ -match 'File:' }).Count | Should Be 1
        @($result | Where-Object { $_ -match 'Size:' }).Count | Should Be 1
    }
}

Describe "realpath command coverage" {
    BeforeAll {
        $script:rpRoot = Join-Path $env:TEMP ("pba-cov-rp-" + $PID)
        $script:rpFile = Join-Path $script:rpRoot "data.txt"
        New-Item -ItemType Directory -Path $script:rpRoot -Force | Out-Null
        Set-Content -Path $script:rpFile -Value "data" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $script:rpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "warns when called without an operand" {
        $out = & $script:realpathFunc -ArgList @() 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "warns on a nonexistent path without -m" {
        $out = & $script:realpathFunc (Join-Path $script:rpRoot "ghost.txt") 2>&1
        @($out | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }).Count | Should Be 1
    }

    It "resolves multiple paths" {
        $result = & $script:realpathFunc $script:rpFile $script:rpFile
        @($result).Count | Should Be 2
        @($result | Where-Object { $_ -match ':\\' }).Count | Should Be 2
    }

    It "resolves an existing file with -s strip" {
        $result = & $script:realpathFunc -s $script:rpFile
        $first = @($result)[0]
        $first -match ':\\' | Should Be $true
    }
}
