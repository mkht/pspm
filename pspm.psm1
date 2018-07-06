#Requires -Version 4

$modulePath = $PSScriptRoot
$classPath = '/Class'
$functionsPath = '/functions'

#region Load Class Libraries
$DllList = @(
    '/bin/SemVer.dll'
)

$DllList | ForEach-Object {
    Add-Type -Path (Join-Path (Join-Path $modulePath $classPath) $_)
}
#endregion Load Class Libraries

#region Load functions
$FunctionList = @(
    'Test-IsWindows.ps1'
    'Test-AdminPrivilege.ps1'
    'Format-Json.ps1'
    'Get-PackageJson.ps1'
    'Get-PSModulePath.ps1'
    'Get-ModuleInfo.ps1'
    'getModule.ps1'
    'pspm.ps1'
)

$FunctionList | ForEach-Object {
    . (Join-Path (Join-Path $modulePath $functionsPath) $_)
}
#endregion Load functions

& (Join-Path (Join-Path $modulePath $functionsPath) 'Test-PowerShellGetVersion.ps1')

Export-ModuleMember -Function pspm
