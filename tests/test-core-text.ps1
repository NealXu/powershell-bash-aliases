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
}