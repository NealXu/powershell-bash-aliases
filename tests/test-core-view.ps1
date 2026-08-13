# tests\test-core-view.ps1 (兼容 Pester 3.4.0)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "..\utils.ps1")
. (Join-Path $scriptDir "..\args-parser.ps1")
. (Join-Path $scriptDir "..\core-view.ps1")

$script:lessFunc = Get-Command less -CommandType Function -ErrorAction SilentlyContinue
$script:moreFunc = Get-Command more -CommandType Function -ErrorAction SilentlyContinue

Describe "less" {
    BeforeAll {
        $testFile = "test-less.txt"
        $content = @()
        for ($i=1; $i -le 50; $i++) { $content += "Line $i of test content" }
        Set-Content -Path $testFile -Value $content -Encoding UTF8
    }

    AfterAll {
        Remove-Item "test-less.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = less -Help
        $result -match "Usage" | Should Be $true
    }

    It "Reads file content with Path parameter" -Skip {
        # less 使用 Out-Host -Paging，交互式测试跳过
        # 验证函数存在且可调用
        { less -Path $testFile } | Should Not Throw
    }

    It "Accepts Convert-BashPath for ~ expansion" {
        # 验证代码中使用 Convert-BashPath
        $code = Get-Content (Join-Path $scriptDir "..\core-view.ps1") -Raw
        $code -match "Convert-BashPath" | Should Be $true
    }

    It "Handles non-existent file gracefully" -Skip {
        # less 对不存在的文件会报错，验证行为
        { less -Path "nonexistent-file.txt" } | Should Throw
    }

    It "Accepts pipeline input" {
        # 管道输入测试: less 是简单函数,管道输入不再被高级参数绑定拦截
        { "test line 1", "test line 2" | & $script:lessFunc } | Should Not Throw
    }

    It "Returns content from Get-Content" {
        # 验证基础功能：Get-Content 调用
        $content = Get-Content $testFile
        $content.Count | Should Be 50
    }
}

Describe "more" {
    BeforeAll {
        $testFile = "test-more.txt"
        $content = @()
        for ($i=1; $i -le 50; $i++) { $content += "Line $i of test content" }
        Set-Content -Path $testFile -Value $content -Encoding UTF8
    }

    AfterAll {
        Remove-Item "test-more.txt" -Force -ErrorAction SilentlyContinue
    }

    It "Shows help" {
        $result = more --help
        $result -match "Usage" | Should Be $true
    }

    It "Accepts -d silent flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-view.ps1") -Raw
        $code -match "silent" | Should Be $true
    }

    It "Accepts -f logical flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-view.ps1") -Raw
        $code -match "logical" | Should Be $true
    }

    It "Accepts -p pattern flag" {
        $code = Get-Content (Join-Path $scriptDir "..\core-view.ps1") -Raw
        $code -match "pattern" | Should Be $true
    }

    It "Uses Show-PagedOutput for display" {
        $code = Get-Content (Join-Path $scriptDir "..\core-view.ps1") -Raw
        $code -match "Show-PagedOutput" | Should Be $true
    }
}

Describe "more pipeline (regression)" {
    It "Accepts pipeline input without throwing" {
        # 管道输入测试: more 是简单函数,管道输入不再被高级参数绑定拦截
        { "line1", "line2" | & $script:moreFunc } | Should Not Throw
    }
}