# profile-setup.ps1
# Standalone helper used by install.ps1 -AddToProfile. Provides
# Set-BashAliasesProfilePreamble, which rewrites a PowerShell profile so it
# contains exactly ONE fresh bash-aliases preamble block. It strips every
# existing (possibly stale/duplicated) preamble block and preserves the user's
# own lines verbatim, in order.
# Pester 3.4.0, Windows PowerShell 5.1. ASCII-only.

function Set-BashAliasesProfilePreamble {
    param([string]$ProfilePath)

    $preamble = @(
        '# Bash-aliases module - remove conflicting aliases before import',
        "foreach (`$a in @('cd','ls','cat','rm','cp','mv','ps','kill','sort','ping','wget','curl','echo','env','diff')) { Remove-Item Alias:`$a -Force -ErrorAction SilentlyContinue }",
        'Import-Module bash-aliases -Force -ErrorAction SilentlyContinue'
    )

    # Ensure the target file exists (idempotent create; leaves existing content).
    if (-not (Test-Path $ProfilePath)) {
        $null = New-Item -ItemType File -Path $ProfilePath -Force
    }

    $lines = @(Get-Content -Path $ProfilePath)

    # Strip every preamble block. A block starts at a line whose marker matches
    # '^# Bash-aliases module' and runs through the NEXT 'Import-Module
    # bash-aliases' line (inclusive). Old and duplicated blocks all share this
    # marker, so any number of stale copies are removed in one pass.
    $kept = [System.Collections.Generic.List[string]]::new()
    $inBlock = $false
    foreach ($line in $lines) {
        if ($inBlock) {
            if ($line -match 'Import-Module bash-aliases') {
                $inBlock = $false
            }
            continue
        }
        if ($line -match '^# Bash-aliases module') {
            $inBlock = $true
            continue
        }
        $kept.Add($line)
    }

    # Append the single fresh preamble block.
    foreach ($p in $preamble) {
        $kept.Add($p)
    }

    $kept | Set-Content -Path $ProfilePath -Encoding UTF8
}
