#Requires -Version 4

$modulePath = $PSScriptRoot
$functionsPath = '\functions'

$FunctionList = @(
    'Format-Json.ps1',
    'Get-ModuleInfo.ps1',
    'getModule.ps1',
    'pspm.ps1'
)

$FunctionList | foreach {
    . (Join-Path (Join-Path $modulePath $functionsPath) $_)
}

Export-ModuleMember -Function pspm