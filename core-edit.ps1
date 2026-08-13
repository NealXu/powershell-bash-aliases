# core-edit.ps1 - vi/vim commands (launch real vim from Git for Windows)

function Resolve-Editor {
    $vim = Get-Command vim -CommandType Application -ErrorAction SilentlyContinue
    if ($vim) { return $vim.Source }
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
        Write-BashError -Command 'vim' -Message 'vim not found. Install Git for Windows or add vim to your PATH.'
        return
    }
    $vimArgs = Build-VimArgs $ArgList
    & $editor $vimArgs
}

function vi {
    vim @args
}
