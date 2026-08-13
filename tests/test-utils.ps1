# tests\test-utils.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")

Describe "Format-FileSize" {
    It "Returns raw bytes when not human-readable" {
        Format-FileSize -Bytes 1024 | Should Be "1024"
    }

    It "Returns human-readable format" {
        Format-FileSize -Bytes 1024 -HumanReadable | Should Be "1.0K"
    }

    It "Handles megabytes" {
        Format-FileSize -Bytes 1048576 -HumanReadable | Should Be "1.0M"
    }

    It "Handles gigabytes" {
        Format-FileSize -Bytes 1073741824 -HumanReadable | Should Be "1.0G"
    }

    It "Handles zero bytes" {
        Format-FileSize -Bytes 0 -HumanReadable | Should Be "0.0B"
    }
}

Describe "Format-FileTime" {
    It "Returns time format string" {
        $recentTime = (Get-Date).AddDays(-30)
        $result = Format-FileTime -Time $recentTime
        $result.Length | Should BeGreaterThan 5
    }

    It "Returns time format with year" {
        $oldTime = (Get-Date).AddYears(-1)
        $result = Format-FileTime -Time $oldTime
        $result.Length | Should BeGreaterThan 5
    }
}

Describe "Format-UnixMode" {
    BeforeAll {
        $testDir = "test-temp"
        New-Item -ItemType Directory -Path $testDir -Force
        New-Item -ItemType File -Path "$testDir\file.txt" -Force
    }

    AfterAll {
        Remove-Item "test-temp" -Recurse -Force
    }

    It "Returns 'd' prefix for directories" {
        $dir = Get-Item "test-temp"
        $result = Format-UnixMode -Item $dir
        $result.Substring(0, 1) | Should Be 'd'
    }

    It "Returns '-' prefix for files" {
        $file = Get-Item "test-temp\file.txt"
        $result = Format-UnixMode -Item $file
        $result.Substring(0, 1) | Should Be '-'
    }

    It "Returns 10-character string" {
        $file = Get-Item "test-temp\file.txt"
        $result = Format-UnixMode -Item $file
        $result.Length | Should Be 10
    }
}

Describe "Format-Columns" {
    It "Formats single column when items are long" {
        $items = @('very-long-item-name-1', 'very-long-item-name-2')
        $result = Format-Columns -Items $items -MaxWidth 20
        $result.Split([Environment]::NewLine).Count | Should Be 2
    }

    It "Formats multiple columns when items are short" {
        $items = @('a', 'b', 'c', 'd', 'e', 'f')
        $result = Format-Columns -Items $items -MaxWidth 20
        $lines = $result.Split([Environment]::NewLine)
        $lines[0].Split(' ', [StringSplitOptions]::RemoveEmptyEntries).Count | Should BeGreaterThan 1
    }

    It "Handles empty items" {
        $result = Format-Columns -Items @() -MaxWidth 80
        $result | Should Be ''
    }
}

Describe "Convert-BashPath" {
    It "Expands ~ to home directory" {
        $result = Convert-BashPath -Path '~/test'
        $result -match "^$([regex]::Escape($HOME))" | Should Be $true
    }

    It "Handles . (current directory)" {
        Convert-BashPath -Path '.' | Should Be '.'
    }

    It "Handles .. (parent directory)" {
        Convert-BashPath -Path '..' | Should Be '..'
    }

    It "Returns unchanged for absolute paths" {
        Convert-BashPath -Path 'C:\test' | Should Be 'C:\test'
    }

    It "Handles nested ~ paths" {
        $result = Convert-BashPath -Path '~/subdir/file.txt'
        $result -match "^$([regex]::Escape($HOME))" | Should Be $true
        $result -match "subdir" | Should Be $true
    }

    It "Handles relative paths" {
        $result = Convert-BashPath -Path 'folder/file.txt'
        $result | Should Be 'folder/file.txt'
    }
}

Describe "Format-FileSize edge cases" {
    It "Handles terabytes" {
        $tb = 1099511627776  # 1 TB
        $result = Format-FileSize -Bytes $tb -HumanReadable
        $result -match "T" | Should Be $true
    }

    It "Handles petabytes" {
        $pb = 1125899906842624  # 1 PB
        $result = Format-FileSize -Bytes $pb -HumanReadable
        $result -match "P" | Should Be $true
    }

    It "Handles boundary 1023 bytes" {
        $result = Format-FileSize -Bytes 1023 -HumanReadable
        $result -match "B" | Should Be $true
    }

    It "Handles boundary 1024 bytes (1K)" {
        $result = Format-FileSize -Bytes 1024 -HumanReadable
        $result | Should Be "1.0K"
    }
}

Describe "Format-FileTime edge cases" {
    It "Handles exactly 180 days" {
        $boundaryTime = (Get-Date).AddDays(-180)
        $result = Format-FileTime -Time $boundaryTime
        $result.Length | Should BeGreaterThan 5
    }
}

Describe "Format-Columns edge cases" {
    It "Handles single item" {
        $result = Format-Columns -Items @('single') -MaxWidth 80
        $result | Should Be 'single'
    }

    It "Handles large number of items" {
        $items = @()
        for ($i=1; $i -le 100; $i++) { $items += "item$i" }
        $result = Format-Columns -Items $items -MaxWidth 80
        $result.Split([char]10).Count | Should BeGreaterThan 1
    }
}

Describe "Read-BashFileContent" {
    BeforeAll {
        $rfTestDir = Join-Path $env:TEMP ("rf-test-" + [guid]::NewGuid().ToString("N"))
        New-Item -ItemType Directory -Path $rfTestDir -Force | Out-Null
        Set-Content -Path (Join-Path $rfTestDir "data.txt") -Value @("line1", "line2") -Encoding UTF8
    }

    AfterAll {
        Remove-Item $rfTestDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Resolves relative path against PowerShell location, not .NET CWD" {
        $orig = Get-Location
        try {
            Set-Location $rfTestDir
            # .NET process CWD is unchanged, but PowerShell location is now the temp dir.
            # Reading a relative path must still resolve to the temp-dir file.
            $result = Read-BashFileContent "data.txt"
            $result.Count | Should Be 2
            $result[0] | Should Be "line1"
        } finally {
            Set-Location $orig
        }
    }

    It "Returns null for non-existent file" {
        (Read-BashFileContent (Join-Path $rfTestDir "nope.txt")) | Should Be $null
    }
}

Describe "Step-PageTop" {
    It "UpArrow clamps at top" {
        Step-PageTop -Top 0 -Total 100 -PageSize 20 -Key 'UpArrow' | Should Be 0
    }
    It "UpArrow decrements" {
        Step-PageTop -Top 5 -Total 100 -PageSize 20 -Key 'UpArrow' | Should Be 4
    }
    It "DownArrow increments" {
        Step-PageTop -Top 5 -Total 100 -PageSize 20 -Key 'DownArrow' | Should Be 6
    }
    It "DownArrow clamps at last line" {
        Step-PageTop -Top 99 -Total 100 -PageSize 20 -Key 'DownArrow' | Should Be 99
    }
    It "Spacebar pages down" {
        Step-PageTop -Top 0 -Total 100 -PageSize 20 -Key 'Spacebar' | Should Be 20
    }
    It "Spacebar clamps at last page top" {
        Step-PageTop -Top 80 -Total 100 -PageSize 20 -Key 'Spacebar' | Should Be 80
    }
    It "PageDown pages down" {
        Step-PageTop -Top 0 -Total 100 -PageSize 20 -Key 'PageDown' | Should Be 20
    }
    It "PageUp pages up" {
        Step-PageTop -Top 40 -Total 100 -PageSize 20 -Key 'PageUp' | Should Be 20
    }
    It "Home goes to top" {
        Step-PageTop -Top 50 -Total 100 -PageSize 20 -Key 'Home' | Should Be 0
    }
    It "End goes to last page top" {
        Step-PageTop -Top 0 -Total 100 -PageSize 20 -Key 'End' | Should Be 80
    }
    It "Unknown key keeps position" {
        Step-PageTop -Top 30 -Total 100 -PageSize 20 -Key 'X' | Should Be 30
    }
}