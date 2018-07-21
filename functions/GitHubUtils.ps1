
function Get-RepositoryInfo {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string] $Owner,

        [Parameter(Mandatory)]
        [string] $Repository,

        [Parameter()]
        [PSCredential] $Credential
    )

    $apiEndpointURI = "https://api.github.com/repos/$Owner/$Repository"

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $response = Invoke-WebRequest -Uri $apiEndpointURI -UseBasicParsing -ErrorAction Stop
        ConvertFrom-Json -InputObject $response.Content
    }
    catch {
        throw
    }
}


function Get-CommitHash {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string] $Owner,

        [Parameter(Mandatory)]
        [string] $Repository,

        [Parameter()]
        [string] $Ref,

        [Parameter()]
        [PSCredential] $Credential
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    if (-not $Ref) {
        $paramHash = @{
            Owner      = $Owner
            Repository = $Repository
        }
        if ($Credential) {
            $paramHash.Credential = $Credential
        }
        try {
            $repoInfo = Get-RepositoryInfo @paramHash -ErrorAction SilentlyContinue
        }
        catch {}
        if (-not $repoInfo) {
            Write-Error 'Repository not found'
            return
        }
        $Ref = $repoInfo.default_branch
    }

    $apiEndpointURI = "https://api.github.com/repos/$Owner/$Repository/commits/$Ref"

    # Get commit info
    try {
        $response = Invoke-WebRequest -Uri $apiEndpointURI -UseBasicParsing -ErrorAction Stop
        $commitInfo = ConvertFrom-Json -InputObject $response.Content
        if ($commitInfo.sha) {
            $commitInfo.sha
        }
        else {
            throw 'Commit not found'
        }
    }
    catch {
        Write-Error $_.Exception.Message
    }
}



