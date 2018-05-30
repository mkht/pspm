function Test-AdminPrivilege {
    [CmdletBinding()]
    [OutputType('System.Boolean')]
    Param
    (
    )

    # Test Windows or Not
    if (IsWindows) {
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

function IsWindows {
    [System.Runtime.InteropServices.RuntimeInformation]::IsOSPlatform([System.Runtime.InteropServices.OSPlatform]::Windows)
}
