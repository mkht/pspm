function pspm {
    [CmdletBinding()]
    param
    (
        # Parameter help description
        [Parameter(Mandatory, Position = 0)]
        [string]
        $Command = 'install',

        # Parameter help description
        [Parameter()]
        [string]
        $PackageName
    )

    $script:moduleRoot = Split-Path -Parent $PSScriptRoot
    $script:currentDir = Convert-Path .
    $script:moduleDir = (Join-path $currentDir '\Modules')

    $PackageJsonFile = Convert-Path (Join-path $currentDir '\package.json') -ErrorAction Stop
    $PackageJson = Get-Content $PackageJsonFile -Raw | ConvertFrom-Json

    if (-Not (Test-Path (Join-path $currentDir '\Modules'))) {
        New-Item -Path (Join-path $currentDir '\Modules') -ItemType Directory
    }

    $PackageJson.dependencies | Get-Member -MemberType NoteProperty | `
        ForEach-Object {
        $local:isSkipDownload = $false
        $moduleName = $_.Name
        $version = $PackageJson.dependencies.($_.Name)

        if (Test-Path (Join-path $moduleDir $moduleName)) {
            $local:moduleInfo = Get-ModuleInfo -Path (Join-path $moduleDir $moduleName) -ErrorAction SilentlyContinue
            if (([System.Version]$version) -eq $moduleInfo.ModuleVersion) {
                # Already downloaded
                Write-Host ('{0}@{1}: Module already exists in Modules directory. Skip download.' -f $moduleName, $version)
                $isSkipDownload = $true
            }
        }
        
        if (-Not $isSkipDownload) {
            if (Test-Path (Join-path $moduleDir $moduleName)) {
                Remove-Item -Path (Join-path $moduleDir $moduleName) -Recurse -Force
            }

            Write-Host ('{0}@{1}: Downloading module.' -f $moduleName, $version)
            Save-Module -Name $moduleName -RequiredVersion $version -Path $moduleDir -Force
        }

        $local:moduleInfo = Get-ModuleInfo -Path (Join-path $moduleDir $moduleName) -ErrorAction SilentlyContinue

        Write-Host ('{0}@{1}: Importing module.' -f $moduleName, $moduleInfo.ModuleVersion)
        Import-Module (Join-path $moduleDir $moduleName) -Force -Global
    }
}