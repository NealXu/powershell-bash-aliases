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
    #
    # Lines consumed inside a block are buffered. A block is only discarded when
    # it is properly terminated by the Import-Module line; if EOF is reached
    # while still inside a block (a partial/crashed append, or a user comment
    # matching the marker), the buffered lines are re-emitted so no user data is
    # silently dropped.
    $kept = [System.Collections.Generic.List[string]]::new()
    $inBlock = $false
    $blockBuffer = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $lines) {
        if ($inBlock) {
            $blockBuffer.Add($line)
            if ($line -match 'Import-Module bash-aliases') {
                $inBlock = $false
                $blockBuffer.Clear()  # properly terminated -> discard the buffer
            }
            continue
        }
        if ($line -match '^# Bash-aliases module') {
            $inBlock = $true
            $blockBuffer.Clear()
            $blockBuffer.Add($line)
            continue
        }
        $kept.Add($line)
    }

    # Unterminated block at EOF: preserve every buffered line.
    if ($inBlock) {
        foreach ($bufLine in $blockBuffer) {
            $kept.Add($bufLine)
        }
    }

    # Append the single fresh preamble block.
    foreach ($p in $preamble) {
        $kept.Add($p)
    }

    $kept | Set-Content -Path $ProfilePath -Encoding UTF8
}
