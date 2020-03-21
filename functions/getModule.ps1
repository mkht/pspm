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
        $Path,

        [Parameter(Mandatory)]
        [ValidateSet('Install', 'Update')]
        [string]
        $CommandType,

        [Parameter()]
        [PSCredential] $Credential,

        [Parameter()]
        [securestring] $Token
    )

    Convert-Path -Path $Path -ErrorAction Stop > $null  #throw exception when the path not exist

    $paramHash = @{ }
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

            if ($Credential) { $paramHash.Credential = $Credential }
            elseif ($Token) { $paramHash.Token = $Token }

            getModuleFromGitHub @paramHash -Path $Path
        }

        'PSGallery' {
            $local:paramHash = $moduleType
            $paramHash.Remove('Type')

            if ($CommandType -eq 'Update') {
                $paramHash.Force = $true
            }

            getModuleFromPSGallery @paramHash -Path $Path
        }
    }
}

function getModuleVersion {
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory)]
        [string]
        $Name
    )

    $moduleType = parseModuleType -Name $Name

    switch ($moduleType.Type) {
        'GitHub' {
            # getModuleVersionFromGitHub @paramHash -Path $Path
        }

        'PSGallery' {
            getModuleVersionFromPSGallery -Name $moduleType.Name
        }
    }
}


function getModuleVersionFromPSGallery {
    [CmdletBinding()]
    param
    (
        # The name of module
        [Parameter(Mandatory)]
        [string]
        $Name,

        [Parameter()]
        [AllowEmptyString()]
        [string]
        $Repository = ''
    )

    $foundModules = @()

    $paramHash = @{
        Name        = $Name
        AllVersions = $true
    }

    if (-not [string]::IsNullOrEmpty($Repository)) {
        # Repository Specified
        $paramHash.Repository = $Repository
    }

    if ((Get-Command Find-Module).Parameters.AllowPrerelease) {
        # Only PowerShellGet 1.6.0+ has AllowPrerelease param
        $paramHash.AllowPrerelease = $true
    }

    try {
        Find-Module @paramHash | ForEach-Object { $foundModules += $_ }
    }
    catch {
        #Ignore Statement-terminating errors
    }

    if (($foundModules | Measure-Object).count -le 0) {
        Write-Error ('{0}: No match found for the specified search criteria and module name' -f $Name)
        return $null
    }
    else {
        $foundModules
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
        $Path,

        [Parameter()]
        [PSCredential] $Credential,

        [Parameter()]
        [securestring] $Token
    )

    $PlatformTemp =
    if ($env:TEMP) { $env:TEMP }
    elseif ($env:TMPDIR) { $env:TMPDIR }
    elseif (Test-Path '/tmp' -PathType Container) { '/tmp' }
    else { Write-Error 'Could not find standard temp folder'; return }

    $TempDir = New-Item (Join-Path $PlatformTemp ([System.IO.Path]::GetRandomFileName())) -Force -ItemType Directory -ErrorAction Stop
    $TempName = [System.IO.Path]::GetRandomFileName() + '.zip'
    $TargetDir = (Join-Path $Path $Name)

    # Get commit hash
    $paramHash = @{Owner = $Account; Repository = $Name }
    if ($Branch) { $paramHash.Ref = $Branch }
    if ($Credential) { $paramHash.Credential = $Credential }
    elseif ($Token) { $paramHash.Token = $Token }

    try {
        $CommitHash = Get-CommitHash @paramHash -ErrorAction Stop
    }
    catch {
        Write-Error -Exception $_.Exception
        return
    }

    if (-not $CommitHash) {
        Write-Error 'Could not get repository info'
        return
    }

    # Test whether the specified module already exists
    if (Test-Path $TargetDir) {
        $private:moduleInfo = Get-ModuleInfo $TargetDir
        if ($private:moduleInfo.Name -eq $Name) {
            if (Test-Path (Join-Path $TargetDir '.pspminfo')) {
                $private:hash = Get-Content -Path (Join-Path $TargetDir '.pspminfo')
                if ($private:hash -eq $CommitHash) {
                    Write-Host ('{0}@{1}: Module already exists in Modules directory. Skip download.' -f $Name, $private:moduleInfo.ModuleVersion)
                    $private:moduleInfo
                    return
                }
            }
        }
    }

    try {
        #Download zip from GitHub
        Write-Host ('{0}: Downloading module from GitHub.' -f $Name)
        $paramHash = @{Owner = $Account; Repository = $Name; Ref = $CommitHash }
        if ($Credential) { $paramHash.Credential = $Credential }
        elseif ($Token) { $paramHash.Token = $Token }
        Get-Zipball @paramHash -OutFile (Join-Path $TempDir $TempName) -ErrorAction Stop

        if (Test-Path (Join-Path $TempDir $TempName)) {
            Expand-Archive -Path (Join-Path $TempDir $TempName) -DestinationPath $TempDir
            $downloadedModule = Get-ChildItem -Path $TempDir -Filter ('{0}-{1}*' -f $Account, $Name) -Directory

            $moduleInfo = $downloadedModule.PsPath | Get-ModuleInfo

            #Copy to /Modules folder
            if (Test-Path (Join-Path $Path $moduleInfo.Name)) {
                Remove-Item -Path (Join-Path $Path $moduleInfo.Name) -Recurse -Force
            }
            $downloadedModule | Copy-Item -Destination (Join-Path $Path $moduleInfo.Name) -Recurse -Force -ErrorAction Stop

            #Save commit hash info
            $CommitHash | Out-File -FilePath (Join-Path (Join-Path $Path $moduleInfo.Name) '.pspminfo') -Force

            #Return module info
            $moduleInfo
        }
        else {
            Write-Error 'Download failed!'
        }
    }
    catch {
        Write-Error -Exception $_.Exception
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
            Write-Error -Exception $_.Exception
            return
        }
    }

    # Detect repository specific module (e.g: @MyRepo/MyModule)
    if ($Name -match '^@(.+)/(.+)$') {
        $Repository = $Matches[1]
        $Name = $Matches[2]
        Write-Verbose ('Repository specified; Repository:"{0}" / ModuleName:"{1}"' -f $Repository, $Name)
    }

    if ((-not $Latest) -and (-not $Force)) {
        if (Test-Path (Join-path $Path $Name)) {
            $local:moduleInfo = Get-ModuleInfo -Path (Join-path $Path $Name) -ErrorAction SilentlyContinue
            if ($local:moduleInfo -and $SemVerRange.IsSatisfied($local:moduleInfo.ModuleVersion)) {
                # Already exist
                Write-Host ('{0}@{1}: Module already exists in Modules directory. Skip download.' -f $Name, $local:moduleInfo.ModuleVersion)
                $moduleInfo
                return
            }
        }
    }

    $foundModules = getModuleVersionFromPSGallery -Name $Name -Repository $Repository -ErrorAction SilentlyContinue

    if ($Latest) {
        $targetModule = $foundModules | Sort-Object -Property { [pspm.SemVer]$_.Version } -Descending | Select-Object -First 1
    }
    else {
        $targetModule = $foundModules | Where-Object { ($null -ne $_.Version) -and $SemVerRange.IsSatisfied($_.Version) } | Sort-Object -Property { [pspm.SemVer]$_.Version } -Descending | Select-Object -First 1
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
        if ($Repository) {
            $moduleInfo.Repository = $Repository
        }
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

    $Result = @{ }

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
            '^[^/@]+/[^/]+' {
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

            # @<repo>/<name>@<version> (PSGallery with repository specific)
            '^(@.+/.+)@(.+)' {
                $local:moduleName = $Matches[1]
                $local:version = $Matches[2]

                $Result = @{
                    Type    = 'PSGallery'
                    Name    = $moduleName
                    Version = $version
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
                $local:moduleName = $_

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

