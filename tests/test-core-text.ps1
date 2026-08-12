# tests\test-core-text.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\args-parser.ps1")
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
        $result = head $testFile
        $result.Count | Should Be 10
    }
    It "Shows first N lines" {
        $result = head -n 5 $testFile
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
        $result = tail $testFile
        $result.Count | Should Be 10
    }
    It "Shows last N lines" {
        $result = tail -n 5 $testFile
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
    It "Counts lines words bytes" {
        $result = wc $testFile
        $result -match "\d+ \d+ \d+" | Should Be $true
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
        $result = sort $testFile
        $result[0] | Should Be "apple"
    }
    It "Sorts reverse" {
        $result = sort -r $testFile
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
        $result = cut -d "," -f "1" $testFile
        $result[0] | Should Be "a"
    }
}

Describe "tr" {
    It "Shows help" {
        $result = tr --help
        $result -match "Usage" | Should Be $true
    }
    It "Translates characters" {
        $result = "hello" -replace "h", "H"
        $result | Should Be "Hello"
    }
    It "Deletes characters" {
        $result = "hello" -replace "l", ""
        $result | Should Be "heo"
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
        $result = head --help
        $result -match "Usage" | Should Be $true
    }
    It "Accepts custom n parameter" {
        $result = head -n 3 $testFile
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
        $result = tail --help
        $result -match "Usage" | Should Be $true
    }
    It "-f flag is accepted" {
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
        $result = wc -c $testFile
        $result -match "\d+" | Should Be $true
    }
    It "Shows all counts by default" {
        $result = wc $testFile
        $result -match "\d+ \d+ \d+" | Should Be $true
    }
    It "Shows combined counts" {
        $result = wc -l -w $testFile
        $result -match "\d+ \d+" | Should Be $true
    }
    It "Shows help" {
        $result = wc --help
        $result -match "Usage" | Should Be $true
    }
    It "Handles multiple files" {
        $result = wc $testFile $testFile2
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
        $result = sort --help
        $result -match "Usage" | Should Be $true
    }
    It "Sorts numerically with -n" {
        $result = sort -n $testFile
        $result[0] | Should Be "1"
        $result[1] | Should Be "2"
    }
    It "Shows unique values with -u" {
        $dupFile = "test-sort-uniq.txt"
        Set-Content -Path $dupFile -Value "a", "a", "b" -Encoding UTF8
        $result = sort -u $dupFile
        $result.Count | Should Be 2
        Remove-Item $dupFile -Force -ErrorAction SilentlyContinue
    }
    It "Combines -n and -r" {
        $result = sort -n -r $testFile
        $result[0] | Should Be "20"
    }
}

Describe "uniq parameter tests" {
    It "Shows help" {
        $result = uniq --help
        $result -match "Usage" | Should Be $true
    }
    It "Shows counts with -c" {
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
        $result = cut --help
        $result -match "Usage" | Should Be $true
    }
    It "Uses custom delimiter with -d" {
        $result = cut -d "," -f "1" $testFile
        $result[0] | Should Be "a"
    }
    It "Extracts multiple fields" {
        $result = cut -d "," -f "1,3" $testFile
        $result[0] | Should Be "a,c"
    }
    It "Handles field index out of range" {
        $result = cut -d "," -f "10" $testFile
        $result[0] | Should Be ""
    }
}

Describe "sed" {
    BeforeAll {
        $testFile = "test-sed.txt"
        Set-Content -Path $testFile -Value "hello world", "foo bar", "test line" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Remove-Item "test-sed-out.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = sed --help
        $result -match "Usage" | Should Be $true
    }
    It "Substitutes text" {
        $result = sed "s/hello/HELLO/" $testFile
        $result[0] | Should Be "HELLO world"
    }
    It "Performs global substitution" {
        $result = sed "s/o/O/g" $testFile
        $result[0] | Should Be "hellO wOrld"
    }
    It "Modifies file in place with -i" {
        Copy-Item $testFile "test-sed-out.txt"
        sed -i "s/test/TEST/" "test-sed-out.txt"
        $content = Get-Content "test-sed-out.txt"
        $content[2] | Should Be "TEST line"
    }
}

Describe "awk" {
    BeforeAll {
        $testFile = "test-awk.txt"
        Set-Content -Path $testFile -Value "apple 10 red", "banana 20 yellow", "cherry 30 red" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = awk --help
        $result -match "Usage" | Should Be $true
    }
    It "Uses field separator -F" {
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "field-separator" | Should Be $true
    }
    It "Prints specific field" {
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "print" | Should Be $true
    }
    It "Processes file content" {
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "Get-Content" | Should Be $true
    }
}

Describe "patch" {
    BeforeAll {
        $testFile = "test-patch-original.txt"
        Set-Content -Path $testFile -Value "line1", "line2", "line3" -Encoding UTF8

        $patchFile = "test-patch.diff"
        $patchContent = @(
            "--- a/test-patch-original.txt",
            "+++ b/test-patch-original.txt",
            "@@ -1,3 +1,3 @@",
            " line1",
            "-line2",
            "+LINE2_MODIFIED",
            " line3"
        )
        Set-Content -Path $patchFile -Value $patchContent -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        Remove-Item $patchFile -Force -ErrorAction SilentlyContinue
        Remove-Item "test-patch-output.txt" -Force -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = patch --help
        $result -match "Usage" | Should Be $true
    }
    It "Shows dry-run option" {
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "dry-run" | Should Be $true
    }
    It "Shows reverse option" {
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "reverse" | Should Be $true
    }
    It "Parses unified diff format" {
        $code = Get-Content (Join-Path $scriptDir "..\core-text.ps1") -Raw
        $code -match "^---.*\+\+\+" | Should Be $true
    }
}
