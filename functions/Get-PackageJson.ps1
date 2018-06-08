function Get-PackageJson {
    [CmdletBinding()]
    Param(
        [Parameter()]
        [string]
        $FilePath
    )

    if (-not $FilePath) {
        $FilePath = (Join-path $PWD.Path 'package.json')
    }

    if (Test-Path $FilePath) {
        (Get-Content -Path $FilePath -Raw | ConvertFrom-Json)
    }
}