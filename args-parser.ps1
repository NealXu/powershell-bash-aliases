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

            if ($flags.Length -eq 1 -and $OptionSpec.ContainsKey($flags) -and $OptionSpec[$flags].Type -eq 'value') {
                if ($i + 1 -lt $ArgsArray.Count) {
                    $i++
                    $value = $ArgsArray[$i]
                    $result.Options[$flags] = $value
                    if ($OptionSpec[$flags].Long) {
                        $result.LongOptions[$OptionSpec[$flags].Long] = $value
                    }
                }
                $i++
                continue
            }

            for ($j = 0; $j -lt $flags.Length; $j++) {
                $flag = [string]$flags[$j]
                if ($OptionSpec.ContainsKey($flag)) {
                    $result.Options[$flag] = $true
                    if ($OptionSpec[$flag].Long) {
                        $result.LongOptions[$OptionSpec[$flag].Long] = $true
                    }
                }
            }
            $i++
        }
        else {
            $result.Positional += $arg
            $i++
        }
    }

    return $result
}
