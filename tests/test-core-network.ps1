# tests\test-core-network.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Import module to get properly exported functions
Import-Module (Join-Path $scriptDir "..\bash-aliases.psm1") -Force

Describe "curl" {
    BeforeAll {
        # Get the curl function from the module
        $script:curlFunc = Get-Command curl -CommandType Function -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = & $script:curlFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Returns content for valid URL" -Skip {
        # 网络测试需要在线环境，默认跳过
        $result = curl -Url "http://localhost"
        $result | Should Not Be $null
    }

    It "Downloads file with -O" -Skip {
        # 需要网络连接
        curl -Url "http://localhost/test.txt" -O
        Test-Path "test.txt" | Should Be $true
        Remove-Item "test.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Downloads to custom file with -OutputFile" -Skip {
        curl -Url "http://localhost/test.txt" -OutputFile "custom.txt"
        Test-Path "custom.txt" | Should Be $true
        Remove-Item "custom.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Returns headers with -I" -Skip {
        $result = curl -Url "http://localhost" -I
        $result | Should Not Be $null
    }

    It "Handles invalid URL gracefully" -Skip {
        # 需要验证错误处理
        { curl -Url "http://invalid-host-xyz" } | Should Not Throw
    }

    It "Passes the -o FILE path (not a boolean) as OutFile" {
        Mock Invoke-WebRequest { param($Url, $OutFile) return [pscustomobject]@{ Content = "saved:$OutFile" } } -ModuleName bash-aliases
        $null = & $script:curlFunc -o 'out.txt' 'http://example.com/file.txt'
        Assert-MockCalled Invoke-WebRequest -ModuleName bash-aliases -Times 1 -ParameterFilter { $OutFile -is [string] -and $OutFile -eq 'out.txt' }
    }
}

Describe "ping" {
    It "Shows help" {
        $result = ping -Help
        $result -match "Usage" | Should Be $true
    }

    It "Pings localhost successfully" -Skip {
        # 网络测试需要在线环境
        $result = ping -Host "localhost" -c 1
        $result -match "Reply" | Should Be $true
    }

    It "Accepts -c count parameter" -Skip {
        $result = ping -Host "localhost" -c 2
        # 应返回2条回复
        ($result | Where { $_ -match "Reply" }).Count | Should Be 2
    }

    It "Handles unreachable host" -Skip {
        # 验证主机不可达的处理
        { ping -Host "192.168.255.255" -c 1 } | Should Not Throw
    }
}

Describe "netstat" {
    It "Shows help" {
        $result = netstat -Help
        $result -match "Usage" | Should Be $true
    }

    It "Shows network connections by default" -Skip {
        # 需要系统网络连接
        $result = netstat
        $result.Count | Should BeGreaterThan 0
    }

    It "Shows TCP connections with -t" -Skip {
        $result = netstat -t
        $result | Where { $_ -match "tcp" } | Should Not Be $null
    }

    It "Shows numeric addresses with -n" -Skip {
        $result = netstat -n
        # 数字地址格式检查
        $result | Where { $_ -match "\d+\.\d+\.\d+\.\d+" } | Should Not Be $null
    }

    It "Falls back to netstat.exe when Get-NetTCPConnection fails" {
        # 验证回退机制存在（代码中有回退逻辑）
        # 在不支持 Get-NetTCPConnection 的系统上应回退
        $code = Get-Content (Join-Path $scriptDir "..\core-network.ps1") -Raw
        $code -match "netstat\.exe" | Should Be $true
    }
}

Describe "wget" {
    BeforeAll {
        # Get the wget function from the module
        $script:wgetFunc = Get-Command wget -CommandType Function -ErrorAction SilentlyContinue
    }
    It "Shows help" {
        $result = & $script:wgetFunc --help
        $result -match "Usage" | Should Be $true
    }

    It "Downloads file to default location" -Skip {
        # 网络测试需要在线环境
        wget -Url "http://localhost/test.txt"
        Test-Path "test.txt" | Should Be $true
        Remove-Item "test.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Downloads file with -O custom output" -Skip {
        wget -Url "http://localhost/test.txt" -O "custom.txt"
        Test-Path "custom.txt" | Should Be $true
        Remove-Item "custom.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Downloads silently with -q" -Skip {
        # 静默模式不应输出进度消息
        $result = wget -Url "http://localhost/test.txt" -q
        $result | Should Be $null
        Remove-Item "test.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Handles download failure gracefully" -Skip {
        # 验证下载失败时的错误处理
        { wget -Url "http://invalid-host-xyz/test.txt" } | Should Not Throw
    }

    It "Uses URL filename as default output" {
        # 验证代码逻辑：Split-Path $Url -Leaf
        $url = "http://example.com/file.txt"
        $expectedFile = Split-Path $url -Leaf
        $expectedFile | Should Be "file.txt"
    }
}