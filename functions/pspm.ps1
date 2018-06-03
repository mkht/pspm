function pspm {
    [CmdletBinding(DefaultParameterSetName = 'Install')]
    param
    (
        # Parameter help description
        [Parameter(Position = 0)]
        [string]
        $Command = 'version',

        # Parameter help description
        [Parameter(position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [ValidateSet('Global', 'CurrentUser')]
        [string]
        $Scope,

        [Parameter()]
        [alias('g')]
        [switch]
        $Global,

        [Parameter()]
        [alias('s')]
        [switch]
        $Save,

        [Parameter()]
        [switch]$Clean,

        [Parameter(ParameterSetName = 'Version')]
        [alias('v')]
        [switch]
        $Version
    )

    #region Initialize
    $script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:CurrentDir = Convert-Path .
    $script:ModuleDir = (Join-path $CurrentDir '/Modules')
    $script:UserPSModulePath = Get-PSModulePath -Scope User
    $script:GlobalPSModulePath = Get-PSModulePath -Scope Global
    #endregion

    # Get version of myself
    if (($Command -eq 'version') -or ($PSCmdlet.ParameterSetName -eq 'Version')) {
        $owmInfo = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $script:ModuleRoot -ChildPath 'pspm.psd1')
        [string]($owmInfo.ModuleVersion)
        return
    }

    #region Scope parameter
    if ($Global) {
        $Scope = 'Global'
    }

    if ($Scope) {
        if ($Clean) {
            Write-Warning ("You can't use '-Clean' with '-Scope'")
            $Clean = $false
        }

        if ($Scope -eq 'Global') {
            #Check for Admin Privileges (only Windows)
            if (-not (Test-AdminPrivilege)) {
                throw [System.InvalidOperationException]::new('Administrator rights are required to install modules in "{0}"' -f $GlobalPSModulePath)
                return
            }

            $ModuleDir = $GlobalPSModulePath
        }
        elseif ($Scope -eq 'CurrentUser') {
            $ModuleDir = $UserPSModulePath
        }
    }
    #endregion

    Write-Host ('Modules will be saved in "{0}"' -f $ModuleDir)
    if (-Not (Test-Path $ModuleDir)) {
        New-Item -Path $ModuleDir -ItemType Directory
    }
    elseif ($Clean) {
        Get-ChildItem -Path $ModuleDir -Directory | Remove-Item -Recurse -Force
    }

    # Install from Name
    if (($PSCmdlet.ParameterSetName -eq 'Install') -and (-not [String]::IsNullOrEmpty($Name))) {
        try {
            $local:targetModule = getModule -Version $Name -Path $ModuleDir -ErrorAction Stop

            if ($local:targetModule) {
                Write-Host ('{0}@{1}: Importing module.' -f $local:targetModule.Name, $local:targetModule.ModuleVersion)
                Import-Module (Join-path $ModuleDir $local:targetModule.Name) -Force -Global -ErrorAction Stop

                if ($Save) {
                    if (Test-Path (Join-path $CurrentDir '/package.json')) {
                        $PackageJson = Get-Content -Path (Join-path $CurrentDir '/package.json') -Raw | ConvertFrom-Json
                        if (-Not $PackageJson.dependencies) {
                            $PackageJson | Add-Member -NotePropertyName 'dependencies' -NotePropertyValue ([PSCustomObject]@{})
                        }
                    }
                    else {
                        $PackageJson = [PSCustomObject]@{
                            dependencies = [PSCustomObject]@{}
                        }
                    }

                    $PackageJson.dependencies | Add-Member -NotePropertyName $local:targetModule.Name -NotePropertyValue ([string]$local:targetModule.ModuleVersion) -Force
                    $PackageJson | ConvertTo-Json | Format-Json | Out-File -FilePath (Join-path $CurrentDir '/package.json') -Force -Encoding utf8
                }
            }
        }
        catch {
            Write-Error ('{0}: {1}' -f $Name, $_.Exception.Message)
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Install') {
        if (Test-Path (Join-path $CurrentDir '/package.json')) {
            $PackageJson = Get-Content -Path (Join-path $CurrentDir '/package.json') -Raw | ConvertFrom-Json
            
            $PackageJson.dependencies | Get-Member -MemberType NoteProperty | `
                ForEach-Object {
                $local:moduleName = $_.Name
                $local:moduleVersion = $PackageJson.dependencies.($_.Name)

                try {
                    $local:targetModule = getModule -Name $local:moduleName -Version $local:moduleVersion -Path $ModuleDir -ErrorAction Stop
                
                    if ($local:targetModule) {
                        Write-Host ('{0}@{1}: Importing module.' -f $local:targetModule.Name, $local:targetModule.ModuleVersion)
                        Import-Module (Join-path $ModuleDir $local:targetModule.Name) -Force -Global -ErrorAction Stop
                    }
                }
                catch {
                    Write-Error ('{0}: {1}' -f $local:moduleName, $_.Exception.Message)
                }
            }
        }
        else {
            Write-Error ('Cloud not find package.json in the current directory')
            return
        }
    }
}

