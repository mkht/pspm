function pspm {
    [CmdletBinding(DefaultParameterSetName = 'Json')]
    param
    (
        # Parameter help description
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Command = 'install',

        # Parameter help description
        [Parameter(position = 1, ParameterSetName = 'ModuleName')]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,

        [Parameter()]
        [switch]$Clean
    )

    #region Initialize
    $script:moduleRoot = Split-Path -Parent $PSScriptRoot
    $script:currentDir = Convert-Path .
    $script:moduleDir = (Join-path $currentDir '\Modules')
    #endregion

    #region load package.json
    if (Test-Path (Join-path $currentDir '\package.json')) {
        $PackageJsonFile = Convert-Path (Join-path $currentDir '\package.json') -ErrorAction Stop
        $PackageJson = Get-Content $PackageJsonFile -Raw | ConvertFrom-Json
    }
    #endregion

    if (-Not (Test-Path $moduleDir)) {
        New-Item -Path $moduleDir -ItemType Directory
    }
    elseif ($Clean) {
        Get-ChildItem -Path $moduleDir -Directory | Remove-Item -Recurse -Force
    }

    if ($PSCmdlet.ParameterSetName -eq 'ModuleName') {
        $moduleName = $Name.Split("@")[0]
        $version = $Name.Split("@")[1]

        getModule -Name $moduleName -RequiredVersion $version -Path $moduleDir

        $local:moduleInfo = Get-ModuleInfo -Path (Join-path $moduleDir $moduleName) -ErrorAction SilentlyContinue

        Write-Host ('{0}@{1}: Importing module.' -f $moduleName, $moduleInfo.ModuleVersion)
        Import-Module (Join-path $moduleDir $moduleName) -Force -Global
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Json') {
        $PackageJson.dependencies | Get-Member -MemberType NoteProperty | `
            ForEach-Object {
            $moduleName = $_.Name
            $version = $PackageJson.dependencies.($_.Name)

            getModule -Name $moduleName -RequiredVersion $version -Path $moduleDir

            $local:moduleInfo = Get-ModuleInfo -Path (Join-path $moduleDir $moduleName) -ErrorAction SilentlyContinue

            Write-Host ('{0}@{1}: Importing module.' -f $moduleName, $moduleInfo.ModuleVersion)
            Import-Module (Join-path $moduleDir $moduleName) -Force -Global
        }
    }
}


function getModule {
    param
    (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]
        $Name,

        # Parameter help description
        [Parameter(Mandatory)]  #temporary
        [System.Version]
        $RequiredVersion,

        # Parameter help description
        [Parameter()]
        [System.Version]
        $MinimumVersion,

        # Parameter help description
        [Parameter()]
        [System.Version]
        $MaximumVersion,

        # Parameter help description
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    
    $local:isSkipDownload = $false

    Convert-Path -Path $Path -ErrorAction Stop  #throw exception when the path not exist

    if (Test-Path (Join-path $Path $Name)) {
        $local:moduleInfo = Get-ModuleInfo -Path (Join-path $Path $Name) -ErrorAction SilentlyContinue
        if (([System.Version]$RequiredVersion) -eq $moduleInfo.ModuleVersion) {
            # Already downloaded
            Write-Host ('{0}@{1}: Module already exists in Modules directory. Skip download.' -f $Name, $RequiredVersion)
            $isSkipDownload = $true
        }
    }
        
    if (-Not $isSkipDownload) {
        if (Test-Path (Join-path $Path $Name)) {
            Remove-Item -Path (Join-path $Path $Name) -Recurse -Force
        }

        Write-Host ('{0}@{1}: Downloading module.' -f $Name, $RequiredVersion)
        Save-Module -Name $Name -RequiredVersion $RequiredVersion -Path $Path -Force
    }
}