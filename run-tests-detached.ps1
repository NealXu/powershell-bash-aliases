# run-tests-detached.ps1
# Run the full test suite in the BACKGROUND, detached from the Claude Code CLI.
# The CLI's blue "Processing" bar is only shown while a tool call is running, so
# a ~51 s suite run parks it; spawning a hidden background process makes this
# wrapper return in ~1 s and keeps the CLI responsive. No window is left behind:
# the child runs headless (-WindowStyle Hidden) to completion and exits, and a
# full Start-Transcript log is written to $env:TEMP for later inspection.
# Usage:
#   .\run-tests-detached.ps1            # detached: returns immediately, log path printed
#   .\run-tests-detached.ps1 -Wait      # blocks on the child, then prints a clean summary
# Windows PowerShell 5.1. ASCII-safe.

param(
    [switch]$Wait   # wait for the suite to finish, then print the result summary
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# The wrapper lives AT the repo root, so the repo root is the script's own dir.
$repoRoot  = $scriptDir
$log       = Join-Path $env:TEMP ("bash-aliases-tests-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')

# Start-Transcript (not Tee-Object) is required: run-tests.ps1 and Pester write
# to the host (Write-Host), which never enters the pipeline, so piping cannot
# capture the colored summary. -NoProfile avoids user-profile side effects.
# No -NoExit: the child runs the suite to completion and exits, so no window
# lingers afterward. -WindowStyle Hidden keeps it fully headless.
$childCmd = "Start-Transcript -Path '$log' -Force; Set-Location -LiteralPath '$repoRoot'; .\tests\run-tests.ps1; Stop-Transcript"

$proc = Start-Process powershell.exe -ArgumentList @('-NoProfile', '-Command', $childCmd) -WindowStyle Hidden -WorkingDirectory $repoRoot -PassThru

if (-not $Wait) {
    Write-Output "Test suite started in the background (headless, returns immediately)."
    Write-Output "Transcript log: $log"
    exit 0
}

# -Wait: block on the PROCESS HANDLE (not a poll), then read the transcript once.
$proc.WaitForExit()

# Strip ANSI color codes so Write-Host -ForegroundColor output parses cleanly.
$clean = (Get-Content $log -Raw -ErrorAction SilentlyContinue) -replace "\x1b\[[0-9;]*[A-Za-z]", ""

$total   = if ($clean -match 'Total Tests:\s*(\d+)')     { $matches[1] } else { '?' }
$passed  = if ($clean -match 'Passed:\s*(\d+)')          { $matches[1] } else { '?' }
$failed  = if ($clean -match 'Failed:\s*(\d+)')          { $matches[1] } else { '?' }
$skipped = if ($clean -match 'Skipped:\s*(\d+)')         { $matches[1] } else { '?' }
$coverage= if ($clean -match '= ([\d.]+)%')              { $matches[1] } else { '?' }
$covWarn = if ($clean -match 'failed during the coverage run') { ' (run-2 warning)' } else { '' }

Write-Output "Test Results Summary:"
Write-Output "  Total Tests: $total"
Write-Output "  Passed: $passed"
Write-Output "  Failed: $failed"
Write-Output "  Skipped: $skipped"
Write-Output "  Coverage: $coverage%$covWarn"
Write-Output "Transcript log: $log"

if ($failed -match '^\d+$' -and [int]$failed -gt 0) { exit 1 } else { exit 0 }
