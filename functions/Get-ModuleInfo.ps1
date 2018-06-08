function Get-ModuleInfo {
    [CmdletBinding()]
    param
    (
        # The path of module folder
        [Parameter(Mandatory, ValueFromPipeline)]
        [string]
        $Path
    )

    $moduleManifest = @(Get-ChildItem -Path $Path -Filter '*.psd1' -File -Recurse -Depth 1)[0]
    
    if (-Not $moduleManifest) {
        $scriptModule = @(Get-ChildItem -Path $Path -Filter '*.psm1' -File -Recurse -Depth 1)[0]
        if ($scriptModule) {
            $moduleInfo = @{
                Name          = $scriptModule.BaseName
                ModuleVersion = [System.Version]::New(0, 0)
            }
            $moduleInfo
        }
        else {
            Write-Error ('Module manifest not found in "{0}"' -f $Path)
            return
        }
    }
    else {
        $moduleInfo = Import-PowerShellDataFile $moduleManifest.PsPath
        $moduleInfo.Name = $moduleManifest.BaseName
        $moduleInfo
    }
}
