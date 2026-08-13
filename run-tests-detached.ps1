# run-tests-detached.ps1
# Run the full test suite in a SEPARATE PowerShell window, detached from the
# Claude Code CLI. The CLI's blue "Processing" bar is only shown while a tool
# call is running, so a ~51 s suite run parks it; spawning a detached window
# makes this wrapper return in ~1 s and keeps the CLI responsive. The suite runs
# live in its own window and a full Start-Transcript log is written to $env:TEMP
# for later inspection.
# Windows PowerShell 5.1. ASCII-safe.

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
# The wrapper lives AT the repo root, so the repo root is the script's own dir.
$repoRoot  = $scriptDir
$log       = Join-Path $env:TEMP ("bash-aliases-tests-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.log')

# Start-Transcript (not Tee-Object) is required: run-tests.ps1 and Pester write
# to the host (Write-Host), which never enters the pipeline, so piping cannot
# capture the colored summary. -NoProfile avoids user-profile side effects in
# the child; -NoExit keeps the window open so the results stay readable.
$childCmd = "Start-Transcript -Path '$log' -Force; Set-Location -LiteralPath '$repoRoot'; .\tests\run-tests.ps1; Stop-Transcript"

Start-Process powershell.exe -ArgumentList @('-NoProfile', '-NoExit', '-Command', $childCmd) -WorkingDirectory $repoRoot | Out-Null

Write-Output "Test suite started in a separate window (returns immediately)."
Write-Output "Live results are in that window."
Write-Output "Transcript log: $log"
