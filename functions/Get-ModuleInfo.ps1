function Get-ModuleInfo {
    [CmdletBinding()]
    param
    (
        # Parameter help description
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Path
    )

    $moduleManifest = @(Get-ChildItem -Path $Path -Filter '*.psd1' -File -Recurse -Depth 1)[0]
    
    if (-Not $moduleManifest) {
        Write-Error 'Module manifest not found!'
        return
    }

    $moduleInfo = Import-PowerShellDataFile $moduleManifest.PsPath
    $moduleInfo.Name = $moduleManifest.BaseName
    $moduleInfo
}
