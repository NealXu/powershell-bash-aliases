# tests/test-core-utils.ps1
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

# Force remove aliases to ensure function calls work
Remove-Item "Global:Alias:echo" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:tee" -Force -ErrorAction SilentlyContinue
Remove-Item "Global:Alias:env" -Force -ErrorAction SilentlyContinue

Describe "echo" {
    BeforeAll {
        # Get the echo function from the module
        $script:echoFunc = Get-Command echo -CommandType Function -ErrorAction SilentlyContinue
    }

    It "Outputs text" {
        $result = & $script:echoFunc "Hello World"
        $result | Should Be "Hello World"
    }

    It "Outputs without newline with -n" {
        # Note: -n uses Write-Host -NoNewline, so we just verify it doesn't throw
        { & $script:echoFunc -n "test" } | Should Not Throw
    }

    It "Parses escape sequences with --enable-escape" {
        $result = & $script:echoFunc --enable-escape "Line1\nLine2"
        $result | Should Be "Line1
Line2"
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
    BeforeAll {
        # Get the tee function from the module
        $script:teeFunc = Get-Command tee -CommandType Function -ErrorAction SilentlyContinue
    }

    It "Writes to file and stdout" {
        $testFile = "$env:TEMP\tee-test-$(Get-Random).txt"
        $result = "Hello World" | & $script:teeFunc $testFile
        $result | Should Be "Hello World"
        Get-Content $testFile | Should Be "Hello World"
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Appends to file with -a" {
        $testFile = "$env:TEMP\tee-append-$(Get-Random).txt"
        Set-Content $testFile "Line1"
        $result = "Line2" | & $script:teeFunc -a $testFile
        $result | Should Be "Line2"
        $content = Get-Content $testFile
        $content.Count | Should Be 2
        $content[0] | Should Be "Line1"
        $content[1] | Should Be "Line2"
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
    }

    It "Handles multiple files" {
        $testFile1 = "$env:TEMP\tee-multi1-$(Get-Random).txt"
        $testFile2 = "$env:TEMP\tee-multi2-$(Get-Random).txt"
        $result = "Test" | & $script:teeFunc $testFile1 $testFile2
        $result | Should Be "Test"
        Get-Content $testFile1 | Should Be "Test"
        Get-Content $testFile2 | Should Be "Test"
        Remove-Item $testFile1,$testFile2 -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = & $script:teeFunc --help
        $result | Should Match "Usage"
    }
}

Describe "date" {
    It "Shows current date" {
        $result = date
        $result -match "\w{3}" | Should Be $true
    }

    It "Shows help" {
        $result = date --help
        $result | Should Match "Usage"
    }

    It "Accepts custom date" {
        $result = date -d "2023-01-01"
        # Verify it doesn't throw and returns something
        $result | Should Not Be $null
    }
}

Describe "env" {
    It "Shows help" {
        $result = env --help
        $result | Should Match "Usage"
    }

    It "Does not throw when called" {
        # Verify env doesn't throw when called
        { env } | Should Not Throw
    }
}

Describe "history" {
    It "Displays history without error" {
        { history } | Should Not Throw
    }
}

Describe "time" {
    It "Shows help" {
        $result = time --help
        $result | Should Match "Usage"
    }

    It "Times a simple command" {
        { time echo "test" } | Should Not Throw
    }
}

Describe "seq" {
    It "Shows help" {
        $result = seq --help
        $result | Should Match "Usage"
    }

    It "Generates sequence to N" {
        $result = seq 5
        $result.Count | Should BeGreaterThan 0
    }

    It "Uses custom separator" {
        $result = seq -s " " 3
        $result | Should Not Be $null
    }
}

Describe "yes" {
    It "Shows help" {
        $result = yes --help
        $result | Should Match "Usage"
    }

    It "Outputs custom string" {
        $result = yes "hello" | Select-Object -First 3
        $result.Count | Should Be 3
    }
}

Describe "rev" {
    It "Reverses lines from pipeline" {
        $result = "hello" | rev
        $result | Should Be "olleh"
    }

    It "Reverses multiple lines" {
        $result = "abc","def" | rev
        $result[0] | Should Be "cba"
        $result[1] | Should Be "fed"
    }
}

Describe "shuf" {
    It "Shuffles lines from pipeline" {
        $result = "a","b","c" | shuf
        $result.Count | Should Be 3
    }

    It "Handles -e flag for echo mode" {
        $result = shuf -e "x" "y" "z"
        $result.Count | Should Be 3
    }
}

Describe "xargs" {
    It "Shows help" {
        $result = xargs --help
        $result | Should Match "Usage"
    }

    It "Respects -r flag" {
        $result = @() | xargs -r echo
        $result | Should Be $null
    }
}