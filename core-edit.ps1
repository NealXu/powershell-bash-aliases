# core-edit.ps1 - vi/vim commands (launch real vim from Git for Windows)

function Resolve-Editor {
    # Editor fallback chain: vim -> $EDITOR -> VS Code (code) -> notepad
    # Get-Command may return multiple ApplicationInfo (e.g. code.cmd + code), so
    # always take the first .Source element to keep the launch unambiguous.
    $vim = Get-Command vim -CommandType Application -ErrorAction SilentlyContinue
    if ($vim) { return @($vim.Source)[0] }

    if ($env:EDITOR) {
        $ed = Get-Command $env:EDITOR -ErrorAction SilentlyContinue
        if ($ed) { return @($ed.Source)[0] }
        if (Test-Path $env:EDITOR) { return $env:EDITOR }
    }

    $code = Get-Command code -CommandType Application -ErrorAction SilentlyContinue
    if ($code) { return @($code.Source)[0] }

    $np = Get-Command notepad -CommandType Application -ErrorAction SilentlyContinue
    if ($np) { return @($np.Source)[0] }

    return $null
}

function Build-VimArgs {
    param([string[]]$ArgList)
    $out = @()
    foreach ($arg in $ArgList) {
        $out += Convert-BashPath $arg
    }
    return $out
}

function vim {
    param([switch]$help)
    $ArgList = @($args)
    if ($help -or ($ArgList -contains '--help') -or ($ArgList -contains '-h')) {
        return 'Usage: vim [-R] [FILE]... [--help]'
    }
    $editor = Resolve-Editor
    if (-not $editor) {
        Write-BashError -Command 'vim' -Message 'no editor found. Install Git for Windows, set $EDITOR, or add vim to PATH.'
        return
    }
    $editorName = Split-Path $editor -Leaf
    if ($editorName -notlike 'vim*') {
        Write-Host "vim not found; using $editorName"
    }
    $vimArgs = Build-VimArgs $ArgList
    & $editor $vimArgs
}

function vi {
    vim @args
}
