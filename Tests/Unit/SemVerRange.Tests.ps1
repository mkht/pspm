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

    Describe 'pspm.SemVerRange' {
        Context 'Constructor' {

            It 'SemVerRange() returns a new range that not matched any (<0.0.0)' {
                $range = [pspm.SemVerRange]::new()
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::Min)
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                $range.IncludeMaximum | Should -Be $false
                $range.IncludeMinimum | Should -Be $false
                $range.Expression | Should -Be '<0.0.0'
            }

            It 'SemVerRange(min, max) returns a new range (>=min, <=max)' {
                $range = [pspm.SemVerRange]::new('1.0.0', '2.0.0')
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                $range.IncludeMaximum | Should -Be $true
                $range.IncludeMinimum | Should -Be $true
                $range.Expression | Should -Be '>=1.0.0 <=2.0.0'
            }

            It 'SemVerRange(min, max, includeMin, includeMax) pattern 1' {
                $range = [pspm.SemVerRange]::new('1.0.0', '2.0.0', $true, $false)
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                $range.IncludeMaximum | Should -Be $false
                $range.IncludeMinimum | Should -Be $true
                $range.Expression | Should -Be '>=1.0.0 <2.0.0'
            }

            It 'SemVerRange(min, max, includeMin, includeMax) pattern 2' {
                $range = [pspm.SemVerRange]::new('1.0.0', [pspm.SemVer]::Max, $false, $true)
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::Max)
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                $range.IncludeMaximum | Should -Be $true
                $range.IncludeMinimum | Should -Be $false
                $range.Expression | Should -Be '>1.0.0'
            }

            It 'SemVerRange(min, max, includeMin, includeMax) pattern 3' {
                $range = [pspm.SemVerRange]::new([pspm.SemVer]::Min, '2.0.0', $true, $true)
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                $range.IncludeMaximum | Should -Be $true
                $range.IncludeMinimum | Should -Be $true
                $range.Expression | Should -Be '<=2.0.0'
            }
        }

        Context 'Expression parsing' {

            Context 'operator' {
                It 'All range ("*")' {
                    $range = [pspm.SemVerRange]::new('*')
                    $range.Expression | Should -Be '>=0.0.0'
                }

                It 'All range ("")' {
                    $range = [pspm.SemVerRange]::new('')
                    $range.Expression | Should -Be '>=0.0.0'
                }

                It 'Strict range ("1.0.0")' {
                    $range = [pspm.SemVerRange]::new('1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '1.0.0'
                }

                It 'Strict range with leading "=vV" ("=vV1.0.0")' {
                    $range = [pspm.SemVerRange]::new('=vV1.0.0')
                    $range.Expression | Should -Be '1.0.0'
                }

                It 'Less than ("<1.0.0")' {
                    $range = [pspm.SemVerRange]::new('<1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '<1.0.0'
                }

                It 'Less equal ("<=1.0.0")' {
                    $range = [pspm.SemVerRange]::new('<=1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '<=1.0.0'
                }

                It 'Grater than (">1.0.0")' {
                    $range = [pspm.SemVerRange]::new('>1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::Max)
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $false
                    $range.Expression | Should -Be '>1.0.0'
                }

                It 'Grater equal (">=1.0.0")' {
                    $range = [pspm.SemVerRange]::new('>=1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::Max)
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.0.0'
                }
            }

            Context 'Hyphen Ranges' {

                It '"1.2.3 - 2.3.4" := >=1.2.3 <=2.3.4' {
                    $range = [pspm.SemVerRange]::new('1.2.3 - 2.3.4')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 3, 4))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 3))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.2.3 <=2.3.4'
                }

                It '"1.2 - 2.3.4" := >=1.2.0 <=2.3.4 (partial version is provided as the first)' {
                    $range = [pspm.SemVerRange]::new('1.2 - 2.3.4')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 3, 4))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 0))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.2.0 <=2.3.4'
                }

                It '"1.2.3 - 2" := >=1.2.3 <3.0.0 (partial version is provided as the second)' {
                    $range = [pspm.SemVerRange]::new('1.2.3 - 2')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(3, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 3))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.2.3 <3.0.0'
                }

                It '"=vV1.2.3 - =vV2.3.4" := >=1.2.3 <=2.3.4 (with leading ignore chars)' {
                    $range = [pspm.SemVerRange]::new('=vV1.2.3 - =vV2.3.4')
                    $range.Expression | Should -Be '>=1.2.3 <=2.3.4'
                }
            }

            Context 'X-Ranges' {

                It '"1.2.x" := >=1.2.0 <1.3.0' {
                    $range = [pspm.SemVerRange]::new('1.2.x')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 3, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 0))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.2.0 <1.3.0'
                }

                It '"1.X" := >=1.0.0 <2.0.0' {
                    $range = [pspm.SemVerRange]::new('1.X')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.0.0 <2.0.0'
                }

                It '"1.2.*" := >=1.0.0 <2.0.0' {
                    $range = [pspm.SemVerRange]::new('1.2.*')
                    $range.Expression | Should -Be '>=1.2.0 <1.3.0'
                }

                It '"vV=1.2.*" := >=1.0.0 <2.0.0 (with leading ignore chars)' {
                    $range = [pspm.SemVerRange]::new('vV=1.2.*')
                    $range.Expression | Should -Be '>=1.2.0 <1.3.0'
                }
            }

            Context 'Partial range (treated as X-Range)' {

                It '"1" := 1.x.x := >=1.0.0 <2.0.0' {
                    $range = [pspm.SemVerRange]::new('1')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.0.0 <2.0.0'
                }

                It '"1.2" := 1.2.x := >=1.2.0 <1.3.0' {
                    $range = [pspm.SemVerRange]::new('1.2')
                    $range.Expression | Should -Be '>=1.2.0 <1.3.0'
                }

                It '"=vV1.2" (with leading ignore chars)' {
                    $range = [pspm.SemVerRange]::new('=vV1.2')
                    $range.Expression | Should -Be '>=1.2.0 <1.3.0'
                }
            }

            Context 'Tilde Ranges' {

                It '"~0.2" := 0.2.x := >=0.2.0 <0.3.0' {
                    $range = [pspm.SemVerRange]::new('~0.2')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(0, 3, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(0, 2, 0))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=0.2.0 <0.3.0'
                }

                It '"~0.2.3" := >=0.2.3 <0.3.0' {
                    $range = [pspm.SemVerRange]::new('~0.2.3')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(0, 3, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(0, 2, 3))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=0.2.3 <0.3.0'
                }

                It '"~1.2.3-beta.2" := >=1.2.3-beta.2 <1.3.0' {
                    $range = [pspm.SemVerRange]::new('~1.2.3-beta.2')
                    $range.Expression | Should -Be '>=1.2.3-beta.2 <1.3.0'
                }

                It '"~=vV0.2" (with leading ignore chars)' {
                    $range = [pspm.SemVerRange]::new('~=vV0.2')
                    $range.Expression | Should -Be '>=0.2.0 <0.3.0'
                }
            }

            Context 'Caret Ranges' {

                It '"^1.2.3" := >=1.2.3 <2.0.0' {
                    $range = [pspm.SemVerRange]::new('^1.2.3')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 3))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.2.3 <2.0.0'
                }

                It '"^0.2.3" := >=0.2.3 <0.3.0' {
                    $range = [pspm.SemVerRange]::new('^0.2.3')
                    $range.Expression | Should -Be '>=0.2.3 <0.3.0'
                }

                It '"^0.0.3" := >=0.0.3 <0.0.4' {
                    $range = [pspm.SemVerRange]::new('^0.0.3')
                    $range.Expression | Should -Be '>=0.0.3 <0.0.4'
                }

                It '"^1.2.3-beta.2" := >=1.2.3-beta.2 <2.0.0' {
                    $range = [pspm.SemVerRange]::new('^1.2.3-beta.2')
                    $range.Expression | Should -Be '>=1.2.3-beta.2 <2.0.0'
                }

                It '"^0.0.x" := >=0.0.0 <0.1.0' {
                    $range = [pspm.SemVerRange]::new('^0.0.x')
                    $range.Expression | Should -Be '>=0.0.0 <0.1.0'
                }

                It '"^0" := >=0.0.0 <1.0.0' {
                    $range = [pspm.SemVerRange]::new('^0')
                    $range.Expression | Should -Be '>=0.0.0 <1.0.0'
                }

                It '"^=Vv0.2.3"  (with leading ignore chars)' {
                    $range = [pspm.SemVerRange]::new('^=Vv0.2.3')
                    $range.Expression | Should -Be '>=0.2.3 <0.3.0'
                }
            }

            Context 'Intersection sets' {
                
                It '<1.0.0 >2.0.0 := <0.0.0 (no intersection 1)' {
                    $range = [pspm.SemVerRange]::new('<1.0.0 >2.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $false
                    $range.Expression | Should -Be '<0.0.0'
                }

                It '<1.0.0 >=1.0.0 := <0.0.0 (no intersection 2)' {
                    $range = [pspm.SemVerRange]::new('<1.0.0 >=1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $false
                    $range.Expression | Should -Be '<0.0.0'
                }

                It '<=1.0.0 >=1.0.0 := 1.0.0 (boundary intersection)' {
                    $range = [pspm.SemVerRange]::new('<=1.0.0 >=1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '1.0.0'
                }

                It '>1.2.7 <=1.3.0' {
                    $range = [pspm.SemVerRange]::new('>1.2.7 <=1.3.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 3, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 7))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $false
                    $range.Expression | Should -Be '>1.2.7 <=1.3.0'
                }

                It '>1.2.7 <=1.3.0 <2.0.0 := >1.2.7 <=1.3.0' {
                    $range = [pspm.SemVerRange]::new('>1.2.7 <=1.3.0 <2.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 3, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 7))
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $false
                    $range.Expression | Should -Be '>1.2.7 <=1.3.0'
                }

                It '>1.0.0 <3.0.0 2.0.0 - 4.0.0 := >=2.0.0 <3.0.0 (mixed in hyphen ranges)' {
                    $range = [pspm.SemVerRange]::new('>1.0.0 <3.0.0 2.0.0 - 4.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(3, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=2.0.0 <3.0.0'
                }
            }

            Context 'Union sets' {
                
                It '1.0.0 || 2.0.0' {
                    $range = [pspm.SemVerRange]::new('1.0.0 || 2.0.0')
                    $range.RangeSet[0].Expression | Should -Be '1.0.0'
                    $range.RangeSet[1].Expression | Should -Be '2.0.0'
                }

                It '"1 || 2 || 3" := >=1.0.0 <4.0.0' {
                    $range = [pspm.SemVerRange]::new('1 || 2 || 3')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(4, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 0, 0))
                    $range.IncludeMaximum | Should -Be $false
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=1.0.0 <4.0.0'
                }

                It '"<2.0.0 || >1.0.0" := >=0.0.0' {
                    $range = [pspm.SemVerRange]::new('<2.0.0 || >1.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::Max)
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '>=0.0.0'
                }

                It '"<2.0.0 || 1.0.0 - 3.0.0" := <=3.0.0 (mixed in hyphen ranges)' {
                    $range = [pspm.SemVerRange]::new('<2.0.0 || 1.0.0 - 3.0.0')
                    $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(3, 0, 0))
                    $range.MinimumVersion | Should -Be ([pspm.SemVer]::Min)
                    $range.IncludeMaximum | Should -Be $true
                    $range.IncludeMinimum | Should -Be $true
                    $range.Expression | Should -Be '<=3.0.0'
                }

                It '1.2.7 || >=1.2.9 <2.0.0' {
                    $range = [pspm.SemVerRange]::new('1.2.7 || >=1.2.9 <2.0.0')
                    $range.RangeSet[0].Expression | Should -Be '1.2.7'
                    $range.RangeSet[1].Expression | Should -Be '>=1.2.9 <2.0.0'
                    $range.Expression | Should -Be '1.2.7 || >=1.2.9 <2.0.0'
                }
            }
        }

        Context 'IsSatisfied()' {

            It 'If parameters are Null, throw ArgumentNullException' {
                { [pspm.SemVerRange]::IsSatisfied($null, '1.0.0') } | Should -Throw
                { [pspm.SemVerRange]::IsSatisfied('1.0.0', $null) } | Should -Throw
            }

            It '"1.0.0" is satisfied "=1.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '=1.0.0') | Should -BeTrue
            }

            It '"1.0.0" is not satisfied "=2.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '=2.0.0') | Should -Not -BeTrue
            }

            It '"1.0.0" is satisfied ">0.1.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '>0.1.0') | Should -BeTrue
            }

            It '"1.0.0" is not satisfied ">1.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '>1.0.0') | Should  -Not -BeTrue
            }

            It '"1.0.0" is satisfied ">=1.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '>=1.0.0') | Should -BeTrue
            }

            It '"1.0.0" is satisfied "<2.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '<2.0.0') | Should -BeTrue
            }

            It '"1.0.0" is satisfied "<=1.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '<=1.0.0') | Should -BeTrue
            }

            It '"1.0.0" is not satisfied "<1.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '<1.0.0') | Should -Not -BeTrue
            }

            It '"0.5.0" is satisfied ">=0.1.0 <=1.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('0.5.0', '>=0.1.0 <=1.0.0') | Should -BeTrue
            }

            It '"1.5.0" is not satisfied ">=0.1.0 <=1.0.0"' {
                [pspm.SemVerRange]::IsSatisfied('1.5.0', '>=0.1.0 <=1.0.0') | Should -Not -BeTrue
            }

            It '"1.2.3" is satisfied "1.0.0 - 1.3.0" (Hyphen ranges)' {
                [pspm.SemVerRange]::IsSatisfied('1.2.3', '1.0.0 - 1.3.0') | Should -BeTrue
            }

            It '"1.2.3" is satisfied "1.x" (X-ranges)' {
                [pspm.SemVerRange]::IsSatisfied('1.2.3', '1.x') | Should -BeTrue
            }

            It '"1.2.3" & "1.2.9" are satisfied "~1.2.3" (Tilde pattern 1)' {
                [pspm.SemVerRange]::IsSatisfied('1.2.3', '~1.2.3') | Should -BeTrue
                [pspm.SemVerRange]::IsSatisfied('1.2.9', '~1.2.3') | Should -BeTrue
            }

            It '"0.2.99" is satisfied "~0.2.3" (Tilde pattern 2)' {
                [pspm.SemVerRange]::IsSatisfied('0.2.99', '~0.2.3') | Should -BeTrue
            }

            It '"1.2.99" is satisfied "^1.2.3" (Caret ranges)' {
                [pspm.SemVerRange]::IsSatisfied('1.2.99', '^1.2.3') | Should -BeTrue
            }

            It '"1.0.0" is satisfied "1.0.0 || 2.0.0" (Union sets)' {
                [pspm.SemVerRange]::IsSatisfied('1.0.0', '1.0.0 || 2.0.0') | Should -BeTrue
            }

            It '"3.0.0" is not satisfied "1.0.0 || 2.0.0" (Union sets)' {
                [pspm.SemVerRange]::IsSatisfied('3.0.0', '1.0.0 || 2.0.0') | Should -Not -BeTrue
            }

            It 'The range "1.2.7 || >=1.2.9 <2.0.0" would match the versions "1.2.7", "1.2.9", and "1.4.6", but not the versions "1.2.8" or "2.0.0"' {
                # complicated example from https://docs.npmjs.com/misc/semver#ranges
                $range = [pspm.SemVerRange]::new("1.2.7 || >=1.2.9 <2.0.0")
                [pspm.SemVerRange]::IsSatisfied('1.2.7', $range) | Should -BeTrue
                [pspm.SemVerRange]::IsSatisfied('1.2.9', $range) | Should -BeTrue
                [pspm.SemVerRange]::IsSatisfied('1.4.6', $range) | Should -BeTrue
                [pspm.SemVerRange]::IsSatisfied('1.2.8', $range) | Should -Not -BeTrue
                [pspm.SemVerRange]::IsSatisfied('2.0.0', $range) | Should -Not -BeTrue
            }

            It 'non static IsSatisfied()' {
                $range = [pspm.SemVerRange]::new(">=1.0.0")
                $range.IsSatisfied('1.2.3.4') | Should -BeTrue
            }
        }


        Context 'MaxSatisfying()' {

            It 'If parameters are Null, throw ArgumentNullException' {
                { [pspm.SemVerRange]::MaxSatisfying($null, '1.0.0') } | Should -Throw
                { [pspm.SemVerRange]::MaxSatisfying('1.0.0', $null) } | Should -Throw
            }

            It 'MaxSatisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3") returns "1.2.99"' {
                [pspm.SemVerRange]::MaxSatisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3") | Should -Be '1.2.99'
            }

            It 'MaxSatisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3 <1.2.10") returns "1.2.4"' {
                [pspm.SemVerRange]::MaxSatisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3 <1.2.10") | Should -Be '1.2.4'
            }

            It 'MaxSatisfying(@("0.2.0", "0.9.0"), ">1.0.0") returns null' {
                [pspm.SemVerRange]::MaxSatisfying(@("0.2.0", "0.9.0"), ">1.0.0") | Should -BeNullOrEmpty
            }

            It 'non static MaxSatisfying()' {
                $range = [pspm.SemVerRange]::new(">=1.0.0")
                $range.MaxSatisfying(@('2.0.0')) | Should -Be '2.0.0'
            }
        }


        Context 'MinSatisfying()' {

            It 'If parameters are Null, throw ArgumentNullException' {
                { [pspm.SemVerRange]::MinSatisfying($null, '1.0.0') } | Should -Throw
                { [pspm.SemVerRange]::MinSatisfying('1.0.0', $null) } | Should -Throw
            }

            It 'MinSatisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3") returns "1.2.4"' {
                [pspm.SemVerRange]::MinSatisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3") | Should -Be '1.2.4'
            }

            It 'MinSatisfying(@("0.2.0", "0.9.0"), ">1.0.0") returns null' {
                [pspm.SemVerRange]::MinSatisfying(@("0.2.0", "0.9.0"), ">1.0.0") | Should -BeNullOrEmpty
            }

            It 'non static MinSatisfying()' {
                $range = [pspm.SemVerRange]::new(">=1.0.0")
                $range.MinSatisfying(@('2.0.0')) | Should -Be '2.0.0'
            }
        }


        Context 'Satisfying()' {

            It 'Satisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3") returns 1.2.4 & 1.2.99' {
                $result = [pspm.SemVerRange]::Satisfying(@("1.2.0", "1.2.4", "1.2.99"), ">1.2.3")
                $result | Should -HaveCount 2
                $result | Should -Contain '1.2.4'
                $result | Should -Contain '1.2.99'
            }

            It 'Satisfying(@("0.2.0", "0.9.0"), ">1.0.0") returns empty array' {
                $result = [pspm.SemVerRange]::Satisfying(@("0.2.0", "0.9.0"), ">1.0.0")
                ($null -eq $result) | Should -Not -BeTrue   #should not return null
                $result | Should -HaveCount 0
            }

            It 'non static Satisfying()' {
                $range = [pspm.SemVerRange]::new(">=1.0.0")
                $result = $range.Satisfying(@('2.0.0'))
                $result | Should -HaveCount 1
            }
        }


        Context 'Intersect()' {

            It 'Intersect(">1.2.3", "<=2.0.0") should return new range of ">1.2.3 <=2.0.0"' {
                $range = [pspm.SemVerRange]::Intersect(">1.2.3", "<=2.0.0")
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 3))
                $range.IncludeMaximum | Should -Be $true
                $range.IncludeMinimum | Should -Be $false
                $range.Expression | Should -Be '>1.2.3 <=2.0.0'
            }

            It 'Intersect(">1.2.3", ">1.0.0 <=2.0.0") should return new range of ">1.2.3 <=2.0.0"' {
                $range = [pspm.SemVerRange]::Intersect(">1.2.3", ">1.0.0 <=2.0.0")
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(2, 0, 0))
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 3))
                $range.IncludeMaximum | Should -Be $true
                $range.IncludeMinimum | Should -Be $false
                $range.Expression | Should -Be '>1.2.3 <=2.0.0'
            }

            It 'Intersect("2.x || 4.x", ">2.3.0 <=4.5.0") should return new range of ">2.3.0 <3.0.0 || >=4.0.0 <=4.5.0"' {
                $range = [pspm.SemVerRange]::Intersect("2.x || 4.x", ">2.3.0 <=4.5.0")
                $range.RangeSet[0].Expression | Should -Be '>2.3.0 <3.0.0'
                $range.RangeSet[1].Expression | Should -Be '>=4.0.0 <=4.5.0'
            }

            It 'non static Intersect()' {
                $range = [pspm.SemVerRange]::new(">=1.0.0")
                $result = $range.Intersect('<2.0.0')
                $result.Expression | Should -Be '>=1.0.0 <2.0.0'
            }
        }

        Context 'IntersectAll()' {

            It 'If input is Null, throw ArgumentNullException' {
                { [pspm.SemVerRange]::IntersectAll($null) } | Should -Throw
            }

            It 'If input is single range, return input' {
                $result = [pspm.SemVerRange]::IntersectAll('>1.0.0')
                $result.Expression | Should -Be '>1.0.0'
            }

            It 'IntersectAll((">1.2.3", "<=2.0.0", ">0.1.0 <=1.9.9")) should return new range of ">1.2.3 <=1.9.9"' {
                $range = [pspm.SemVerRange]::IntersectAll((">1.2.3", "<=2.0.0", ">0.1.0 <=1.9.9"))
                $range.MaximumVersion | Should -Be ([pspm.SemVer]::new(1, 9, 9))
                $range.MinimumVersion | Should -Be ([pspm.SemVer]::new(1, 2, 3))
                $range.IncludeMaximum | Should -Be $true
                $range.IncludeMinimum | Should -Be $false
                $range.Expression | Should -Be '>1.2.3 <=1.9.9'
            }
        }


        Context 'ToString()' {
           
            It 'return expression string' {
                ([pspm.SemVerRange]::new('1.0.0', '2.0.0')).ToString() | Should -Be '>=1.0.0 <=2.0.0'
            }
        }
    }
}
finally {
    Remove-Module -Name $script:moduleName -Force
    Set-Location -Path $script:CurrentDir
}
#endregion Testing
