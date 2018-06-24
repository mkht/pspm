#region Initialize
$script:moduleName = 'pspm'
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$global:CurrentDir = Convert-Path .

# Requires Pester 4.2.0 or higher
$newestPesterVersion = [System.Version]((Get-Module Pester -ListAvailable).Version | Sort-Object -Descending | Select-Object -First 1)
if ($newestPesterVersion -lt '4.2.0') { throw "Pester 4.2.0 or higher is required." }

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

        $ValidPackageJson1 = (
            '{{',
            '  "dependencies": {{',
            '    "{0}": "^{1}"',
            '  }}',
            '}}') -join [System.Environment]::NewLine

        $ValidPackageJson2 = (
            '{{',
            '  "dependencies": {{',
            '    "{0}": "^{1}",',
            '    "{2}": "^{3}"',
            '  }}',
            '}}') -join [System.Environment]::NewLine

        $ScriptJsonObj1 = [PSCustomObject]@{
            scripts = [PSCustomObject]@{
                start   = 'echo "start"'
                restart = 'echo "restart"'
                stop    = 'echo "stop"'
                test    = 'echo "test"'
                hello   = 'echo "hello"'
                args    = 'echo $args[0]'
                conf    = 'echo $env:pspm_package_config_config'
            }
            config  = [PSCustomObject]@{
                config = 'config'
            }
        }

        $HookScriptJsonObj1 = [PSCustomObject]@{
            scripts = [PSCustomObject]@{
                prestart      = 'echo "prestart"'
                start         = 'echo "start"'
                poststart     = 'echo "poststart"'
                preinstall    = 'echo "preinstall"'
                install       = 'echo "install"'
                postinstall   = 'echo "postinstall"'
                preuninstall  = 'echo "preuninstall"'
                uninstall     = 'echo "uninstall"'
                postuninstall = 'echo "postuninstall"'
                prehello      = 'echo "prehello"'
                hello         = 'echo "hello"'
                posthello     = 'echo "posthello"'
            }
        }
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
                        'TestDrive:/package.json' | Should -FileContentMatchMultiline ([regex]::Escape(($ValidPackageJson1 -f $MockModuleName1, $MockModuleVersion1)))
                    }

                    It 'Update module info in package.json' {
                        New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f $MockModuleName1, '0.0.1') -Force
                        { pspm install $MockModuleName1 -Save } | Should -Not -Throw

                        'TestDrive:/package.json' | Should -Exist
                        'TestDrive:/package.json' | Should -FileContentMatchMultiline ([regex]::Escape(($ValidPackageJson1 -f $MockModuleName1, $MockModuleVersion1)))
                    }

                    It 'Add module info in package.json' {
                        New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f 'somemodule', '0.0.1') -Force
                        { pspm install $MockModuleName1 -Save } | Should -Not -Throw

                        'TestDrive:/package.json' | Should -Exist
                        $packageJson = Get-Content -Path 'TestDrive:/package.json' -Raw | ConvertFrom-Json
                        ($packageJson.dependencies | Get-Member -Type NoteProperty | Measure-Object).Count | Should -Be 2
                        $packageJson.dependencies.($MockModuleName1) | Should -Be ('^' + $MockModuleVersion1)
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
                    
                    { pspm install -ea Stop } | Should -Throw 'Could not find package.json in the current directory'
                }

                It 'Write-Error when an exception occurred' {
                    New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f 'invalid_module', $MockModuleVersion1) -Force
                    Mock getModule { throw 'Some exception' } -ParameterFilter {$Name -eq 'invalid_module'}
                    { pspm install -ea Stop } | Should -Throw

                    Assert-MockCalled -CommandName Import-Module -Times 0 -Scope It
                }
            }

            Context 'pspm uninstall' {
                Mock Get-ModuleInfo {
                    @{
                        Name          = $MockModuleName1
                        ModuleVersion = [System.Version]::Parse($MockModuleVersion1)
                    }
                }

                Mock Remove-Module {}

                It 'Uninstall module' {
                    # Create dummy file
                    New-Item -Path ('TestDrive:/Modules/{0}/{0}.psd1' -f $MockModuleName1) -ItemType File -Force >$null

                    {pspm uninstall $MockModuleName1} | Should -Not -Throw
                    ('TestDrive:/Modules/{0}' -f $MockModuleName1) | Should -Not -Exist 
                }

                It 'If target module not exist, should output warning' {
                    $local:WarningPreference = 'Stop'
                    $warnmsg = ('Module "{0}" not found in "{1}"' -f 'notexist', (Join-Path $TestDrive 'Modules'))

                    {pspm uninstall 'notexist' 3>$null} | Should -Throw $warnmsg
                }

                Context 'pspm uninstall -Save' {
                    It 'Remove module info in package.json' {
                        $local:WarningPreference = 'SilentlyContinue'
                        New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f $MockModuleName1, $MockModuleVersion1) -Force
                        
                        { pspm uninstall $MockModuleName1 -Save } | Should -Not -Throw

                        'TestDrive:/package.json' | Should -Exist
                        $json = Get-Content 'TestDrive:/package.json' -Raw | ConvertFrom-Json
                        $json.dependencies.($MockModuleName1) | Should -Be $null
                    }

                    It 'If module entry not exist in package.json, should output warning' {
                        $local:WarningPreference = 'Stop'
                        # Create dummy file
                        New-Item -Path 'TestDrive:/package.json' -Value ($ValidPackageJson1 -f $MockModuleName2, $MockModuleVersion2) -Force
                        New-Item -Path ('TestDrive:/Modules/{0}/{0}.psd1' -f $MockModuleName1) -ItemType File -Force >$null
                        $warnmsg = ('Entry "{0}" not found in package.json dependencies' -f $MockModuleName1)
                        
                        { pspm uninstall $MockModuleName1 -Save 3>$null } | Should -Throw  $warnmsg
                    }

                    It 'If package.json not exist, should output warning' {
                        $local:WarningPreference = 'Stop'
                        New-Item -Path ('TestDrive:/Modules/{0}/{0}.psd1' -f $MockModuleName1) -ItemType File -Force >$null
                        $warnmsg = 'Could not find package.json or dependencies entry'
                        
                        { pspm uninstall $MockModuleName1 -Save 3>$null } | Should -Throw  $warnmsg
                    }
                }
            }

            Context 'pspm version' {
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

            Context 'pspm run-script' {
                Mock Get-PackageJson {$ScriptJsonObj1}
                
                It 'pspm run <command> invoke user defined script' {
                    pspm run hello | Should -Be 'hello'
                }

                It 'pspm run-script <command> invoke user defined script' {
                    pspm run-script hello | Should -Be 'hello'
                }

                It 'pspm run <command> with arguments' {
                    pspm run args -Arguments 'arg1' | Should -Be 'arg1'
                }

                It 'pspm run <command> with config' {
                    pspm run conf | Should -Be 'config'
                }

                It 'pspm run <command> -IfPresent (exist)' {
                    pspm run hello -IfPresent | Should -Be 'hello'
                }

                It 'pspm run <command> -IfPresent (not exist)' {
                    pspm run notexist -IfPresent | Should -Be $null
                }

                It 'pspm run <Non Existence Command> should throw error' {
                    $local:ErrorActionPreference = 'Stop'

                    { pspm run notexist } | Should -Throw
                }

                It 'If package.json not exist, should throw error' {
                    Mock Get-PackageJson {}
                    $local:ErrorActionPreference = 'Stop'

                    { pspm run hello } | Should -Throw
                }

                It 'If package.json not exist with -IfPresent, should not throw error' {
                    Mock Get-PackageJson {}
                    $local:ErrorActionPreference = 'Stop'

                    { pspm run hello -IfPresent } | Should -Not -Throw
                }
            }

            Context 'pspm run-script (preserved words)' {
                Mock Get-PackageJson {$ScriptJsonObj1}
                
                It 'pspm start' {
                    pspm start | Should -Be 'start'
                }

                It 'pspm restart' {
                    pspm restart | Should -Be 'restart'
                }

                It 'pspm stop' {
                    pspm stop | Should -Be 'stop'
                }

                It 'pspm test' {
                    pspm test | Should -Be 'test'
                }
            }

            Context 'pspm pre / post hook scripting' {
                Mock Get-PackageJson {$HookScriptJsonObj1}
                
                It 'user defined script hooking' {
                    $ret = @(pspm run hello)
                    $ret | Should -HaveCount 3
                    $ret[0] | Should -Be 'prehello'
                    $ret[1] | Should -Be 'hello'
                    $ret[2] | Should -Be 'posthello'
                }

                It 'preserved script hooking' {
                    $ret = @(pspm start)
                    $ret | Should -HaveCount 3
                    $ret[0] | Should -Be 'prestart'
                    $ret[1] | Should -Be 'start'
                    $ret[2] | Should -Be 'poststart'
                }

                It 'pspm install hooking' {
                    Mock pspm-install {'invoke'}

                    $ret = @(pspm install)
                    $ret | Should -HaveCount 4
                    $ret[0] | Should -Be 'preinstall'
                    $ret[1] | Should -Be 'invoke'
                    # install script should run after pspm-install
                    $ret[2] | Should -Be 'install'
                    $ret[3] | Should -Be 'postinstall'
                }

                It 'pspm uninstall hooking' {
                    Mock pspm-uninstall {'invoke'}

                    $ret = @(pspm uninstall 'mock')
                    $ret | Should -HaveCount 4
                    $ret[0] | Should -Be 'preuninstall'
                    # uninstall script should run before pspm-uninstall
                    $ret[1] | Should -Be 'uninstall'
                    $ret[2] | Should -Be 'invoke'
                    $ret[3] | Should -Be 'postuninstall'
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
