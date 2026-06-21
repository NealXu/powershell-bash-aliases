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

        # 长参数: --option
        if ($arg.StartsWith('--')) {
            $longName = $arg.Substring(2)
            foreach ($key in $OptionSpec.Keys) {
                if ($OptionSpec[$key].Long -eq $longName) {
                    $result.Options[$key] = $true
                    $result.LongOptions[$longName] = $true
                    break
                }
            }
            $i++
        }
        # 短参数: -a 或 -la 组合
        elseif ($arg.StartsWith('-') -and $arg.Length -gt 1) {
            $flags = $arg.Substring(1)
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
        # 位置参数
        else {
            $result.Positional += $arg
            $i++
        }
    }

    return $result
}