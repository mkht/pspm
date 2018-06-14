
class SemVer :IComparable {

    # Major
    [ValidateRange(0, [int]::MaxValue)]
    Hidden [int]$_Major

    # Minor
    [ValidateRange(0, [int]::MaxValue)]
    Hidden [int]$_Minor = 0

    # Patch
    [ValidateRange(0, [int]::MaxValue)]
    Hidden [int]$_Patch = 0

    # Revision
    [ValidateRange(0, [int]::MaxValue)]
    Hidden [int]$_Revision = 0

    # PreReleaseLabel
    [ValidatePattern('^[.0-9A-Za-z-]*$')]
    Hidden [string]$_PreReleaseLabel

    # BuildLabel
    [ValidatePattern('^[.0-9A-Za-z-]*$')]
    Hidden [string]$_BuildLabel

    #region <#---- init() ----#>
    Hidden init () {
        $Members = $this | Get-Member -Force -MemberType Property -Name '_*'
        ForEach ($Member in $Members) {
            $PublicPropertyName = $Member.Name -replace '_', ''
            # Define getter
            $Getter = "return `$this.{0}" -f $Member.Name
            # Define setter
            $Setter = "throw [System.Management.Automation.RuntimeException]::new('{0} is a ReadOnly property.')" -f $PublicPropertyName

            $AddMemberParams = @{
                Name        = $PublicPropertyName
                MemberType  = 'ScriptProperty'
                Value       = [ScriptBlock]::Create($Getter)
                SecondValue = [ScriptBlock]::Create($Setter)
            }
            $this | Add-Member @AddMemberParams
        }
    }
    #endregion <#---- init() ----#>

    #region Constructor
    SemVer([int]$major) {
        $this.init()
        $this._Major = $major
    }

    SemVer([int]$major, [int]$minor) {
        $this.init()
        $this._Major = $major
        $this._Minor = $minor
    }

    SemVer([int]$major, [int]$minor, [int]$patch) {
        $this.init()
        $this._Major = $major
        $this._Minor = $minor
        $this._Patch = $patch
    }

    SemVer([int]$major, [int]$minor, [int]$patch, [int]$revision) {
        $this.init()
        $this._Major = $major
        $this._Minor = $minor
        $this._Patch = $patch
        $this._Revision = $revision
    }

    SemVer([int]$major, [int]$minor, [int]$patch, [int]$revision, [string]$prerelease, [string]$build) {
        $this.init()
        $this._Major = $major
        $this._Minor = $minor
        $this._Patch = $patch
        $this._Revision = $revision
        $this._PreReleaseLabel = $prerelease
        $this._BuildLabel = $build
    }

    SemVer([version]$version) {
        $this.init()
        $this._Major = if ($version.Major -ge 0) {$version.Major} else {0}
        $this._Minor = if ($version.Minor -ge 0) {$version.Minor} else {0}
        $this._Patch = if ($version.Build -ge 0) {$version.Build} else {0}
        $this._Revision = if ($version.Revision -ge 0) {$version.Revision} else {0}
    }

    SemVer([string]$string) {
        $this.init()
        $private:semver = [SemVer]::Parse($string)
        $this._Major = $private:semver._Major
        $this._Minor = $private:semver._Minor
        $this._Patch = $private:semver._Patch
        $this._Revision = $private:semver._Revision
        $this._PreReleaseLabel = $private:semver._PreReleaseLabel
        $this._BuildLabel = $private:semver._BuildLabel
    }
    #endregion Constructor

    <#---- ToString() ----#>
    [String] ToString() {
        [string]$Ret = (($this._Major, $this._Minor, $this._Patch) -join '.')

        if ($this._Revision) {
            $Ret += ('.{0}' -f $this._Revision)
        }
        if ($this._PreReleaseLabel) {
            $Ret += ('-{0}' -f $this._PreReleaseLabel)
        }
        if ($this._BuildLabel) {
            $Ret += ('+{0}' -f $this._BuildLabel)
        }

        return $Ret
    }

    <#---- Parse() ----#>
    static [SemVer] Parse([string]$string) {
        # split major.minor.patch
        $local:numbers = $string.split('-')[0].split('+')[0].split('.')
        $tMajor = if ([int]::TryParse($numbers[0], [ref]$null)) {if (($n = [int]::Parse($numbers[0])) -ge 0) {$n} else {0}} else {throw [System.FormatException]}
        $tMinor = if (-not $numbers[1]) {0} elseif ([int]::TryParse($numbers[1], [ref]$null)) {if (($n = [int]::Parse($numbers[1])) -ge 0) {$n} else {0}} else {throw [System.FormatException]}
        $tPatch = if (-not $numbers[2]) {0} elseif ([int]::TryParse($numbers[2], [ref]$null)) {if (($n = [int]::Parse($numbers[2])) -ge 0) {$n} else {0}} else {throw [System.FormatException]}
        $tRevision = if (-not $numbers[3]) {0} elseif ([int]::TryParse($numbers[3], [ref]$null)) {if (($n = [int]::Parse($numbers[3])) -ge 0) {$n} else {0}} else {throw [System.FormatException]}
        
        # split prelease+buildmeta
        $local:prerelease = if (($i = $string.IndexOf('-')) -ge 1) {$string.Substring($i + 1)} #behind from hyphen
        $local:build = if (($j = $string.IndexOf('+')) -ge 1) {$string.Substring($j + 1)} #behind from plus

        if ($local:prerelease.length -gt $local:build.length) {
            if (-not [string]::IsNullOrEmpty($local:prerelease)) {
                $private:tmp = $local:prerelease.split('+')
                $tPreReleaseLabel = ([string]$private:tmp[0]).Trim()
                $tBuildLabel = ([string]$private:tmp[1]).Trim()
            }
        }
        else {
            if (-not [string]::IsNullOrEmpty($local:build)) {
                $tBuildLabel = ([string]$local:build).Trim()
            }
        }

        return [SemVer]::new($tMajor, $tMinor, $tPatch, $tRevision, $tPreReleaseLabel, $tBuildLabel)
    }

    <#---- TryParse() ----#>
    static [bool] TryParse([string]$string, [ref]$ref) {
        try {
            $private:tmp = [SemVer]::Parse($string)
            $ref.Value = $private:tmp
            return $true
        }
        catch {
            return $false
        }
    }

    <#---- CompareTo() ----#>
    [int] CompareTo([object]$semver) {
        $semver = [SemVer]$semver

        #Compare Major
        if ($this._Major -ne $semver._Major) {
            if ($this._Major -gt $semver._Major) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Minor
        elseif ($this._Minor -ne $semver._Minor) {
            if ($this._Minor -gt $semver._Minor) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Patch
        elseif ($this._Patch -ne $semver._Patch) {
            if ($this._Patch -gt $semver._Patch) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Revision
        elseif ($this._Revision -ne $semver._Revision) {
            if ($this._Revision -gt $semver._Revision) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Prerelease
        elseif ($this._PreReleaseLabel -or $semver._PreReleaseLabel) {
            if ((-not $this._PreReleaseLabel) -and $semver._PreReleaseLabel) {
                return 1
            }
            elseif ($this._PreReleaseLabel -and (-not $semver._PreReleaseLabel)) {
                return -1
            }
            elseif ($this._PreReleaseLabel -eq $semver._PreReleaseLabel) {
                return 0
            }
            else {
                $identifierMyself = @($this._PreReleaseLabel.split('.'))
                $identifierTarget = @($semver._PreReleaseLabel.split('.'))
                
                for ($i = 0; $i -le $identifierMyself.Count; $i++) {
                    if ($identifierMyself[$i] -eq $identifierTarget[$i]) {
                        continue
                    }

                    if ($identifierMyself -and (-not $identifierTarget[$i])) {
                        return 1
                    }
                    elseif ((-not $identifierMyself) -and $identifierTarget[$i]) {
                        return -1
                    }

                    else {
                        if ([string]$identifierMyself[$i] -gt [string]$identifierTarget[$i]) {
                            return 1
                        }
                        else {
                            return -1
                        }
                    }
                }
            }
        }

        return 0
    }
}