#region Initialize
$script:moduleName = 'pspm'
$script:moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$script:CurrentDir = $PWD

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

    Describe 'pspm.SemVer' {
        Context 'Constructor' {

            It 'SemVer([int]$major)' {
                $semver = [pspm.SemVer]::new(1)
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 0
                $semver.Patch | Should -Be 0
                $semver.Revision | Should -Be 0
                $semver.PreReleaseLabel | Should -BeNullOrEmpty
                $semver.BuildLabel | Should -BeNullOrEmpty
            }

            It 'SemVer([int]$major, [int]$minor)' {
                $semver = [pspm.SemVer]::new(1, 2)
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 0
                $semver.Revision | Should -Be 0
                $semver.PreReleaseLabel | Should -BeNullOrEmpty
                $semver.BuildLabel | Should -BeNullOrEmpty
            }

            It 'SemVer([int]$major, [int]$minor, [int]$patch)' {
                $semver = [pspm.SemVer]::new(1, 2, 3)
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.Revision | Should -Be 0
                $semver.PreReleaseLabel | Should -BeNullOrEmpty
                $semver.BuildLabel | Should -BeNullOrEmpty
            }

            It 'SemVer([int]$major, [int]$minor, [int]$patch, [int]$revision)' {
                $semver = [pspm.SemVer]::new(1, 2, 3, 4)
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.Revision | Should -Be 4
                $semver.PreReleaseLabel | Should -BeNullOrEmpty
                $semver.BuildLabel | Should -BeNullOrEmpty
            }

            It 'SemVer([int]$major, [int]$minor, [int]$patch, [int]$revision, [string]$prerelease, [string]$build)' {
                $semver = [pspm.SemVer]::new(1, 2, 3, 4, 'pre', 'build')
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.Revision | Should -Be 4
                $semver.PreReleaseLabel | Should -Be 'pre'
                $semver.BuildLabel | Should -Be 'build'
            }

            It 'SemVer([version]$version)' {
                $semver = [pspm.SemVer]::new([System.Version]::new('1.2.3'))
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.Revision | Should -Be 0
                $semver.PreReleaseLabel | Should -BeNullOrEmpty
                $semver.BuildLabel | Should -BeNullOrEmpty
            }

            It 'SemVer([string]$string)' {
                $semver = [pspm.SemVer]::new('1.2.3.4-pre+build')
                $semver = [pspm.SemVer]::new(1, 2, 3, 4, 'pre', 'build')
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.Revision | Should -Be 4
                $semver.PreReleaseLabel | Should -Be 'pre'
                $semver.BuildLabel | Should -Be 'build'
            }

            It '(SemVer("1.3.0") == SemVer(1, 3, 0)) should True (Issue #44)' {
                ([pspm.SemVer]::new("1.3.0") -eq [pspm.SemVer]::new(1, 3, 0)) | Should -BeTrue
            }
        }

        Context 'Properties validation test' {
                
            It 'Major should be >=0 && <=[int]::MaxValue' {
                { [pspm.SemVer]::new(-1)} | Should -Throw
                { [pspm.SemVer]::new(0)} | Should -Not -Throw
                { [pspm.SemVer]::new([int]::MaxValue)} | Should -Not -Throw
                { [pspm.SemVer]::new([int]::MaxValue + 1)} | Should -Throw
            }

            It 'Minor should be >=0 && <=[int]::MaxValue' {
                { [pspm.SemVer]::new(1, -1)} | Should -Throw
                { [pspm.SemVer]::new(1, 0)} | Should -Not -Throw
                { [pspm.SemVer]::new(1, [int]::MaxValue)} | Should -Not -Throw
                { [pspm.SemVer]::new(1, [int]::MaxValue + 1)} | Should -Throw
            }

            It 'Patch should be >=0 && <=[int]::MaxValue' {
                { [pspm.SemVer]::new(1, 1, -1)} | Should -Throw
                { [pspm.SemVer]::new(1, 1, 0)} | Should -Not -Throw
                { [pspm.SemVer]::new(1, 1, [int]::MaxValue)} | Should -Not -Throw
                { [pspm.SemVer]::new(1, 1, [int]::MaxValue + 1)} | Should -Throw
            }

            It 'Revision should be >=0 && <=[int]::MaxValue' {
                { [pspm.SemVer]::new(1, 1, 1, -1)} | Should -Throw
                { [pspm.SemVer]::new(1, 1, 1, 0)} | Should -Not -Throw
                { [pspm.SemVer]::new(1, 1, 1, [int]::MaxValue)} | Should -Not -Throw
                { [pspm.SemVer]::new(1, 1, 1, [int]::MaxValue + 1)} | Should -Throw
            }

            It 'PreReleaseLabel should match pattern "^[.0-9A-Za-z-]*$"' {
                { [pspm.SemVer]::new(1, 1, 1, 1, 'abcXYZ.-0123456789')} | Should -Not -Throw
                { [pspm.SemVer]::new(1, 1, 1, 1, 'a0+')} | Should -Throw
            }

            It 'BuildLabel should match pattern "^[.0-9A-Za-z-]*$"' {
                { [pspm.SemVer]::new(1, 1, 1, 1, 'pre', 'abcXYZ.-0123456789')} | Should -Not -Throw
                { [pspm.SemVer]::new(1, 1, 1, 1, 'pre', 'a0+')} | Should -Throw
            }
        }

        Context 'Read-only properties test' {

            It 'Major should be read-only' {
                $semver = [pspm.SemVer]::new(1)
                {$semver.Major = 123} | Should -Throw                    
            }

            It 'Minor should be read-only' {
                $semver = [pspm.SemVer]::new(1)
                {$semver.Minor = 123} | Should -Throw                    
            }

            It 'Patch should be read-only' {
                $semver = [pspm.SemVer]::new(1)
                {$semver.Patch = 123} | Should -Throw                    
            }

            It 'Revision should be read-only' {
                $semver = [pspm.SemVer]::new(1)
                {$semver.Revision = 123} | Should -Throw                    
            }

            It 'PreReleaseLabel should be read-only' {
                $semver = [pspm.SemVer]::new(1)
                {$semver.PreReleaseLabel = 'foo'} | Should -Throw                    
            }

            It 'BuildLabel should be read-only' {
                $semver = [pspm.SemVer]::new(1)
                {$semver.BuildLabel = 'foo'} | Should -Throw                    
            }                
        }

        Context 'ToString()' {

            It '"1" to "1.0.0" ( Major & Minor & Patch always display)' {
                [pspm.SemVer]::new(1).ToString() | Should -Be '1.0.0'
            }

            It '"1.2.3" to "1.2.3"' {
                [pspm.SemVer]::new(1, 2, 3).ToString() | Should -Be '1.2.3'
            }

            It '"1.2.3.0" to "1.2.3" (When Revision == 0, Revision should not be displayed)' {
                [pspm.SemVer]::new(1, 2, 3, 0).ToString() | Should -Be '1.2.3'
            }

            It '"1.2.3.4" to "1.2.3.4" (When Revision != 0, Revision should be displayed)' {
                [pspm.SemVer]::new(1, 2, 3, 4).ToString() | Should -Be '1.2.3.4'
            }

            It '"1.2.3.0-pre" to "1.2.3-pre"' {
                [pspm.SemVer]::new(1, 2, 3, 0, 'pre', $null).ToString() | Should -Be '1.2.3-pre'
            }

            It '"1.2.3.0-pre+build" to "1.2.3-pre+build"' {
                [pspm.SemVer]::new(1, 2, 3, 0, 'pre', 'build').ToString() | Should -Be '1.2.3-pre+build'
            }

            It '"1.2.3.0+build" to "1.2.3+build"' {
                [pspm.SemVer]::new(1, 2, 3, 0, $null, 'build').ToString() | Should -Be '1.2.3+build'
            }

            It '"1.2.3.4-pre+build" to "1.2.3.4-pre+build"' {
                [pspm.SemVer]::new(1, 2, 3, 4, 'pre', 'build').ToString() | Should -Be '1.2.3.4-pre+build'
            }
        }

        Context 'Parse()' {

            It '"major.minor.patch" pattern' {
                $semver = [pspm.SemVer]::Parse('1.2.3')
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
            }

            It '"major.minor.patch.revision" pattern' {
                $semver = [pspm.SemVer]::Parse('1.2.3.4')
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.Revision | Should -Be 4
            }

            It '"major.minor.patch-pre" pattern' {
                $semver = [pspm.SemVer]::Parse('1.2.3-pre')
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.PreReleaseLabel | Should -Be 'pre'
            }

            It '"major.minor.patch+build" pattern' {
                $semver = [pspm.SemVer]::Parse('1.2.3+build')
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.BuildLabel | Should -Be 'build'
            }

            It '"major.minor.patch-pre+build" pattern' {
                $semver = [pspm.SemVer]::Parse('1.2.3-pre+build')
                $semver.Major | Should -Be 1
                $semver.Minor | Should -Be 2
                $semver.Patch | Should -Be 3
                $semver.PreReleaseLabel | Should -Be 'pre'
                $semver.BuildLabel | Should -Be 'build'
            }

            It 'Invalid format should throw exception' {
                {[pspm.SemVer]::Parse('foo@bar')} |Should -Throw
            }
        }

        Context 'TryParse()' {
            It 'Return True on valid format' {
                $var = $null
                [pspm.SemVer]::TryParse('1.2.3.4-pre+build', [ref]$var) | Should -BeTrue
                $var.ToString() | Should -Be '1.2.3.4-pre+build'
            }

            It 'Return False on invalid format' {
                [pspm.SemVer]::TryParse('foo', [ref]$null) | Should -BeFalse
            }
        }

        Context 'CompareTo()' {
            It 'Throw exception if input object is not semver' {
                $semver = [pspm.SemVer]::new(1)
                {$semver.CompareTo(@{})} | Should -Throw
            }

            It '1.0.0 < 2.0.0 (Major compare)' {
                ([pspm.SemVer]'1.0.0' -lt '2.0.0') | Should -BeTrue
            }

            It '2.0.0 < 2.1.0 (Minor compare)' {
                ([pspm.SemVer]'2.0.0' -lt '2.1.0') | Should -BeTrue
            }

            It '2.1.0 < 2.1.1 (Patch compare)' {
                ([pspm.SemVer]'2.1.0' -lt '2.1.1') | Should -BeTrue
            }

            It '2.1.1.0 < 2.1.1.1 (Revision compare)' {
                ([pspm.SemVer]'2.1.1.0' -lt '2.1.1.1') | Should -BeTrue
            }

            It '1.0.0-alpha < 1.0.0 (Prerelease version has lower precedence than a normal version)' {
                ([pspm.SemVer]'1.0.0-alpha' -lt '1.0.0') | Should -BeTrue
            }

            It '1.0.0-alpha < 1.0.0-beta (Prerelease non-numeric compare)' {
                ([pspm.SemVer]'1.0.0-alpha' -lt '1.0.0-beta') | Should -BeTrue
            }

            It '1.0.0-alpha.1 < 1.0.0-alpha.2 (Prerelease numeric compare)' {
                ([pspm.SemVer]'1.0.0-alpha.1' -lt '1.0.0-alpha.2') | Should -BeTrue
            }

            It '1.0.0-alpha.1 < 1.0.0-alpha.beta (Numeric identifiers always have lower precedence than non-numeric identifiers)' {
                ([pspm.SemVer]'1.0.0-alpha.1' -lt '1.0.0-alpha.beta') | Should -BeTrue
            }

            It '1.0.0-A < 1.0.0-a (Non-numeric identifiers are compared lexically in ASCII sort order)' {
                ([pspm.SemVer]'1.0.0-A' -lt '1.0.0-a') | Should -BeTrue
            }

            It '1.0.0-alpha == 1.0.0-alpha+build (Build metadata does not figure into precedence)' {
                ([pspm.SemVer]'1.0.0-alpha' -le '1.0.0-alpha+build') | Should -BeTrue
                ([pspm.SemVer]'1.0.0-alpha' -ge '1.0.0-alpha+build') | Should -BeTrue
            }
        }

        Context 'Equals()' {
                
            It 'If parameter is null, should return False' {
                [pspm.SemVer]::new(1).Equals($null) | Should -Not -BeTrue
            }

            It '$bar.Equals($bar) should return True' {
                $bar = [pspm.SemVer]::new(1)
                $bar.Equals($bar) | Should -BeTrue
            }

            It '1.0.0 != 2.0.0 (Major compare)' {
                ([pspm.SemVer]'1.0.0' -eq '2.0.0') | Should -Not -BeTrue
            }

            It '2.0.0 != 2.1.0 (Minor compare)' {
                ([pspm.SemVer]'2.0.0' -eq '2.1.0') | Should -Not -BeTrue
            }

            It '2.1.0 != 2.1.1 (Patch compare)' {
                ([pspm.SemVer]'2.1.0' -eq '2.1.1') | Should -Not -BeTrue
            }

            It '2.1.1.0 != 2.1.1.1 (Revision compare)' {
                ([pspm.SemVer]'2.1.1.0' -eq '2.1.1.1') | Should -Not -BeTrue
            }

            It '1.0.0-alpha != 1.0.0-beta (Prerelease compare)' {
                ([pspm.SemVer]'1.0.0-alpha' -eq '1.0.0-beta') | Should -Not -BeTrue
            }

            It '1.0.0-alpha == 1.0.0-alpha' {
                ([pspm.SemVer]'1.0.0-alpha' -eq '1.0.0-alpha') | Should -BeTrue
            }

            It '1.0.0-alpha == 1.0.0-alpha+beta (Build metadata does not figure into precedence)' {
                ([pspm.SemVer]'1.0.0-alpha' -eq '1.0.0-alpha+build') | Should -BeTrue
            }
        }

        Context 'static members' {
                
            It '[pspm.SemVer]::Max indicates maximum semver' {
                ([pspm.SemVer]::Max -eq [pspm.SemVer]::new([int]::MaxValue, [int]::MaxValue, [int]::MaxValue, [int]::MaxValue)) | Should -BeTrue
            }

            It '[pspm.SemVer]::Min indicates minimum semver' {
                ([pspm.SemVer]::Min -eq [pspm.SemVer]::new(0)) | Should -BeTrue
            }
        }
    }
}
finally {
    Remove-Module -Name $script:moduleName -Force
    Set-Location -Path $script:CurrentDir
}
#endregion Testing
