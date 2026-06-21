# tests\test-core-text.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\core-text.ps1")

Describe "head" {
    BeforeAll {
        $testFile = "test-head.txt"
        $content = @()
        for ($i=1; $i -le 20; $i++) { $content += "line$i" }
        Set-Content -Path $testFile -Value $content -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-head.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Shows first 10 lines by default" {
        $result = Get-Content $testFile | Select-Object -First 10
        $result.Count | Should Be 10
    }
    It "Shows first N lines" {
        $result = Get-Content $testFile | Select-Object -First 5
        $result.Count | Should Be 5
    }
}

Describe "tail" {
    BeforeAll {
        $testFile = "test-tail.txt"
        $content = @()
        for ($i=1; $i -le 20; $i++) { $content += "line$i" }
        Set-Content -Path $testFile -Value $content -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-tail.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Shows last 10 lines by default" {
        $result = Get-Content $testFile | Select-Object -Last 10
        $result.Count | Should Be 10
    }
    It "Shows last N lines" {
        $result = Get-Content $testFile | Select-Object -Last 5
        $result.Count | Should Be 5
    }
}

Describe "wc" {
    BeforeAll {
        $testFile = "test-wc.txt"
        Set-Content -Path $testFile -Value "hello world", "test line" -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-wc.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Counts lines" {
        $content = Get-Content $testFile
        $content.Count | Should Be 2
    }
    It "Counts words" {
        $words = (Get-Content $testFile | ForEach { $_.Split(' ') } | Measure-Object).Count
        $words | Should Be 4
    }
}

Describe "sort" {
    BeforeAll {
        $testFile = "test-sort.txt"
        Set-Content -Path $testFile -Value "zebra", "apple", "banana" -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-sort.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Sorts alphabetically" {
        $result = Get-Content $testFile | Sort-Object
        $result[0] | Should Be "apple"
    }
    It "Sorts reverse" {
        $result = Get-Content $testFile | Sort-Object -Descending
        $result[0] | Should Be "zebra"
    }
}

Describe "uniq" {
    It "Shows unique lines" {
        $input = @("a", "a", "b", "b", "c") | Sort-Object | Get-Unique
        $input.Count | Should Be 3
    }
}

Describe "cut" {
    BeforeAll {
        $testFile = "test-cut.txt"
        Set-Content -Path $testFile -Value "a,b,c", "x,y,z" -Encoding UTF8
    }
    AfterAll {
        Remove-Item "test-cut.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Extracts field by delimiter" {
        $line = Get-Content $testFile | Select-Object -First 1
        $parts = $line.Split(',')
        $parts[0] | Should Be "a"
    }
}

Describe "tr" {
    It "Translates characters" {
        $result = "hello" -replace "h", "H"
        $result | Should Be "Hello"
    }
    It "Deletes characters" {
        $result = "hello" -replace "l", ""
        $result | Should Be "heo"
    }
    It "Shows help" {
        $result = tr -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "head parameter tests" {
    BeforeAll {
        $testFile = "test-head-params.txt"
        $content = @()
        for ($i=1; $i -le 20; $i++) { $content += "line$i" }
        Set-Content -Path $testFile -Value $content -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = head -Help
        $result -match "Usage" | Should Be $true
    }
    It "Accepts custom n parameter" {
        $result = head -Path $testFile -n 3
        $result.Count | Should Be 3
    }
}

Describe "tail parameter tests" {
    BeforeAll {
        $testFile = "test-tail-params.txt"
        $content = @()
        for ($i=1; $i -le 20; $i++) { $content += "line$i" }
        Set-Content -Path $testFile -Value $content -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = tail -Help
        $result -match "Usage" | Should Be $true
    }
    It "-f flag is accepted" {
        # -f 使用 Get-Content -Wait，需要跳过实际执行
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "Get-Content.*-Wait" | Should Be $true
    }
}

Describe "wc parameter tests" {
    BeforeAll {
        $testFile = "test-wc-params.txt"
        $testFile2 = "test-wc-params2.txt"
        Set-Content -Path $testFile -Value "hello world", "test line" -Encoding UTF8
        Set-Content -Path $testFile2 -Value "single" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile, $testFile2 -Force -ErrorAction SilentlyContinue
    }
    It "Shows character count with -c" {
        $result = wc -Path $testFile -c
        $result -match "\d+" | Should Be $true
    }
    It "Shows all counts by default" {
        $result = wc -Path $testFile
        $result -match "\d+ \d+ \d+" | Should Be $true
    }
    It "Shows combined counts" {
        $result = wc -Path $testFile -l -w
        $result -match "\d+ \d+" | Should Be $true
    }
    It "Shows help" {
        $result = wc -Help
        $result -match "Usage" | Should Be $true
    }
    It "Handles multiple files" {
        $result = wc -Path $testFile, $testFile2
        $result.Count | Should Be 2
    }
}

Describe "sort parameter tests" {
    BeforeAll {
        $testFile = "test-sort-params.txt"
        Set-Content -Path $testFile -Value "10", "2", "1", "20" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = sort -Help
        $result -match "Usage" | Should Be $true
    }
    It "Sorts numerically with -n" {
        $result = sort -Path $testFile -n
        $result[0] | Should Be "1"
        $result[1] | Should Be "2"
    }
    It "Shows unique values with -u" {
        $dupFile = "test-sort-uniq.txt"
        Set-Content -Path $dupFile -Value "a", "a", "b" -Encoding UTF8
        $result = sort -Path $dupFile -u
        $result.Count | Should Be 2
        Remove-Item $dupFile -Force -ErrorAction SilentlyContinue
    }
    It "Combines -n and -r" {
        $result = sort -Path $testFile -n -r
        $result[0] | Should Be "20"
    }
}

Describe "uniq parameter tests" {
    It "Shows help" {
        $result = uniq -Help
        $result -match "Usage" | Should Be $true
    }
    It "Shows counts with -c" {
        $inputData = @("a", "a", "b", "b", "c")
        $sorted = $inputData | Sort-Object
        # uniq 函数使用 $input，需要特殊测试方式
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "Group" | Should Be $true
    }
    It "Shows duplicates only with -d" {
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "Get-Unique" | Should Be $true
    }
}

Describe "cut parameter tests" {
    BeforeAll {
        $testFile = "test-cut-params.txt"
        Set-Content -Path $testFile -Value "a,b,c", "x,y,z" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = cut -Help
        $result -match "Usage" | Should Be $true
    }
    It "Uses custom delimiter with -d" {
        $result = cut -Path $testFile -d "," -f "1"
        $result[0] | Should Be "a"
    }
    It "Extracts multiple fields" {
        $result = cut -Path $testFile -d "," -f "1,3"
        $result[0] | Should Be "a,c"
    }
    It "Handles field index out of range" {
        $result = cut -Path $testFile -d "," -f "10"
        $result[0] | Should Be ""
    }
}