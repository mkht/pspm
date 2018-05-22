#Requires -Version 4

$modulePath = $PSScriptRoot
$functionsPath = '\functions'

Get-ChildItem (Join-Path $modulePath $functionsPath) -Include "*.ps1" -Recurse | 
    % { . $_.PsPath }

Export-ModuleMember -Function pspm