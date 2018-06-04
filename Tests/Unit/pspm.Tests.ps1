#region Initialize
$script:moduleName = 'pspm'
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$global:CurrentDir = Convert-Path .

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
        $MockModuleName1 = 'MockModule1'
        $MockModuleVersion1 = '1.1.1'
        $MockModuleName2 = 'MockModule2'
        $MockModuleVersion2 = '2.2.2.2'

        $ValidPackageJson1 = @'
{{
  "dependencies": {{
    "{0}": "{1}"
  }}
}}
'@

        $ValidPackageJson2 = @'
{{
  "dependencies": {{
    "{0}": "{1}",
    "{2}": "{3}"
  }}
}}
'@
        #endregion Set variables for testing

        Describe 'pspm/pspm' {
            #Suppress Write-Host message
            Mock Write-Host {}

            BeforeEach {
                Set-Location -Path TestDrive:/
                Get-ChildItem -Path ./ -Recurse | Remove-Item -Force 
            }

            AfterAll {
                Set-Location -Path $global:CurrentDir
            }

            Context 'Initialize Modules folder' {
                Mock getModule {}

                It 'Create Modules folder when not exist' {
                    { pspm install $MockModuleName1 } | Should -Not -Throw
                    'TestDrive:/Modules' | Should -Exist
                }

                It 'When "-Clean" specified, Remove all folders in Modules folder' {
                    New-Item -Path 'TestDrive:/Modules/SomeFolder' -ItemType Directory -Force
                    New-Item -Path 'TestDrive:/Modules/SomeFile.txt' -ItemType File -Force
                    
                    { pspm install $MockModuleName1 -Clean } | Should -Not -Throw
                    'TestDrive:/Modules' | Should -Exist
                    'TestDrive:/Modules/SomeFolder' | Should -Not -Exist
                    'TestDrive:/Modules/SomeFile.txt' | Should -Exist
                }
            }

            Context 'pspm install <module name>' {
                Mock getModule {
                    @{
                        Name          = $MockModuleName1
                        ModuleVersion = [System.Version]::Parse($MockModuleVersion1)
                    }
                }

                Mock Import-Module {}

                It 'Get module & Import it' {
                    { pspm install $MockModuleName1 } | Should -Not -Throw

                    Assert-MockCalled -CommandName getModule -Times 1 -Exactly -Scope It
                    Assert-MockCalled -CommandName Import-Module -Times 1 -Exactly -Scope It
                }

                It 'Write-Error when an exception occurred' {
                    Mock getModule { throw 'Some exception' } -ParameterFilter {$Version -eq 'invalid_module'}
                    { pspm install 'invalid_module' -ea Stop} | Should -Throw

                    Assert-MockCalled -CommandName Import-Module -Times 0 -Scope It
                }

                Context 'pspm install <module name> -Save' {

                    It 'Create package.json if not exist' {
                        Remove-Item -Path 'TestDrive:/package.json' -Force -ErrorAction SilentlyContinue
                        { pspm install $MockModuleName1 -Save } | Should -Not -Throw

                        'TestDrive:/package.json' | Should -Exist
                        'TestDrive:/package.json' | Should -FileContentMatchMultiline ($ValidPackageJson1 -f $MockModuleName1, $MockModuleVersion1)
                    }

                    It 'Update module info in package.json' {
                        New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f $MockModuleName1, '0.0.1') -Force
                        { pspm install $MockModuleName1 -Save } | Should -Not -Throw

                        'TestDrive:/package.json' | Should -Exist
                        'TestDrive:/package.json' | Should -FileContentMatchMultiline ($ValidPackageJson1 -f $MockModuleName1, $MockModuleVersion1)
                    }

                    It 'Add module info in package.json' {
                        New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f 'somemodule', '0.0.1') -Force
                        { pspm install $MockModuleName1 -Save } | Should -Not -Throw

                        'TestDrive:/package.json' | Should -Exist
                        $packageJson = Get-Content -Path 'TestDrive:/package.json' -Raw | ConvertFrom-Json
                        ($packageJson.dependencies | Get-Member -Type NoteProperty | Measure-Object).Count | Should -Be 2
                        $packageJson.dependencies.($MockModuleName1) | Should -Be $MockModuleVersion1
                    }
                }
            }

            Context 'pspm install from dependencies' {
                Mock getModule {
                    @{
                        Name          = $MockModuleName1
                        ModuleVersion = [System.Version]::Parse($MockModuleVersion1)
                    }
                }

                Mock Import-Module {}

                It 'Load ./package.json & Get module & Import it' {
                    New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f $MockModuleName1, $MockModuleVersion1) -Force
                    { pspm install } | Should -Not -Throw

                    Assert-MockCalled -CommandName getModule -Times 1 -Exactly -Scope It
                    Assert-MockCalled -CommandName Import-Module -Times 1 -Exactly -Scope It
                }

                It 'Load ./package.json & Get multiple modules & Import it' {
                    New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson2 -f $MockModuleName1, $MockModuleVersion1, $MockModuleName2, $MockModuleVersion2) -Force
                    { pspm install } | Should -Not -Throw

                    Assert-MockCalled -CommandName getModule -Times 2 -Exactly -Scope It
                    Assert-MockCalled -CommandName Import-Module -Times 2 -Exactly -Scope It
                }

                It 'Write-Error when package.json not exist' {
                    Remove-Item -Path 'TestDrive:/package.json' -Force -ErrorAction SilentlyContinue
                    
                    { pspm install -ea Stop } | Should -Throw 'Cloud not find package.json in the current directory'
                }

                It 'Write-Error when an exception occurred' {
                    New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f 'invalid_module', $MockModuleVersion1) -Force
                    Mock getModule { throw 'Some exception' } -ParameterFilter {$Name -eq 'invalid_module'}
                    { pspm install -ea Stop } | Should -Throw

                    Assert-MockCalled -CommandName Import-Module -Times 0 -Scope It
                }
            }

            Context 'pspm/pspm version' {
                It 'pspm version output own version' {
                    (pspm version) -as [System.version] | Should -Be $true
                }

                It 'pspm -Version output own version' {
                    (pspm -Version) -as [System.version] | Should -Be $true
                }

                It 'pspm -v output own version' {
                    (pspm -v) -as [System.version] | Should -Be $true
                }
            }

            Context 'pspm unsupported command' {
                It 'Write-Error if specified unsupported command' {
                    { pspm -Command 'unsupported' -ErrorAction Stop } | Should -Throw ('Unsupported command: {0}' -f 'unsupported')
                }
            }
        }
    }
}
finally {
    Remove-Module -Name $script:moduleName -Force
    Remove-Variable -Name CurrentDir -Scope Global
}
#endregion Testing
