# core-edit.ps1 - vi/vim commands (launch real vim from Git for Windows)

function Get-GitVimPath {
    # vim.exe ships with Git for Windows in usr\bin, but that directory is NOT on
    # the Windows PATH by default (only Git\cmd is), so a Windows-launched
    # PowerShell cannot find it via Get-Command. Locate it via git.exe's install
    # root, then fall back to the standard Program Files locations.
    $roots = @()
    $git = Get-Command git -CommandType Application -ErrorAction SilentlyContinue
    if ($git) { $roots += Split-Path -Parent (Split-Path -Parent @($git.Source)[0]) }
    $roots += (Join-Path ${env:ProgramFiles} 'Git')
    $roots += (Join-Path ${env:ProgramFiles(x86)} 'Git')
    foreach ($root in $roots) {
        $cand = Join-Path $root 'usr\bin\vim.exe'
        if (Test-Path $cand) { return $cand }
    }
    return $null
}

function Resolve-Editor {
    # Editor fallback chain: vim (PATH) -> Git-bundled vim -> $EDITOR ->
    # VS Code (code) -> notepad. Get-Command may return multiple ApplicationInfo
    # (e.g. code.cmd + code), so always take the first .Source element.
    $vim = Get-Command vim -CommandType Application -ErrorAction SilentlyContinue
    if ($vim) { return @($vim.Source)[0] }

    $gitVim = Get-GitVimPath
    if ($gitVim) { return $gitVim }

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
