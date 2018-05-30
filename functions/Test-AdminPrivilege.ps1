function Test-AdminPrivilege {
    [CmdletBinding()]
    [OutputType('System.Boolean')]
    Param
    (
    )

    # Except Windows, always return $true
    if ($PSVersionTable.PSVersion -ge '6.0') {
        if (-not $IsWindows) {
            return $true
        }
    }

    $local:user = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object -TypeName 'Security.Principal.WindowsPrincipal' -ArgumentList $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}