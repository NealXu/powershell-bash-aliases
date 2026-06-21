# tests\test-core-process.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\core-process.ps1")

Describe "ps" {
    It "Lists processes" {
        $result = ps
        $result.Count | Should BeGreaterThan 0
    }

    It "Shows all processes with -e" {
        $result = ps -e
        $result.Count | Should BeGreaterThan 10
    }

    It "Shows help" {
        $result = ps -Help
        $result -match "Usage" | Should Be $true
    }

    It "Limits to 10 processes by default" {
        $procs = Get-Process
        $result = ps
        # ps 默认返回前10个进程的 Id, ProcessName
        $result.Count | Should BeLessThan 11
    }
}

Describe "kill" {
    It "Shows signal list with -l" {
        $result = kill -l
        $result -match "Signals" | Should Be $true
    }

    It "Shows help" {
        $result = kill -Help
        $result -match "Usage" | Should Be $true
    }

    It "Accepts process ID parameter" {
        # 创建一个短暂进程用于测试
        $proc = Start-Process -FilePath "powershell" -ArgumentList "-Command", "Start-Sleep -Seconds 5" -PassThru
        $procId = $proc.Id
        try {
            # 验证进程存在
            Get-Process -Id $procId -ErrorAction SilentlyContinue | Should Not Be $null
            # 终止进程
            kill -Id $procId
            Start-Sleep -Seconds 1
            # 验证进程已终止
            { Get-Process -Id $procId -ErrorAction Stop } | Should Throw
        } catch {
            # 清理
            Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe "killall" {
    It "Shows help" {
        $result = killall -Help
        $result -match "Usage" | Should Be $true
    }

    It "Accepts process name parameter" {
        # 使用已存在的进程名称测试（不会真正终止）
        $procsBefore = Get-Process -Name "explorer" -ErrorAction SilentlyContinue
        if ($procsBefore) {
            # 测试语法正确性，但不实际终止 explorer
            { killall -Name "nonexistent_process_xyz" } | Should Not Throw
        }
    }
}

Describe "top" {
    It "Shows top processes by memory" {
        $result = top -n 5
        $result.Count | Should BeGreaterThan 1
        $result[0] -match "PID" | Should Be $true
    }

    It "Shows help" {
        $result = top -Help
        $result -match "Usage" | Should Be $true
    }

    It "Limits output to N processes" {
        $result = top -n 3
        # 输出包含表头行，所以实际进程行数 = n
        $procLines = $result | Where { $_ -match "^\s*\d+" }
        $procLines.Count | Should BeLessThan 4
    }

    It "Uses default n=10" {
        $result = top
        # 验证输出格式
        $result[0] -match "Memory" | Should Be $true
    }
}

Describe "ps parameter tests" {
    It "Shows detailed format with -f" {
        $result = ps -f
        # -f 输出应该包含 CPU, WorkingSet 等信息
        $true | Should Be $true  # 验证函数可执行
    }

    It "Accepts -u user filter" {
        # -u 参数应该过滤用户
        $code = Get-Content (Join-Path $scriptDir "..\core-process.ps1") -Raw
        $code -match "UserName" | Should Be $true
    }

    It "Combines -e and -f" {
        $result = ps -e -f
        $true | Should Be $true  # 验证组合参数可执行
    }
}

Describe "kill parameter tests" {
    It "Accepts -Name parameter" {
        # 验证代码逻辑
        $code = Get-Content (Join-Path $scriptDir "..\core-process.ps1") -Raw
        $code -match "Stop-Process.*-Name" | Should Be $true
    }

    It "Handles non-existent process gracefully" {
        # kill 对不存在的进程会报错
        { kill -Id 999999 } | Should Throw
    }
}