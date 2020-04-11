#Requires -Version 4

$modulePath = $PSScriptRoot
$classPath = '/Class'
$functionsPath = '/functions'

#region Enable TLS1.2 in the current session (if not supported)
if (([Net.ServicePointManager]::SecurityProtocol -ne [Net.SecurityProtocolType]::SystemDefault) -and (-not ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12))) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    Write-Verbose ('TLS 1.2 is enabled in the current session')
}
#endregion

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
    'GitHubUtils.ps1'
    'getModule.ps1'
    'pspm.ps1'
)

$FunctionList | ForEach-Object {
    . (Join-Path (Join-Path $modulePath $functionsPath) $_)
}
#endregion Load functions

& (Join-Path (Join-Path $modulePath $functionsPath) 'Test-PowerShellGetVersion.ps1')

Export-ModuleMember -Function pspm
