# tests/test-install-profile.ps1
# TDD tests: Set-BashAliasesProfilePreamble (profile-setup.ps1) writes an
# idempotent bash-aliases preamble to a profile, replacing any stale/duplicated
# preamble blocks and preserving the user's own lines verbatim.
# Pester 3.4.0, Windows PowerShell 5.1. ASCII-only.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir '..\profile-setup.ps1')

# Old stale preamble, exactly like the real user profile that accumulated
# duplicates: only 10 aliases (missing cd, curl, echo, env, diff).
$oldBlock = @(
    '# Bash-aliases module - remove conflicting aliases before import',
    "foreach (`$a in @('ls','cat','rm','cp','mv','ps','kill','sort','ping','wget')) { Remove-Item Alias:`$a -Force -ErrorAction SilentlyContinue }",
    'Import-Module bash-aliases -Force -ErrorAction SilentlyContinue'
)

function New-TempProfile {
    param([string[]]$Lines)
    $p = Join-Path $env:TEMP ("alias-profile-" + [guid]::NewGuid().ToString('N') + '.ps1')
    Set-Content -Path $p -Value $Lines -Encoding UTF8
    return $p
}

Describe "Set-BashAliasesProfilePreamble" {

    It "dedupes a stale preamble duplicated 4x and preserves the custom line" {
        $content = @()
        for ($i = 0; $i -lt 4; $i++) { $content += $oldBlock }
        $content += 'function cdcodes { Set-Location D:\Codes }'
        $profile = New-TempProfile $content

        Set-BashAliasesProfilePreamble -ProfilePath $profile

        $after = @(Get-Content $profile)
        $importCount = @($after | Where-Object { $_ -match '^Import-Module bash-aliases' }).Count
        $importCount | Should Be 1
        $after | Where-Object { $_ -match 'function cdcodes' } | Should Be 'function cdcodes { Set-Location D:\Codes }'
        Remove-Item $profile -Force -ErrorAction SilentlyContinue
    }

    It "is idempotent: a second call still yields exactly one preamble" {
        $content = @()
        for ($i = 0; $i -lt 4; $i++) { $content += $oldBlock }
        $profile = New-TempProfile $content

        Set-BashAliasesProfilePreamble -ProfilePath $profile
        Set-BashAliasesProfilePreamble -ProfilePath $profile

        $after = @(Get-Content $profile)
        $importCount = @($after | Where-Object { $_ -match '^Import-Module bash-aliases' }).Count
        $importCount | Should Be 1
        Remove-Item $profile -Force -ErrorAction SilentlyContinue
    }

    It "writes the full alias list (cd, echo, diff that the old preamble lacked)" {
        $content = @()
        for ($i = 0; $i -lt 2; $i++) { $content += $oldBlock }
        $profile = New-TempProfile $content

        Set-BashAliasesProfilePreamble -ProfilePath $profile

        $foreachLine = @(Get-Content $profile | Where-Object { $_ -match 'Remove-Item Alias' })[0]
        $foreachLine | Should Match 'cd'
        $foreachLine | Should Match 'ls'
        $foreachLine | Should Match 'cat'
        $foreachLine | Should Match 'echo'
        $foreachLine | Should Match 'diff'
        Remove-Item $profile -Force -ErrorAction SilentlyContinue
    }

    It "removes a block whose marker is the first line and also a mid-file block" {
        $content = @()
        $content += $oldBlock  # marker is the first line
        $content += 'function cdcodes { Set-Location D:\Codes }'
        $content += $oldBlock  # mid-file block
        $profile = New-TempProfile $content

        Set-BashAliasesProfilePreamble -ProfilePath $profile

        $after = @(Get-Content $profile)
        $markerCount = @($after | Where-Object { $_ -match '^# Bash-aliases module' }).Count
        $markerCount | Should Be 1
        $after | Where-Object { $_ -match 'function cdcodes' } | Should Be 'function cdcodes { Set-Location D:\Codes }'
        Remove-Item $profile -Force -ErrorAction SilentlyContinue
    }

    It "creates the file when it does not exist" {
        $profile = Join-Path $env:TEMP ("alias-profile-new-" + [guid]::NewGuid().ToString('N') + '.ps1')
        try {
            Set-BashAliasesProfilePreamble -ProfilePath $profile

            Test-Path $profile | Should Be $true
            $importCount = @(Get-Content $profile | Where-Object { $_ -match '^Import-Module bash-aliases' }).Count
            $importCount | Should Be 1
        } finally {
            Remove-Item $profile -Force -ErrorAction SilentlyContinue
        }
    }

    It "preserves user lines when a preamble block is unterminated (no Import-Module terminator)" {
        $content = @(
            '# Bash-aliases module - remove conflicting aliases before import',
            '# user line after a crashed/partial append',
            'function keepme { ''x'' }'
        )
        $profile = New-TempProfile $content

        Set-BashAliasesProfilePreamble -ProfilePath $profile

        $after = @(Get-Content $profile)
        # Every original line is still present - user data is NOT lost.
        $after | Where-Object { $_ -eq '# user line after a crashed/partial append' } | Should Be '# user line after a crashed/partial append'
        $after | Where-Object { $_ -match 'function keepme' } | Should Be 'function keepme { ''x'' }'
        # The stale marker line is preserved along with the buffered lines.
        $after | Where-Object { $_ -eq '# Bash-aliases module - remove conflicting aliases before import' } | Should Be '# Bash-aliases module - remove conflicting aliases before import'
        # And the fresh preamble is still appended exactly once.
        $importCount = @($after | Where-Object { $_ -match '^Import-Module bash-aliases' }).Count
        $importCount | Should Be 1
        Remove-Item $profile -Force -ErrorAction SilentlyContinue
    }
}
