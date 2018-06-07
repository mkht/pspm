#region Initialize
$script:moduleName = 'pspm'
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)

# Requires Pester 4.1.0 or higher
$newestPesterVersion = [System.Version]((Get-Module Pester -ListAvailable).Version | Sort-Object -Descending | Select-Object -First 1)
if ($newestPesterVersion -lt '4.1.0') { throw "Pester 4.1.0 or higher is required." }

# Import test target module
Remove-Module -Name $script:moduleName -Force -ErrorAction SilentlyContinue
Import-Module -Name (Join-Path -Path $script:moduleRoot -ChildPath 'pspm.psd1') -Force
#endregion Initialize

#region Testing
# Begin Test
try {
    InModuleScope 'pspm' {
        #region Set variables for testing
        $MockPackageJson1 = '{"Mock":"MockJson"}'
        #endregion Set variables for testing

        Describe 'Get-PackageJson' {

            Context 'Load from current directory' {

                BeforeEach {
                    Set-Location -LiteralPath $TestDrive
                    Remove-Item -Path (Join-Path $TestDrive 'package.json') -Force -ErrorAction SilentlyContinue
                }

                It 'Return $null if package.json not exists' {
                    Get-PackageJson | Should -Be $null
                }

                It 'Return json object if package.json exists' {
                    $MockPackageJson1 | Out-File -FilePath (Join-Path $TestDrive 'package.json')

                    $json = Get-PackageJson
                    $json | Should -BeOfType PSCustomObject
                    $json.Mock | Should -Be 'MockJson'
                }
            }

            Context 'Load from specified file' {

                BeforeEach {
                    Set-Location -LiteralPath $PSHome
                    Remove-Item -Path (Join-Path $TestDrive 'package.json') -Force -ErrorAction SilentlyContinue
                }

                It 'Return $null if the file not exist' {
                    Get-PackageJson -FilePath (Join-Path $TestDrive 'package.json') | Should -Be $null
                }

                It 'return Json object if the file exists' {
                    $MockPackageJson1 | Out-File -FilePath (Join-Path $TestDrive 'package.json')

                    $json = Get-PackageJson -FilePath (Join-Path $TestDrive 'package.json')
                    $json | Should -BeOfType PSCustomObject
                    $json.Mock | Should -Be 'MockJson'
                }

                It 'Write-Error if the file exists but invalid json format' {
                    'Invalid' | Out-File -FilePath (Join-Path $TestDrive 'package.json')

                    { Get-PackageJson -FilePath (Join-Path $TestDrive 'package.json') -ErrorAction Stop } | Should -Throw
                }
            }
        }
    }
}
finally {
    Remove-Module -Name $script:moduleName -Force
    Set-Location $script:moduleRoot
}
#endregion Testing
