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