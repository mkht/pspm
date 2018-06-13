
class SemVer :IComparable {

    # Major
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Major

    # Minor
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Minor = 0

    # Patch
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Patch = 0

    # Revision
    [ValidateRange(0, [int]::MaxValue)]
    [int]$Revision = 0

    # PreReleaseLabel
    [ValidatePattern('^[.0-9A-Za-z-]*$')]
    [string]$PreReleaseLabel

    # BuildLabel
    [ValidatePattern('^[.0-9A-Za-z-]*$')]
    [string]$BuildLabel

    #region Constructor
    SemVer([int]$major) {
        $this.Major = $major
    }

    SemVer([int]$major, [int]$minor) {
        $this.Major = $major
        $this.Minor = $minor
    }

    SemVer([int]$major, [int]$minor, [int]$patch) {
        $this.Major = $major
        $this.Minor = $minor
        $this.Patch = $patch
    }

    SemVer([int]$major, [int]$minor, [int]$patch, [int]$revision) {
        $this.Major = $major
        $this.Minor = $minor
        $this.Patch = $patch
        $this.Revision = $revision
    }

    SemVer([int]$major, [int]$minor, [int]$patch, [int]$revision, [string]$prerelease, [string]$build) {
        $this.Major = $major
        $this.Minor = $minor
        $this.Patch = $patch
        $this.Revision = $revision
        $this.PreReleaseLabel = $prerelease
        $this.BuildLabel = $build
    }

    SemVer([version]$version) {
        $this.Major = if ($version.Major -ge 0) {$version.Major} else {0}
        $this.Minor = if ($version.Minor -ge 0) {$version.Minor} else {0}
        $this.Patch = if ($version.Build -ge 0) {$version.Build} else {0}
        $this.Revision = if ($version.Revision -ge 0) {$version.Revision} else {0}
    }

    SemVer([string]$string) {
        $private:semver = [SemVer]::Parse($string)
        $this.Major = $private:semver.Major
        $this.Minor = $private:semver.Minor
        $this.Patch = $private:semver.Patch
        $this.Revision = $private:semver.Revision
        $this.PreReleaseLabel = $private:semver.PreReleaseLabel
        $this.BuildLabel = $private:semver.BuildLabel
    }
    #endregion Constructor

    <#---- ToString() ----#>
    [String] ToString() {
        [string]$Ret = (($this.Major, $this.Minor, $this.Patch) -join '.')

        if ($this.Revision) {
            $Ret += ('.{0}' -f $this.Revision)
        }
        if ($this.PreReleaseLabel) {
            $Ret += ('-{0}' -f $this.PreReleaseLabel)
        }
        if ($this.BuildLabel) {
            $Ret += ('+{0}' -f $this.BuildLabel)
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
        if ($this.Major -ne $semver.Major) {
            if ($this.Major -gt $semver.Major) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Minor
        elseif ($this.Minor -ne $semver.Minor) {
            if ($this.Minor -gt $semver.Minor) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Patch
        elseif ($this.Patch -ne $semver.Patch) {
            if ($this.Patch -gt $semver.Patch) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Revision
        elseif ($this.Revision -ne $semver.Revision) {
            if ($this.Revision -gt $semver.Revision) {
                return 1
            }
            else {
                return -1
            }
        }

        #Compare Prerelease
        elseif ($this.PreReleaseLabel -or $semver.PreReleaseLabel) {
            if ((-not $this.PreReleaseLabel) -and $semver.PreReleaseLabel) {
                return 1
            }
            elseif ($this.PreReleaseLabel -and (-not $semver.PreReleaseLabel)) {
                return -1
            }
            elseif ($this.PreReleaseLabel -eq $semver.PreReleaseLabel) {
                return 0
            }
            else {
                $identifierMyself = @($this.PreReleaseLabel.split('.'))
                $identifierTarget = @($semver.PreReleaseLabel.split('.'))
                
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