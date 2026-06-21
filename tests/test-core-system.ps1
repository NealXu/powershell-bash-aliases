# tests\test-core-system.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\args-parser.ps1")
. (Join-Path $scriptDir "..\core-system.ps1")

Describe "df" {
    It "Shows disk usage" {
        $result = df
        $result -match "C" | Should Be $true
    }

    It "Shows human-readable with -h" {
        $result = df -h
        $result -match "K|M|G" | Should Be $true
    }

    It "Shows help" {
        $result = df -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "du" {
    BeforeAll {
        $testDir = "test-du-temp"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path "$testDir\file.txt" -Force | Out-Null
        Set-Content -Path "$testDir\file.txt" -Value "content" -Encoding UTF8
    }

    AfterAll {
        Remove-Item "test-du-temp" -Recurse -Force -ErrorAction SilentlyContinue
    }

    It "Shows directory size" {
        $result = du -Path $testDir
        $result -match "\d+" | Should Be $true
    }

    It "Shows human-readable with -h" {
        $result = du -Path $testDir -h
        $result -match "B|K|M" | Should Be $true
    }

    It "Shows help" {
        $result = du -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "uptime" {
    It "Shows uptime info" {
        $result = uptime
        $result -match "up" | Should Be $true
    }

    It "Shows help" {
        $result = uptime -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "uname" {
    It "Shows system name" {
        $result = uname
        $result -match "Windows" | Should Be $true
    }

    It "Shows all info with -a" {
        $result = uname -a
        $result.Length | Should BeGreaterThan 10
    }

    It "Shows version with -r" {
        $result = uname -r
        $result -match "\d+" | Should Be $true
    }

    It "Shows hostname with -n" {
        $result = uname -n
        $result | Should Be $env:COMPUTERNAME
    }

    It "Shows help" {
        $result = uname -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "hostname" {
    It "Shows computer name" {
        $result = hostname
        $result | Should Be $env:COMPUTERNAME
    }

    It "Shows help" {
        $result = hostname -Help
        $result -match "Usage" | Should Be $true
    }
}

Describe "du parameter tests" {
    BeforeAll {
        $testDir = "test-du-params"
        $testFile = "test-du-file.txt"
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        New-Item -ItemType File -Path $testFile -Force | Out-Null
        Set-Content -Path $testFile -Value "content" -Encoding UTF8
    }
    AfterAll {
        Remove-Item $testDir, $testFile -Force -ErrorAction SilentlyContinue
    }
    It "Shows summary with -s" {
        $result = du -Path $testDir -s
        $result -match "\d+" | Should Be $true
    }
    It "Handles file (not directory)" {
        $result = du -Path $testFile
        $result -match "\d+" | Should Be $true
    }
    It "Handles non-existent path gracefully" {
        # du 对不存在的路径会报错
        { du -Path "nonexistent-path-xyz" } | Should Throw
    }
}

Describe "df edge cases" {
    It "Handles drive with zero total" {
        # 验证代码中的 total=0 处理
        $code = Get-Content (Join-Path $scriptDir "..\core-system.ps1") -Raw
        $code -match "total -gt 0" | Should Be $true
    }
}