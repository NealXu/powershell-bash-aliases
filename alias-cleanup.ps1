# alias-cleanup.ps1
# Removes PowerShell's built-in aliases that would shadow this module's
# functions (cd, ls, cat, rm, cp, mv, ps, kill, wget, sort, ping, curl, echo,
# env, diff). These built-ins carry the AllScope/ReadOnly attribute.
#
# This script runs in the CALLER's environment via the module manifest's
# ScriptsToProcess, BEFORE the RootModule is loaded. That is the key: in PS 5.1
# a module's own scope CANNOT remove global AllScope built-in aliases (the
# psm1's Remove-Item loop is a silent no-op for them), but the caller's session
# state CAN. So this is the authoritative cleanup that makes the module
# functions win over alias precedence after Import-Module bash-aliases.
#
# AllScope aliases exist as a physical copy in EVERY active scope, so a single
# Remove-Item only clears the current scope's copy. Walk the scope chain
# (0 = current, 1 = parent, ... = Global) and remove the alias from each scope,
# which makes the fix work whether the import happens at the console/prompt
# (global scope) or from a script/test (a child scope).
#
# Note: "Alias:$a" (not "Global:Alias:$a") is the valid Remove-Item path syntax;
# a "Global:" drive prefix is not a valid provider path.

$aliases = @('cd','ls','cat','rm','cp','mv','ps','kill','wget','sort','ping','curl','echo','env','diff')

foreach ($a in $aliases) {
    # Remove the alias from every active scope up to (and including) Global.
    # Get-Alias -Scope N throws once N is beyond the active scope count, which
    # ends the walk. AllScope guarantees the alias exists in every active scope,
    # so each iteration removes one physical copy.
    for ($sc = 0; ; $sc++) {
        try {
            $null = Get-Alias $a -Scope $sc -ErrorAction Stop
        } catch {
            break
        }
        Remove-Item "Alias:$a" -Force -ErrorAction SilentlyContinue
    }
}
