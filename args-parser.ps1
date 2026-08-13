# args-parser.ps1
# Bash-style argument parser for PowerShell

function Parse-BashArgs {
    param(
        [string[]]$ArgsArray,
        [hashtable]$OptionSpec
    )

    $result = @{
        Options = @{}
        LongOptions = @{}
        Positional = @()
        Errors = @()
    }

    $i = 0
    while ($i -lt $ArgsArray.Count) {
        $arg = $ArgsArray[$i]

        if ($arg.StartsWith('--')) {
            $longPart = $arg.Substring(2)
            $longName = $longPart
            $value = $null
            $hasValue = $false

            if ($longPart.Contains('=')) {
                $eqIndex = $longPart.IndexOf('=')
                $longName = $longPart.Substring(0, $eqIndex)
                $value = $longPart.Substring($eqIndex + 1)
                $hasValue = $true
            }

            foreach ($key in $OptionSpec.Keys) {
                if ($OptionSpec[$key].Long -eq $longName) {
                    $spec = $OptionSpec[$key]
                    if ($spec.Type -eq 'value') {
                        if ($hasValue) {
                            $result.Options[$key] = $value
                            $result.LongOptions[$longName] = $value
                        } elseif ($i + 1 -lt $ArgsArray.Count) {
                            $i++
                            $result.Options[$key] = $ArgsArray[$i]
                            $result.LongOptions[$longName] = $ArgsArray[$i]
                        }
                    } else {
                        $result.Options[$key] = $true
                        $result.LongOptions[$longName] = $true
                    }
                    break
                }
            }
            $i++
        }
        elseif ($arg.StartsWith('-') -and $arg.Length -gt 1) {
            $flags = $arg.Substring(1)

            # Check if the whole flags string matches a spec key directly
            # (e.g., -name, -type in find command)
            $wholeMatchKey = $null
            foreach ($key in $OptionSpec.Keys) {
                if ($key -eq $flags) {
                    $wholeMatchKey = $key
                    break
                }
            }

            if ($wholeMatchKey) {
                # Whole -word matches a spec key (e.g., -name, -type)
                if ($OptionSpec[$wholeMatchKey].Type -eq 'value') {
                    if ($i + 1 -lt $ArgsArray.Count -and $ArgsArray[$i + 1] -notmatch '^-') {
                        $i++
                        $value = $ArgsArray[$i]
                        $result.Options[$wholeMatchKey] = $value
                        if ($OptionSpec[$wholeMatchKey].Long) {
                            $result.LongOptions[$OptionSpec[$wholeMatchKey].Long] = $value
                        }
                    } else {
                        # Next arg is a flag, treat as switch
                        $result.Options[$wholeMatchKey] = $true
                        if ($OptionSpec[$wholeMatchKey].Long) {
                            $result.LongOptions[$OptionSpec[$wholeMatchKey].Long] = $true
                        }
                    }
                } else {
                    $result.Options[$wholeMatchKey] = $true
                    if ($OptionSpec[$wholeMatchKey].Long) {
                        $result.LongOptions[$OptionSpec[$wholeMatchKey].Long] = $true
                    }
                }
                $i++
                continue
            }

            # Check for single flag with value (e.g., -o file)
            if ($flags.Length -eq 1) {
                $matchedKey = $null
                # Check if flag matches a Short attribute
                foreach ($key in $OptionSpec.Keys) {
                    if ($OptionSpec[$key].Short -eq $flags) {
                        $matchedKey = $key
                        break
                    }
                }
                # Also check direct key match
                if (-not $matchedKey -and $OptionSpec.ContainsKey($flags)) {
                    $matchedKey = $flags
                }

                if ($matchedKey -and $OptionSpec[$matchedKey].Type -eq 'value') {
                    if ($i + 1 -lt $ArgsArray.Count -and $ArgsArray[$i + 1] -notmatch '^-') {
                        $i++
                        $value = $ArgsArray[$i]
                        $result.Options[$matchedKey] = $value
                        if ($OptionSpec[$matchedKey].Long) {
                            $result.LongOptions[$OptionSpec[$matchedKey].Long] = $value
                        }
                    } else {
                        # Next arg is a flag, treat as switch
                        $result.Options[$matchedKey] = $true
                        if ($OptionSpec[$matchedKey].Long) {
                            $result.LongOptions[$OptionSpec[$matchedKey].Long] = $true
                        }
                    }
                    $i++
                    continue
                }
            }

            for ($j = 0; $j -lt $flags.Length; $j++) {
                $flag = [string]$flags[$j]
                $matchedKey = $null
                # Check if flag matches a Short attribute
                foreach ($key in $OptionSpec.Keys) {
                    if ($OptionSpec[$key].Short -eq $flag) {
                        $matchedKey = $key
                        break
                    }
                }
                # Also check direct key match
                if (-not $matchedKey -and $OptionSpec.ContainsKey($flag)) {
                    $matchedKey = $flag
                }

                if ($matchedKey) {
                    $result.Options[$matchedKey] = $true
                    if ($OptionSpec[$matchedKey].Long) {
                        $result.LongOptions[$OptionSpec[$matchedKey].Long] = $true
                    }
                }
            }
            $i++
        }
        else {
            # Skip empty/whitespace args: `@() + $null` yields a $null element in PS 5.1,
            # which [string[]] coercion turns into '', so a no-arg call would otherwise
            # produce an empty positional that breaks bare `ls` (it silently skips '').
            if (-not [string]::IsNullOrWhiteSpace($arg)) {
                $result.Positional += $arg
            }
            $i++
        }
    }

    return $result
}

function Get-PipelineInput {
    param(
        [object]$InputObject,
        [string[]]$PathParams
    )

    if ($InputObject -and ($InputObject | Measure-Object).Count -gt 0) {
        return @{ Source = 'pipeline'; Data = @($InputObject) }
    }
    elseif ($PathParams.Count -gt 0) {
        return @{ Source = 'file'; Paths = $PathParams }
    }
    return @{ Source = 'none' }
}

function Write-BashError {
    param(
        [string]$Command,
        [string]$Message
    )
    Write-Error "${Command}: $Message" -ErrorAction Continue
}
