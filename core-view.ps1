function less {
    param([string]$Path, [switch]$Help)
    if ($Help) { return 'Usage: less FILE' }
    $content = if ($Path) { Get-Content (Convert-BashPath $Path) } else { $input }
    $content | Out-Host -Paging
}
