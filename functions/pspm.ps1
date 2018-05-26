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
        $targetModule = getModule -Version $Name -Path $moduleDir

        if ($targetModule) {
            Write-Host ('{0}@{1}: Importing module.' -f $targetModule.Name, $targetModule.ModuleVersion)
            Import-Module (Join-path $moduleDir $targetModule.Name) -Force -Global
        }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'Json') {
        $PackageJson.dependencies | Get-Member -MemberType NoteProperty | `
            ForEach-Object {
            $moduleName = $_.Name
            $version = $PackageJson.dependencies.($_.Name)

            $targetModule = getModule -Name $moduleName -Version $version -Path $moduleDir -ErrorAction Continue

            if ($targetModule) {
                Write-Host ('{0}@{1}: Importing module.' -f $targetModule.Name, $targetModule.ModuleVersion)
                Import-Module (Join-path $moduleDir $targetModule.Name) -Force -Global
            }
        }
    }
}

