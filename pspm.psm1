#Requires -Version 4

$modulePath = $PSScriptRoot
$classPath = '/Class'
$functionsPath = '/functions'

#region Load Class Libraries
$DllList = @(
    '/bin/SemVer.dll'
)

$DllList | foreach {
    $private:csharp = Get-Content -Path (Join-Path (Join-Path $modulePath $classPath) $_) -Raw
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

$FunctionList | foreach {
    . (Join-Path (Join-Path $modulePath $functionsPath) $_)
}
#endregion Load functions


#region Update $env:PSModulePath
[string]$tmpModulePath = Join-Path $pwd.Path '/Modules'
[string]$oldPSModulePath = $env:PSModulePath

$oldPSModulePathArray = $oldPSModulePath.Split(';')

if ($oldPSModulePathArray -ccontains $tmpModulePath) {
    $newPSModulePathArray = $oldPSModulePathArray | Where-Object {$_ -ne $tmpModulePath}
    $newPSModulePath = $newPSModulePathArray -join ';'
}
else {
    $newPSModulePath = $oldPSModulePath
}

$newPSModulePath = ($tmpModulePath, $newPSModulePath) -join ';'
$env:PSModulePath = $newPSModulePath
#endregion Update $env:PSModulePath


Export-ModuleMember -Function pspm
