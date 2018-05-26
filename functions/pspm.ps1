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


function getModule {
    [CmdletBinding()]
    Param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter()]
        [string]
        $Version,

        [Parameter(Mandatory)]
        [string]
        $Path
    )

    Convert-Path -Path $Path -ErrorAction Stop > $null  #throw exception when the path not exist
    
    $paramHash = @{}
    if ($PSBoundParameters.ContainsKey('Name')) {
        $paramHash.Name = $Name
    }
    if ($PSBoundParameters.ContainsKey('Version')) {
        $paramHash.Version = $Version
    }
    $moduleType = parseModuleType @paramHash

    switch ($moduleType.Type) {
        'GitHub' {
            $local:paramHash = $moduleType
            $paramHash.Remove('Type')
            getModuleFromGitHub @paramHash -Path $Path
        }

        'PSGallery' {
            $local:paramHash = $moduleType
            $paramHash.Remove('Type')
            getModuleFromPSGallery @paramHash -Path $Path
        }
    }
}


function getModuleFromGitHub {
    [CmdletBinding()]
    Param
    (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]
        $Name,
        
        [Parameter(Mandatory)]
        [string]
        $Account,

        [Parameter()]
        [string]
        $Branch,

        [Parameter(Mandatory)]
        [string]
        $Path
    )

    
    $TempDir = New-Item (Join-Path $env:TEMP '/pspm') -Force -ItemType Directory -ErrorAction Stop
    $TempName = [System.Guid]::NewGuid().toString() + '.zip'

    $zipUrl = ('https://api.github.com/repos/{0}/{1}/zipball/{2}' -f $Account, $Name, $Branch)
    
    try {
        #Download zip from GitHub
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Write-Host ('{0}: Downloading module from GitHub.' -f $Name)
        Invoke-WebRequest -Uri $zipUrl -UseBasicParsing -OutFile (Join-Path $TempDir $TempName) -ErrorAction Stop

        if (Test-Path (Join-Path $TempDir $TempName)) {
            Expand-Archive -Path (Join-Path $TempDir $TempName) -DestinationPath $TempDir
            $downloadedModule = Get-ChildItem -Path $TempDir -Filter ('{0}-{1}*' -f $Account, $Name) -Directory

            $moduleInfo = $downloadedModule.PsPath | Get-Moduleinfo

            #Copy to /Modules folder
            if (Test-Path (Join-Path $Path $moduleInfo.Name)) {
                Remove-Item -Path (Join-Path $Path $moduleInfo.Name) -Recurse -Force
            }
            $downloadedModule | Copy-Item -Destination (Join-Path $Path $moduleInfo.Name) -Recurse -Force -ErrorAction Stop

            #Return module info
            $moduleInfo
        }
        else {
            throw 'Download failed!'
        }
    }
    catch {
        throw $_.Exception
    }
    finally {
        if (Test-Path $TempDir) {
            #Cleanup temp folder
            Remove-Item $TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}


function getModuleFromPSGallery {
    [CmdletBinding(DefaultParameterSetName = 'Latest')]
    param
    (
        # Parameter help description
        [Parameter(Mandatory)]
        [string]
        $Name,

        # Parameter help description
        [Parameter(ParameterSetName = 'StrictVersion')]
        [System.Version]
        $RequiredVersion,

        # Parameter help description
        [Parameter(ParameterSetName = 'RangeVersion')]
        [System.Version]
        $MinimumVersion,

        # Parameter help description
        [Parameter(ParameterSetName = 'RangeVersion')]
        [System.Version]
        $MaximumVersion,

        # Parameter help description
        [Parameter(Mandatory)]
        [string]
        $Path
    )
    
    $local:isSkipDownload = $false

    $foundModules = Find-Module -Name $Name -AllVersions -ErrorAction SilentlyContinue
    if ($RequiredVersion) {
        $foundModules = $foundModules | ? {$_.Version -eq $RequiredVersion}
    }
    elseif ($MinimumVersion -or $MaximumVersion) {
        if ($MinimumVersion) {
            $foundModules = $foundModules | ? {$_.Version -ge $MinimumVersion}
        }
        if ($MaximumVersion) {
            $foundModules = $foundModules | ? {$_.Version -le $MaximumVersion}
        }
    }

    $targetModule = $foundModules | ? {$_.Version} | sort Version -Descending | select -First 1

    if (($targetModule | Measure-Object).count -le 0) {
        Write-Error ('{0}: No match found for the specified search criteria and module name' -f $Name)
        return
    }

    if (Test-Path (Join-path $Path $Name)) {
        $local:moduleInfo = Get-ModuleInfo -Path (Join-path $Path $Name) -ErrorAction SilentlyContinue
        if (([Version]$targetModule.Version) -eq $moduleInfo.ModuleVersion) {
            # Already downloaded
            Write-Host ('{0}@{1}: Module already exists in Modules directory. Skip download.' -f $Name, $targetModule.Version)
            $isSkipDownload = $true
        }
    }

    if (-Not $isSkipDownload) {
        if (Test-Path (Join-path $Path $Name)) {
            Remove-Item -Path (Join-path $Path $Name) -Recurse -Force
        }

        Write-Host ('{0}@{1}: Downloading module.' -f $Name, $targetModule.Version)
        $targetModule | Save-Module -Path $Path -Force
    }

    if (Test-Path (Join-path $Path $Name)) {
        $moduleInfo = Get-ModuleInfo -Path (Join-path $Path $Name) -ErrorAction SilentlyContinue
        $moduleInfo
    }
}


function parseModuleType {
    param
    (
        [Parameter()]
        [string]
        $Name,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]
        $Version
    )

    $Result = @{}

    if ($PSBoundParameters.ContainsKey('Name')) {
        #dependencies
        switch -regex ($Version) {
            #Git Urls
            '^git\+?.*:' {
                #Not implemented
                Write-Warning ('Sorry! This version specification format is not supported.')
                break
            }

            #Local path & Urls
            '^<http|https|file>://' {
                #Not implemented
                Write-Warning ('Sorry! This version specification format is not supported.')
                break
            }

            # GitHub Urls
            '^[^/]+/[^/]+' {
                $local:userAccount = $_.Split("/")[0]
                $local:repoName = $_.Split("/")[1].Split("#")[0]
                $local:branch = $_.Split("/")[1].Split("#")[1]

                $Result = @{
                    Type    = 'GitHub'
                    Name    = $repoName
                    Account = $userAccount
                    Branch  = $branch
                }

                break
            }

            # <version> (PSGallery)
            Default {
                $local:parsedVersion = parseVersion -Version $_

                $Result = @{
                    Type = 'PSGallery'
                    Name = $Name
                }

                if ($parsedVersion.RequiredVersion) {
                    $Result.RequiredVersion = $parsedVersion.RequiredVersion
                }
                else {
                    if ($parsedVersion.MaximumVersion) {
                        $Result.MaximumVersion = $parsedVersion.MaximumVersion
                    }
                    if ($parsedVersion.MinimumVersion) {
                        $Result.MinimumVersion = $parsedVersion.MinimumVersion
                    }
                }
            }
        }
    }
    else {
        #parameter
        switch -regex ($Version) {
            #Git Urls
            '^git\+?.*:' {
                #Not implemented
                Write-Warning ('Sorry! This version specification format is not supported.')
                break
            }

            #Local path & Urls
            '^<http|https|file>://' {
                #Not implemented
                Write-Warning ('Sorry! This version specification format is not supported.')
                break
            }

            # GitHub Urls
            '^[^/]+/[^/]+' {
                $local:userAccount = $_.Split("/")[0]
                $local:repoName = $_.Split("/")[1].Split("#")[0]
                $local:branch = $_.Split("/")[1].Split("#")[1]

                $Result = @{
                    Type    = 'GitHub'
                    Name    = $repoName
                    Account = $userAccount
                    Branch  = $branch
                }

                break
            }

            # <name>@<version> (PSGallery)
            '^.+@.+' {
                $local:moduleName = $_.Split("@")[0]
                $local:version = $_.Split("@")[1]
                $local:parsedVersion = parseVersion -Version $version

                $Result = @{
                    Type = 'PSGallery'
                    Name = $moduleName
                }

                if ($parsedVersion.RequiredVersion) {
                    $Result.RequiredVersion = $parsedVersion.RequiredVersion
                }
                else {
                    if ($parsedVersion.MaximumVersion) {
                        $Result.MaximumVersion = $parsedVersion.MaximumVersion
                    }
                    if ($parsedVersion.MinimumVersion) {
                        $Result.MinimumVersion = $parsedVersion.MinimumVersion
                    }
                }

                break
            }

            # <name> (PSGallery)
            Default {
                $local:moduleName = $_.Split("@")[0]

                $Result = @{
                    Type = 'PSGallery'
                    Name = $moduleName
                }
            }
        }
    }

    $Result

}


function parseVersion {
    param
    (
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]
        $Version
    )

    $ReturnHash = @{}

    $isError = $false

    if (($Version -eq '') -or ($Version -eq '*') -or ($Version -eq 'latest')) {
        #empty or asterisk or latest means not specified (= latest)
    }
    elseif ([System.Version]::TryParse($Version, [ref]$null)) {
        #Specified strict version (e.g. '1.2.0'
        $ReturnHash.RequiredVersion = [System.Version]::Parse($Version)
    }
    elseif ($Version.StartsWith('>')) {
        if ($Version.Substring(1).StartsWith('=')) {
            #Grater equals (e.g. '>=1.2.0'
            $local:tempVersion = $Version.Substring(2)
            if ([System.Version]::TryParse($tempVersion, [ref]$null)) {
                $ReturnHash.MinimumVersion = [System.Version]::Parse($tempVersion)
            }
            else {
                $isError = $true
            }
        }
        else {
            #Grater than (e.g. '>1.2.0'
            $local:tempVersion = $Version.Substring(1)
            if ([System.Version]::TryParse($tempVersion, [ref]$null)) {
                $local:v = [System.Version]::Parse($tempVersion)
                $ReturnHash.MinimumVersion = [System.Version]::New($v.Major, $v.Minor, $v.Build, $v.Revision + 1)
            }
            else {
                $isError = $true
            }
        }
    }
    elseif ($Version.StartsWith('<')) {
        if ($Version.Substring(1).StartsWith('=')) {
            #Less equals (e.g. '<=1.2.0'
            $local:tempVersion = $Version.Substring(2)
            if ([System.Version]::TryParse($tempVersion, [ref]$null)) {
                $ReturnHash.MaximumVersion = [System.Version]::Parse($tempVersion)
            }
            else {
                $isError = $true
            }
        }
        else {
            #Less than (e.g. '<1.2.0'
            $local:tempVersion = $Version.Substring(1)
            if ([System.Version]::TryParse($tempVersion, [ref]$null)) {
                $local:v = [System.Version]::Parse($tempVersion)
                #region Version decrement
                $local:major = $v.Major
                $local:Minor = $v.Minor
                $local:Build = $v.Build
                $local:Revision = $v.Revision
                if ($v.Revision -le 0) {
                    $Revision = [Int32]::MaxValue
                    if ($v.Build -le 0) {
                        $Build = [Int32]::MaxValue
                        if ($v.Minor -le 0) {
                            $Minor = [Int32]::MaxValue
                            $Major--
                        }
                        else {
                            $Minor--
                        }
                    }
                    else {
                        $Build--
                    }
                }
                else {
                    $Revision--
                }
                #endregion
                $ReturnHash.MaximumVersion = [System.Version]::New($Major, $Minor, $Build, $Revision)
            }
            else {
                $isError = $true
            }
        }
    }
    else {
        #Not supported format
        $isError = $true
    }

    if ($isError) {
        throw ('"{0}" is unsupported version format' -f $Version)
    }
    else {
        $ReturnHash
    }
}

