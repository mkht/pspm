function Test-AdminPrivilege {
    [CmdletBinding()]
    [OutputType('System.Boolean')]
    Param
    (
    )

    # Test Windows or Not
    if (Test-IsWindows) {
        # Check Administrator privilege
        $local:user = 
        try {
            [Security.Principal.WindowsIdentity]::GetCurrent()
        }
        catch {}
        (New-Object -TypeName 'Security.Principal.WindowsPrincipal' -ArgumentList $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
    }
    else {
        # Except Windows, always return $true
        $true
    }
}
