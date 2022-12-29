#Requires -Modules @{ ModuleName="Pester"; ModuleVersion="5.2" }

BeforeAll {
    Remove-Module pspm -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $PSScriptRoot '../../pspm.psd1') -Force
    $ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
}

Describe 'pspm integration test' {

    Context 'Command: version' {
        It 'pspm -v' {
            $info = Import-PowerShellDataFile -Path (Resolve-Path (Join-Path $PSScriptRoot '../../pspm.psd1'))
            pspm -v | Should -Be $info.ModuleVersion
        }

        It 'pspm -Version' {
            $info = Import-PowerShellDataFile -Path (Resolve-Path (Join-Path $PSScriptRoot '../../pspm.psd1'))
            pspm -Version | Should -Be $info.ModuleVersion
        }

        It 'pspm Version' {
            $info = Import-PowerShellDataFile -Path (Resolve-Path (Join-Path $PSScriptRoot '../../pspm.psd1'))
            pspm Version | Should -Be $info.ModuleVersion
        }
    }

    Context 'Command: script' {
        BeforeAll {
            Copy-Item (Join-Path $PSScriptRoot 'test-package.json') -Destination (Join-Path $TestDrive 'package.json') -Force
            Push-Location $TestDrive
        }

        AfterAll {
            Pop-Location
        }

        It 'pspm start' {
            pspm start | Should -Be 'prestart', 'start', 'poststart'
        }

        It 'pspm stop' {
            pspm stop | Should -Be 'prestop', 'stop', 'poststop'
        }

        It 'pspm restart' {
            pspm restart | Should -Be 'prerestart', 'restart', 'postrestart'
        }

        It 'pspm test' {
            pspm test | Should -Be 'pretest', 'test', 'posttest'
        }

        It 'pspm run xxx' {
            pspm run xxx | Should -Be 'prexxx', 'xxx', 'postxxx'
        }

        It 'pspm run argtest' {
            pspm run argtest -Arguments 'foo' | Should -Be 'foo'
        }

        It 'pspm run configtest' {
            pspm run configtest | Should -Be '8080'
        }

        It 'pspm run notexist' {
            {pspm run notexist -ea Stop} | Should -Throw
            {pspm run notexist -IfPresent -ea Stop} | Should -Not -Throw
        }
    }

    Context 'Command: install' {
        BeforeAll {
            Push-Location $TestDrive
        }

        BeforeEach {
            Copy-Item (Join-Path $PSScriptRoot 'test-package.json') -Destination (Join-Path $TestDrive 'package.json') -Force
            $iv = $null
        }

        AfterEach {
            pspm unload
            Remove-Module DHCPClient-PS -Force -ErrorAction SilentlyContinue
            Remove-Module PSSlack -Force -ErrorAction SilentlyContinue
            Remove-Item ./Modules -Force -Recurse -ErrorAction SilentlyContinue
            Remove-Item ./TestModules -Force -Recurse -ErrorAction SilentlyContinue
        }

        AfterAll {
            Pop-Location
        }

        It 'pspm install (From PSGallery, Non Version specific)' {
            pspm install DHCPClient-PS | Should -Be 'preinstall', 'install', 'postinstall'
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            Get-Module -Name DHCPClient-PS | Should -BeTrue
        }

        It 'pspm install (From PSGallery, Version specific)' {
            pspm install DHCPClient-PS@1.1.3 | Should -Be 'preinstall', 'install', 'postinstall'
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            Get-Module -Name DHCPClient-PS | select -ExpandProperty Version | Should -Be '1.1.3'
        }

        It 'pspm install (From GitHub, Non ref specific)' {
            pspm install mkht/DHCPClient-PS | Should -Be 'preinstall', 'install', 'postinstall'
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            Get-Module -Name DHCPClient-PS | Should -BeTrue
        }

        It 'pspm install (From GitHub, ref specific)' {
            pspm install 'mkht/DHCPClient-PS#25dd83b' | Should -Be 'preinstall', 'install', 'postinstall'
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            Get-Module -Name DHCPClient-PS | select -ExpandProperty Version | Should -Be '2.0.0'
        }

        It 'pspm install (From GitHub, Non ref specific, subdirectory)' {
            pspm install 'RamblingCookieMonster/PSSlack::PSSlack' | Should -Be 'preinstall', 'install', 'postinstall'
            Test-Path .\Modules\PSSlack -PathType Container | Should -BeTrue
            Get-Module -Name PSSlack | Should -BeTrue
        }

        It 'pspm install (From GitHub, ref specific, subdirectory)' {
            pspm install 'RamblingCookieMonster/PSSlack#1c9d6c0::PSSlack' | Should -Be 'preinstall', 'install', 'postinstall'
            Test-Path .\Modules\PSSlack -PathType Container | Should -BeTrue
            Get-Module -Name PSSlack | Should -BeTrue
        }

        It 'pspm install (NoImport)' {
            pspm install DHCPClient-PS -NoImport | Should -Be 'preinstall', 'install', 'postinstall'
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            Get-Module -Name DHCPClient-PS | Should -BeFalse
        }

        It 'pspm install (Clean)' {
            New-Item .\Modules\SomeDir -ItemType Directory
            'somefile' | Out-File .\Modules\SomeDir\SomeFile.txt -Force
            Test-Path .\Modules\SomeDir\SomeFile.txt | Should -BeTrue
            pspm install DHCPClient-PS -Clean
            Test-Path .\Modules\SomeDir\SomeFile.txt | Should -BeFalse
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            Get-Module -Name DHCPClient-PS | Should -BeTrue
        }

        It 'pspm install (Scope:Global)' {
            Mock Get-PSModulePath { Join-Path $TestDrive 'TestModules' } -ModuleName pspm
            Mock Test-AdminPrivilege { $true } -ModuleName pspm
            Test-Path .\TestModules\DHCPClient-PS -PathType Container | Should -BeFalse
            pspm install DHCPClient-PS -NoImport -Scope Global
            Test-Path .\TestModules\DHCPClient-PS -PathType Container | Should -BeTrue
        }

        It 'pspm install (Scope:CurrentUser)' {
            Mock Get-PSModulePath { Join-Path $TestDrive 'TestModules' } -ModuleName pspm
            Mock Test-AdminPrivilege { $true } -ModuleName pspm
            Test-Path .\TestModules\DHCPClient-PS -PathType Container | Should -BeFalse
            pspm install DHCPClient-PS -NoImport -Scope CurrentUser
            Test-Path .\TestModules\DHCPClient-PS -PathType Container | Should -BeTrue
        }

        It 'pspm install (Not download when already exists)' {
            pspm install 'mkht/DHCPClient-PS#25dd83b' -NoImport
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            pspm install 'mkht/DHCPClient-PS#25dd83b' -NoImport -InformationVariable iv
            (-join $iv) | Should -Match 'Skip download.'
        }

        It 'pspm install (Save to package.json)' {
            pspm install 'DSCR_NetscapeBookmark@1.1.0' -NoImport -Save
            $json = Get-Content .\package.json -Raw | ConvertFrom-Json
            $json.dependencies.DSCR_NetscapeBookmark | Should -BeExactly '^1.1.0'
        }
    }

    Context 'Command: install (package.json)' {
        BeforeAll {
            Push-Location $TestDrive
        }

        BeforeEach {
            Copy-Item (Join-Path $PSScriptRoot 'test-package.json') -Destination (Join-Path $TestDrive 'package.json') -Force
            $iv = $null
        }

        AfterEach {
            pspm unload
            Remove-Item ./Modules -Force -Recurse -ErrorAction SilentlyContinue
        }

        AfterAll {
            Pop-Location
        }

        It 'pspm install (package.json)' {
            pspm install -NoImport
            Test-Path .\Modules\KanaUtils -PathType Container | Should -BeTrue
            Test-Path .\Modules\powershell-yaml\0.4.2 -PathType Container | Should -BeTrue
            Test-Path .\Modules\AWSPowerShell.NetCore\4.0.* -PathType Container | Should -BeTrue
            Test-Path .\Modules\7ZipArchiveDsc -PathType Container | Should -BeTrue
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue
            Test-Path .\Modules\PSSQLite -PathType Container | Should -BeTrue
        }
    }

    Context 'Command: update' {
        BeforeAll {
            Push-Location $TestDrive
        }

        BeforeEach {
            Copy-Item (Join-Path $PSScriptRoot 'test-package.json') -Destination (Join-Path $TestDrive 'package.json') -Force
        }

        AfterEach {
            pspm unload
            Remove-Item ./Modules -Force -Recurse -ErrorAction SilentlyContinue
        }

        AfterAll {
            Pop-Location
        }

        It 'pspm update' {
            pspm install 'DHCPClient-PS@1.1.2' -NoImport -Save
            Test-Path .\Modules\DHCPClient-PS\1.1.2 -PathType Container | Should -BeTrue
            $json = Get-Content .\package.json -Raw | ConvertFrom-Json
            $json.dependencies.'DHCPClient-PS' | Should -BeExactly '^1.1.2'

            pspm update 'DHCPClient-PS@1.x' -NoImport | Should -Be 'preupdate', 'update', 'postupdate'
            Test-Path .\Modules\DHCPClient-PS\1.1.2 -PathType Container | Should -BeFalse
            Test-Path .\Modules\DHCPClient-PS\1.1.3 -PathType Container | Should -BeTrue
            $json = Get-Content .\package.json -Raw | ConvertFrom-Json
            $json.dependencies.'DHCPClient-PS' | Should -BeExactly '^1.1.3'
        }
    }

    Context 'Command: unintall' {
        BeforeAll {
            Push-Location $TestDrive
        }

        BeforeEach {
            Copy-Item (Join-Path $PSScriptRoot 'test-package.json') -Destination (Join-Path $TestDrive 'package.json') -Force
        }

        AfterEach {
            pspm unload
            Remove-Item ./Modules -Force -Recurse -ErrorAction SilentlyContinue
        }

        AfterAll {
            Pop-Location
        }

        It 'pspm uninstall' {
            pspm install 'DHCPClient-PS' -NoImport
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeTrue

            pspm uninstall 'DHCPClient-PS' | Should -Be 'preuninstall', 'uninstall', 'postuninstall'
            Test-Path .\Modules\DHCPClient-PS -PathType Container | Should -BeFalse
        }
    }
}
