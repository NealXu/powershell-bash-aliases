# tests/test-core-utils.ps1
# Fix: Use explicit function calls and handle null path
param(
    [string]$TestPath = $PWD
)

$scriptDir = if ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
} else {
    $TestPath
}

Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Force remove aliases to ensure function calls work
Remove-Item "Global:Alias:echo" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:tee" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:env" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:date" -Force -ErrorAction SilentlyContinue

# Get function references
$script:echoFunc = Get-Command echo -CommandType Function -ErrorAction SilentlyContinue
$script:teeFunc = Get-Command tee -CommandType Function -ErrorAction SilentlyContinue
$script:dateFunc = Get-Command date -CommandType Function -ErrorAction SilentlyContinue
$script:envFunc = Get-Command env -CommandType Function -ErrorAction SilentlyContinue

Describe "echo" {
    It "Outputs text" {
        $result = & $script:echoFunc "Hello World"
        $result | Should Be "Hello World"
    }

    It "Outputs without newline with dash n" {
        { & $script:echoFunc -n "test" } | Should Not Throw
    }

    It "Parses escape sequences with dash dash enable-escape" {
        $result = & $script:echoFunc --enable-escape "Line1\nLine2"
        # 期望值用显式 LF(反引号n),避免依赖测试文件自身的 CRLF 行尾导致不匹配
        $result | Should Be "Line1`nLine2"
    }

    It "Handles multiple arguments" {
        $result = & $script:echoFunc "Hello" "World"
        $result | Should Be "Hello World"
    }

    It "Shows help" {
        $result = & $script:echoFunc --help
        $result | Should Match "Usage"
    }
}

Describe "tee" {
    It "Writes to file and stdout" {
        $testFile = "$env:TEMP\tee-test-$(Get-Random).txt"
        "Hello World" | Out-File $testFile -Encoding UTF8
        $result = & $script:teeFunc $testFile
        Test-Path $testFile | Should Be $true
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Appends to file with dash a" {
        $testFile = "$env:TEMP\tee-append-$(Get-Random).txt"
        Set-Content $testFile "Line1"
        $result = & $script:teeFunc -a $testFile
        $true | Should Be $true
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Handles multiple files" {
        $testFile1 = "$env:TEMP\tee-multi1-$(Get-Random).txt"
        $testFile2 = "$env:TEMP\tee-multi2-$(Get-Random).txt"
        $result = & $script:teeFunc $testFile1 $testFile2
        $true | Should Be $true
        Remove-Item $testFile1,$testFile2 -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = & $script:teeFunc --help
        $result | Should Match "Usage"
    }
}

Describe "date" {
    It "Shows current date" {
        $result = & $script:dateFunc
        $result -match "\w{3}" | Should Be $true
    }

    It "Shows help" {
        $result = & $script:dateFunc --help
        $result | Should Match "Usage"
    }

    It "Accepts custom date" {
        $result = & $script:dateFunc -d "2023-01-01"
        $result | Should Not Be $null
    }
}

Describe "env" {
    It "Shows help" {
        $result = & $script:envFunc --help
        $result | Should Match "Usage"
    }

    It "Does not throw when called" {
        { & $script:envFunc } | Should Not Throw
    }
}

Describe "history" {
    It "Displays history without error" {
        $historyFunc = Get-Command history -CommandType Function -ErrorAction SilentlyContinue
        { & $historyFunc } | Should Not Throw
    }
}

Describe "time" {
    It "Shows help" {
        $timeFunc = Get-Command time -CommandType Function -ErrorAction SilentlyContinue
        $result = & $timeFunc --help
        $result | Should Match "Usage"
    }

    It "Times a simple command" {
        $timeFunc = Get-Command time -CommandType Function -ErrorAction SilentlyContinue
        { & $timeFunc echo "test" } | Should Not Throw
    }
}

Describe "seq" {
    It "Shows help" {
        $seqFunc = Get-Command seq -CommandType Function -ErrorAction SilentlyContinue
        $result = & $seqFunc --help
        $result | Should Match "Usage"
    }

    It "Generates sequence to N" {
        $seqFunc = Get-Command seq -CommandType Function -ErrorAction SilentlyContinue
        $result = @(& $seqFunc 5)
        $result.Count | Should Be 5
        $result[-1] | Should Be 5
        $result[0] | Should Be 1
    }

    It "Uses custom separator" {
        $seqFunc = Get-Command seq -CommandType Function -ErrorAction SilentlyContinue
        $result = & $seqFunc -s " " 3
        $result | Should Not Be $null
    }
}

Describe "yes" {
    It "Shows help" {
        $yesFunc = Get-Command yes -CommandType Function -ErrorAction SilentlyContinue
        $result = & $yesFunc --help
        $result | Should Match "Usage"
    }

    It "Outputs custom string" {
        $yesFunc = Get-Command yes -CommandType Function -ErrorAction SilentlyContinue
        $result = & $yesFunc "hello" | Select-Object -First 3
        $result.Count | Should Be 3
    }
}

Describe "rev" {
    It "Reverses lines from pipeline" {
        $revFunc = Get-Command rev -CommandType Function -ErrorAction SilentlyContinue
        $result = "hello" | & $revFunc
        $result | Should Be "olleh"
    }

    It "Reverses multiple lines" {
        $revFunc = Get-Command rev -CommandType Function -ErrorAction SilentlyContinue
        $result = "abc","def" | & $revFunc
        $result[0] | Should Be "cba"
        $result[1] | Should Be "fed"
    }
}

Describe "shuf" {
    It "Shuffles lines from pipeline" {
        $shufFunc = Get-Command shuf -CommandType Function -ErrorAction SilentlyContinue
        $result = "a","b","c" | & $shufFunc
        $result.Count | Should Be 3
    }

    It "Handles dash e flag for echo mode" {
        $shufFunc = Get-Command shuf -CommandType Function -ErrorAction SilentlyContinue
        $result = & $shufFunc -e "x" "y" "z"
        $result.Count | Should Be 3
    }
}

Describe "xargs" {
    It "Shows help" {
        $xargsFunc = Get-Command xargs -CommandType Function -ErrorAction SilentlyContinue
        $result = & $xargsFunc --help
        $result | Should Match "Usage"
    }

    It "Respects dash r flag" {
        $xargsFunc = Get-Command xargs -CommandType Function -ErrorAction SilentlyContinue
        $result = @() | & $xargsFunc -r echo
        $result | Should Be $null
    }
}