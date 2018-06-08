function pspm {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param
    (
        # Command name (version / install / run)
        [Parameter(Mandatory = $false, ParameterSetName = 'Version')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Default')]
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'Run')]
        [string]
        $Command,

        # Name of Package (install) or Name of script (run)
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

        [Parameter(ParameterSetName = 'Run')]
        [string[]]
        $Arguments,

        [Parameter(ParameterSetName = 'Run')]
        [switch]
        $IfPresent,

        [Parameter(ParameterSetName = 'Version')]
        [alias('v')]
        [switch]
        $Version
    )

    #region Variable Initialize
    $script:ModuleRoot = Split-Path -Parent $PSScriptRoot
    $script:CurrentDir = Convert-Path .
    $script:ModuleDir = (Join-path $CurrentDir '/Modules')
    $script:UserPSModulePath = Get-PSModulePath -Scope User
    $script:GlobalPSModulePath = Get-PSModulePath -Scope Global
    #endregion Variable Initialize

    # pspm -v
    if (($Command -eq 'version') -or ($PSCmdlet.ParameterSetName -eq 'Version')) {
        
        pspm-version
        
        return
    }

    # pspm install
    elseif ($Command -eq 'Install') {
        [HashTable]$private:param = @{
            Name = $Name
        }
        if ($Scope) {$private:param.Add('Scope', $Scope)}
        if ($Global) {$private:param.Add('Global', $Global)}
        if ($Save) {$private:param.Add('Save', $Save)}
        if ($Clean) {$private:param.Add('Clean', $Clean)}

        # run preinstall script
        pspm-run -CommandName 'preinstall' -IfPresent

        # main
        pspm-install @param
        
        # run install script
        pspm-run -CommandName 'install' -IfPresent
        
        # run postinstall script
        pspm-run -CommandName 'postinstall' -IfPresent

        return
    }

    # pspm uninstall
    elseif ($Command -eq 'uninstall') {
        [HashTable]$private:param = @{
            Name = $Name
        }
        if ($Scope) {$private:param.Add('Scope', $Scope)}
        if ($Global) {$private:param.Add('Global', $Global)}
        if ($Save) {$private:param.Add('Save', $Save)}

        # run preuninstall script
        pspm-run -CommandName 'preuninstall' -IfPresent
        
        # run uninstall script
        pspm-run -CommandName 'uninstall' -IfPresent

        # main
        pspm-uninstall @param

        # run postuninstall script
        pspm-run -CommandName 'postuninstall' -IfPresent

        return
    }

    # pspm run
    elseif (($Command -eq 'run') -or ($Command -eq 'run-script')) {
        [HashTable]$private:param = @{
            CommandName = $Name
            Arguments   = $Arguments
            IfPresent   = $IfPresent
        }

        # run pre script
        pspm-run -CommandName ('pre' + $Name) -IfPresent

        # run main script
        pspm-run @param

        # run post script
        pspm-run -CommandName ('post' + $Name) -IfPresent

        return
    }

    # pspm run (preserved name)
    elseif (('start', 'restart', 'stop', 'test') -eq $Command) {
        [HashTable]$private:param = @{
            CommandName = $Command
            Arguments   = $Arguments
            IfPresent   = $IfPresent
        }
        # run pre script
        pspm-run -CommandName ('pre' + $Command) -IfPresent

        # run main script
        pspm-run @param

        # run post script
        pspm-run -CommandName ('post' + $Command) -IfPresent

        return
    }

    else {
        Write-Error ('Unsupported command: {0}' -f $Command)
    }
}


function pspm-version {
    [CmdletBinding()]
    [OutputType('string')]
    param()

    $local:ModuleRoot = $script:ModuleRoot
        
    # Get version of myself
    $owmInfo = Import-PowerShellDataFile -LiteralPath (Join-Path -Path $local:ModuleRoot -ChildPath 'pspm.psd1')
    [string]($owmInfo.ModuleVersion)
    return
}


function pspm-install {
    [CmdletBinding()]
    param
    (
        [Parameter()]
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
        [switch]$Clean
    )

    $local:ModuleDir = $script:ModuleDir
    $local:CurrentDir = $script:CurrentDir
   
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
    
            $local:ModuleDir = $script:GlobalPSModulePath
        }
        elseif ($Scope -eq 'CurrentUser') {
            $local:ModuleDir = $script:UserPSModulePath
        }
    }
    #endregion
    
    Write-Host ('Modules will be saved in "{0}"' -f $local:ModuleDir)
    if (-Not (Test-Path $local:ModuleDir)) {
        New-Item -Path $local:ModuleDir -ItemType Directory
    }
    elseif ($Clean) {
        Get-ChildItem -Path $local:ModuleDir -Directory | Remove-Item -Recurse -Force
    }
    
    # Install from Name
    if (-not [String]::IsNullOrEmpty($Name)) {
        try {
            $local:targetModule = getModule -Version $Name -Path $local:ModuleDir -ErrorAction Stop
    
            if ($local:targetModule) {
                Write-Host ('{0}@{1}: Importing module.' -f $local:targetModule.Name, $local:targetModule.ModuleVersion)
                Import-Module (Join-path $local:ModuleDir $local:targetModule.Name) -Force -Global -ErrorAction Stop
    
                if ($Save) {
                    if ($PackageJson = (Get-PackageJson -ErrorAction SilentlyContinue)) {
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
                    $PackageJson | ConvertTo-Json | Format-Json | Out-File -FilePath (Join-path $local:CurrentDir '/package.json') -Force -Encoding utf8
                }
            }
        }
        catch {
            Write-Error ('{0}: {1}' -f $Name, $_.Exception.Message)
        }
    }
    # Install from package.json
    elseif ($PackageJson = (Get-PackageJson -ErrorAction SilentlyContinue)) {
        $PackageJson.dependencies | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue | `
            ForEach-Object {
            $local:moduleName = $_.Name
            $local:moduleVersion = $PackageJson.dependencies.($_.Name)
    
            try {
                $local:targetModule = getModule -Name $local:moduleName -Version $local:moduleVersion -Path $local:ModuleDir -ErrorAction Stop
                    
                if ($local:targetModule) {
                    Write-Host ('{0}@{1}: Importing module.' -f $local:targetModule.Name, $local:targetModule.ModuleVersion)
                    Import-Module (Join-path $local:ModuleDir $local:targetModule.Name) -Force -Global -ErrorAction Stop
                }
            }
            catch {
                Write-Error ('{0}: {1}' -f $local:moduleName, $_.Exception.Message)
            }
        }
    }
    else {
        Write-Error ('Could not find package.json in the current directory')
        return
    }
}


function pspm-uninstall {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string[]]
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
        $Save
    )

    $local:ModuleDir = $script:ModuleDir
    $local:CurrentDir = $script:CurrentDir
   
    #region Scope parameter
    if ($Global) {
        $Scope = 'Global'
    }
    
    if ($Scope) {
        if ($Scope -eq 'Global') {
            #Check for Admin Privileges (only Windows)
            if (-not (Test-AdminPrivilege)) {
                throw [System.InvalidOperationException]::new('Administrator rights are required to uninstall modules in "{0}"' -f $GlobalPSModulePath)
                return
            }
    
            $local:ModuleDir = $script:GlobalPSModulePath
        }
        elseif ($Scope -eq 'CurrentUser') {
            $local:ModuleDir = $script:UserPSModulePath
        }
    }
    #endregion
    
    Write-Host ('Modules will be removed from "{0}"' -f $local:ModuleDir)
    
    # Uninstall from Name
    $AllModules = Get-ChildItem -Path $local:ModuleDir -Directory -ErrorAction SilentlyContinue
    $AllModuleInfos = $AllModules | ForEach-Object {Get-ModuleInfo -Path $_.Fullname -ErrorAction SilentlyContinue}

    @($Name).ForEach(
        {
            $targetName = $_.Split("@")[0]
            # $targetVersion = $_.Split("@")[1]

            if ($targetModule = ($AllModuleInfos | Where-Object {$targetName -eq $_.Name})) {
                Write-Host ('{0}@{1}: Removing module.' -f $targetModule.Name, $targetModule.ModuleVersion)

                Remove-Module -Name $targetModule -Force -ErrorAction SilentlyContinue
                $AllModules | Where-Object {$_.Name -eq $targetModule.Name} | Remove-Item -Recurse -Force
            }
            else {
                # Which is better, error or warning ?
                Write-Warning ('Module "{0}" not found in "{1}"' -f $targetName, $local:ModuleDir)
            }

            if ($Save) {
                $PackageJson = (Get-PackageJson -ErrorAction SilentlyContinue)
                if ($PackageJson -and $PackageJson.dependencies) {
                    if ($PackageJson.dependencies | gm -Type NoteProperty -Name $targetName) {
                        $PackageJson.dependencies.PSObject.Members.Remove($targetName)
                        $PackageJson | ConvertTo-Json | Format-Json | Out-File -FilePath (Join-path $local:CurrentDir 'package.json') -Force -Encoding utf8
                    }
                    else {
                        Write-Warning ('Entry "{0}" not found in package.json dependencies' -f $targetName)
                    }
                }
                else {
                    Write-Warning ('Could not find package.json or dependencies entry')
                }
            }
        }
    )
}


function pspm-run {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory)]
        [string]
        $CommandName,

        [Parameter()]
        [string[]]
        $Arguments,

        [Parameter()]
        [switch]
        $IfPresent
    )

    $local:ModuleDir = $script:ModuleDir
    $local:CurrentDir = $script:CurrentDir

    if ($PackageJson = (Get-PackageJson -ErrorAction SilentlyContinue)) {
        if ($PackageJson.scripts | Get-Member -MemberType NoteProperty -ErrorAction SilentlyContinue | Where-Object {$_.Name -eq $CommandName}) {
            try {
                $local:ScriptBlock = [scriptblock]::Create($PackageJson.scripts.($CommandName))
                $local:ScriptBlock.Invoke($Arguments)
            }
            finally {
                Set-Location -Path $local:CurrentDir
            }
        }
        else {
            if (-not $IfPresent) {
                Write-Error ('The script "{0}" is not defined in package.json' -f $CommandName)
            }
        }
    }
    else {
        if (-not $IfPresent) {
            Write-Error ('Could not find package.json in the current directory')
            return
        }
    }
}
