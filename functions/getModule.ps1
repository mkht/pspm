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
    [CmdletBinding()]
    param
    (
        # The name of module
        [Parameter(Mandatory)]
        [string]
        $Name,

        # Desired version (semver range expression)
        [Parameter()]
        [string]
        $Version = '*',

        # The path for download
        [Parameter(Mandatory)]
        [string]
        $Path,

        # Get module from PSGallery even if the module already exists
        [Parameter()]
        [switch]
        $Force
    )

    $Latest = ($Version -eq 'Latest')   #"Latest" is special term
    
    if (-not $Latest) {
        try {
            $SemVerRange = [pspm.SemVerRange]::new($Version) #throw exception on parse error
        }
        catch {
            throw
            return
        }
    }
    
    if ((-not $Latest) -and (-not $Force)) {
        if (Test-Path (Join-path $Path $Name)) {
            $local:moduleInfo = Get-ModuleInfo -Path (Join-path $Path $Name) -ErrorAction SilentlyContinue
            if ($SemVerRange.IsSatisfied($moduleInfo.ModuleVersion)) {
                # Already exist
                Write-Host ('{0}@{1}: Module already exists in Modules directory. Skip download.' -f $Name, $moduleInfo.ModuleVersion)
                $moduleInfo
                return
            }
        }
    }

    if ((-not $Latest) -and (Get-Command Find-Module).Parameters.AllowPrerelease) {
        # Only PowerShell 6.0+ has AllowPrerelease param
        $foundModules = Find-Module -Name $Name -AllVersions -AllowPrerelease -ErrorAction SilentlyContinue
    }
    else {
        $foundModules = Find-Module -Name $Name -AllVersions -ErrorAction SilentlyContinue
    }

    if ($Latest) {
        $targetModule = $foundModules | sort Version -Descending | select -First 1
    }
    else {
        $targetModule = $foundModules | ? {$SemVerRange.IsSatisfied($_.Version)} | sort Version -Descending | select -First 1
    }

    if (($targetModule | Measure-Object).count -le 0) {
        Write-Error ('{0}: No match found for the specified search criteria and module name' -f $Name)
        return
    }

    if (-not $Force) {
        if (Test-Path (Join-path $Path $Name)) {
            $local:moduleInfo = Get-ModuleInfo -Path (Join-path $Path $Name) -ErrorAction SilentlyContinue
            if (([Version]$targetModule.Version) -eq $moduleInfo.ModuleVersion) {
                # Already downloaded
                Write-Host ('{0}@{1}: Module already exists in Modules directory. Skip download.' -f $Name, $targetModule.Version)
                $moduleInfo
                return
            }
        }
    }

    if (Test-Path (Join-path $Path $Name)) {
        Remove-Item -Path (Join-path $Path $Name) -Recurse -Force
    }

    Write-Host ('{0}@{1}: Downloading module.' -f $Name, $targetModule.Version)
    $targetModule | Save-Module -Path $Path -Force -ErrorAction Stop

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
                $Result = @{
                    Type    = 'PSGallery'
                    Name    = $Name
                    Version = $_
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

                $Result = @{
                    Type    = 'PSGallery'
                    Name    = $moduleName
                    Version = $version
                }

                break
            }

            # <name> (PSGallery)
            Default {
                $local:moduleName = $_.Split("@")[0]

                $Result = @{
                    Type    = 'PSGallery'
                    Name    = $moduleName
                    Version = '*'
                }
            }
        }
    }

    $Result
}

