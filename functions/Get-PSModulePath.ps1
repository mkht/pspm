function Get-PSModulePath {
    [CmdletBinding()]
    [OutputType('string')]
    Param(
        [Parameter()]
        [ValidateSet('All', 'User', 'Global')]
        [string]
        $Scope = 'All'
    )

    # Determine platforms
    if (Test-IsWindows -eq $true) {
        # Windows
        $script:UserPSModulePath = Join-Path ([Environment]::GetFolderPath("MyDocuments")) 'WindowsPowerShell/Modules'
        $script:GlobalPSModulePath = Join-Path $env:ProgramFiles 'WindowsPowerShell/Modules'
    }
    else {
        # Others (MacOS or Linux)
        $script:UserPSModulePath = Join-Path $env:HOME '/.local/share/powershell/Modules'
        $script:GlobalPSModulePath = '/usr/local/share/powershell/Modules'
    }

    # Output
    switch ($Scope) {
        'All' {
            $env:PSModulePath
            break
        }

        'User' {
            $script:UserPSModulePath
            break
        }

        'Global' {
            $script:GlobalPSModulePath
            break
        }
    }
}

