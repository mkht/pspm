$script:WarningMessage = @"
The PowerShellGet module installed in this system is older version. 
We strongly recommend updating to the latest version to improve compatibility and stability.

To update PowerShellGet use the following command and restart PowerShell:
    Install-Module PowerShellGet -Force

"@


$PSGet = Get-PackageProvider -Name PowerShellGet

if (($null -eq $PSGet.Version) -or ($PSGet.Version -lt '1.6.0')) {
    Write-Warning $script:WarningMessage
}
