
function Get-RepositoryInfo {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string] $Owner,

        [Parameter(Mandatory)]
        [string] $Repository,

        [Parameter()]
        [PSCredential] $Credential,

        [Parameter()]
        [securestring] $Token
    )

    $apiEndpointURI = "https://api.github.com/repos/$Owner/$Repository"

    try {
        if ($Credential) {
            $response = Invoke-GitHubRequest -Uri $apiEndpointURI -Credential $Credential -ErrorAction Stop
        }
        elseif ($Token) {
            $response = Invoke-GitHubRequest -Uri $apiEndpointURI -Token $Token -ErrorAction Stop
        }
        else {
            $response = Invoke-GitHubRequest -Uri $apiEndpointURI -ErrorAction Stop
        }
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
        [PSCredential] $Credential,

        [Parameter()]
        [securestring] $Token
    )

    if (-not $Ref) {
        $paramHash = @{
            Owner      = $Owner
            Repository = $Repository
        }

        if ($Credential) {
            $paramHash.Credential = $Credential
        }
        elseif ($Token) {
            $paramHash.Token = $Token
        }

        try {
            $repoInfo = Get-RepositoryInfo @paramHash -ErrorAction Stop
        }
        catch {
            throw
            return
        }

        if (-not $repoInfo) {
            throw 'Repository not found'
            return
        }
        $Ref = $repoInfo.default_branch
    }

    $apiEndpointURI = "https://api.github.com/repos/$Owner/$Repository/commits/$Ref"

    # Get commit info
    try {
        if ($Credential) {
            $response = Invoke-GitHubRequest -Uri $apiEndpointURI -Credential $Credential -ErrorAction Stop
        }
        elseif ($Token) {
            $response = Invoke-GitHubRequest -Uri $apiEndpointURI -Token $Token -ErrorAction Stop
        }
        else {
            $response = Invoke-GitHubRequest -Uri $apiEndpointURI -ErrorAction Stop
        }

        $commitInfo = ConvertFrom-Json -InputObject $response.Content
        if ($commitInfo.sha) {
            $commitInfo.sha
        }
        else {
            throw 'Commit not found'
        }
    }
    catch {
        throw
    }
}


function Get-Zipball {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [string] $Owner,

        [Parameter(Mandatory)]
        [string] $Repository,

        [Parameter()]
        [string] $Ref,

        [Parameter(Mandatory)]
        [string] $OutFile,

        [Parameter()]
        [PSCredential] $Credential,

        [Parameter()]
        [securestring] $Token
    )

    $zipUrl = ('https://api.github.com/repos/{0}/{1}/zipball/{2}' -f $Owner, $Repository, $Ref)

    $paramHash = @{
        Uri     = $zipUrl
        OutFile = $OutFile
    }
    if ($Credential) {
        $paramHash.Credential = $Credential
    }
    elseif ($Token) {
        $paramHash.Token = $Token
    }

    Invoke-GitHubRequest @paramHash
}


function Invoke-GitHubRequest {
    [CmdletBinding(DefaultParameterSetName = 'None')]
    param(
        [Parameter(Mandatory, Position = 0)]
        [uri] $URI,

        [Parameter()]
        [string] $OutFile,

        [Parameter(ParameterSetName = 'BasicAuth')]
        [pscredential] $Credential,

        [Parameter(ParameterSetName = 'OAuth')]
        [securestring] $Token
    )

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

    [bool]$IsPSCore6 = [bool]((Get-Command Invoke-WebRequest).Parameters.Authentication)

    $paramHash = @{
        Uri = $URI
    }

    if ($OutFile) {
        $paramHash.OutFile = $OutFile
    }

    if ($IsPSCore6) {
        if ($PSCmdlet.ParameterSetName -eq 'BasicAuth') {
            $paramHash.Authentication = 'Basic'
            $paramHash.Credential = $Credential
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'OAuth') {
            $paramHash.Authentication = 'Bearer'
            $paramHash.Token = $Token
        }
    }
    else {
        if ($PSCmdlet.ParameterSetName -eq 'BasicAuth') {
            $private:base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(("{0}:{1}" -f $Credential.UserName, $Credential.GetNetworkCredential().Password)))
            $paramHash.Headers = @{Authorization = ("Basic {0}" -f $private:base64AuthInfo)}
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'OAuth') {
            $private:BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($private:Token)
            $private:PlainToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($private:BSTR)
            $paramHash.Headers = @{Authorization = ("Bearer {0}" -f $private:PlainToken)}
        }
    }

    try {
        Invoke-WebRequest @paramHash -UseBasicParsing
    }
    catch {
        $errorResponse = $_.Exception.Response
        $errorResponseStream = $errorResponse.GetResponseStream()
        $errorResponseStream.Seek(0, [System.IO.SeekOrigin]::Begin)
        $streamReader = New-Object System.IO.StreamReader $errorResponseStream
        $message = $streamReader.ReadToEnd()
        if ($message) {
            $messageObject = ConvertFrom-Json -InputObject $message -ErrorAction SilentlyContinue
            if ($messageObject.message) {
                $message = $messageObject.message
            }
            throw ('Remote server returned error ({0}). Message : {1}' -f $errorResponse.StatusCode.Value__, $message)
        }
        else {
            throw
        }
    }
    finally {
        if ($streamReader) {
            $streamReader.Dispose()
        }
    }
}
