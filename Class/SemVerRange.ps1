
enum Operator {
    Equal = 0
    LessThan
    LessEqual
    MoreThan
    MoreEqual
}

<#
.SYNOPSIS
This class express a range of SemVer

.DESCRIPTION
The SemVerRange class express a range of SemVer,
allowing you to parse range expression string,
and allowing you to test a SemVer satisfies the range or not.

.EXAMPLE
$Range = [SemVerRange]::new('1.2.x')
$Range.IsSatisfied('1.2.0')  # =>true
$Range.IsSatisfied('1.3.0')  # =>false

.NOTES
You can refer to the range syntax in the document of npm-semver.
(Some advanced syntax is not implemented yet, sorry.)
https://docs.npmjs.com/misc/semver
#>
Class SemVerRange {

    <#
    .DESCRIPTION
    The minimum version of range
    #>
    [SemVer]$MinimumVersion

    <#
    .DESCRIPTION
    The maximum version of range
    #>
    [SemVer]$MaximumVersion

    <#
    .DESCRIPTION
    Expression string of range
    #>
    [string]$Expression

    # private properties
    Hidden [Operator]$_GraterOperator = [Operator]::MoreEqual
    Hidden [Operator]$_LowerOperator = [Operator]::LessEqual

    #region <-- Constructor -->

    <#
    .SYNOPSIS
    Construct a new range from a min & max version

    .PARAMETER minimum
    The minimum version of a range. (>=min)

    .PARAMETER maximum
    The maximum version of a range. (<=max)
    #>
    SemVerRange([SemVer]$minimum, [SemVer]$maximum) {
        $this.MaximumVersion = $maximum
        $this.MinimumVersion = $minimum
        $this._GraterOperator = [Operator]::MoreEqual
        $this._LowerOperator = [Operator]::LessEqual

        $this.Expression = ('>={0} <={1}' -f [string]$minimum, [string]$maximum)
    }


    <#
    .SYNOPSIS
    Construct a new range from range expression string

    .PARAMETER expression
    The range expression string.

    .EXCEPTION [System.ArgumentException]
    Thrown when the range expression is invalid or unsupported.
    #>
    SemVerRange([string]$expression) {
        $isError = $false
        
        # All
        if (($expression -eq '') -or ($expression -eq '*')) {
            #empty or asterisk match all versions
            $this.Expression = '>=0.0.0'
        }

        # X-Ranges (1.x, 1.2.x, 1.2.*)
        elseif ($expression -match '^\d+(\.\d+)?\.[x\*]') {
            $regex = ([RegEx]::new('\d+(?=\.[x\*])', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))

            $this._RangeHelper($expression, $regex)
        }

        # Partial range (1, 1.2)
        elseif ($expression -match '^\d+(\.\d+)?$') {
            $newexp = $expression + '.x'    # treat as X-Range
            $regex = ([RegEx]::new('\d+(?=\.x)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))

            try {
                $this._RangeHelper($newexp, $regex)
            }
            catch [System.ArgumentException] {
                $isError = $true
            }
        }

        # Tilde Ranges
        elseif ($expression.StartsWith('~')) {
            # Tilde pattern 1 (~1, ~1.2)
            if ($expression -match '^~\d+(\.\d+)?$') {
                $newexp = $expression.Substring(1) + '.x'    # treat as X-Range
                $regex = ([RegEx]::new('\d+(?=\.x)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase))

                try {
                    $this._RangeHelper($newexp, $regex)
                }
                catch [System.ArgumentException] {
                    $isError = $true
                }
            }
            # Tilde pattern 2 (~1.2.3, ~1.2.3-beta)
            else {
                try {
                    [SemVer]$min = [SemVer]::Parse($expression.Substring(1))
                    [SemVer]$max = [SemVer]::new($min.Major, $min.Minor + 1, 0)

                    $this.MaximumVersion = $max
                    $this.MinimumVersion = $min
                    $this._GraterOperator = [Operator]::MoreEqual
                    $this._LowerOperator = [Operator]::LessThan
            
                    $this.Expression = ('>={0} <{1}' -f [string]$min, [string]$max)
                }
                catch {
                    $isError = $true
                }
            }
        }

        # Caret Ranges (^1.2, ^0.2.3)
        elseif ($expression.StartsWith('^')) {
            try {
                $escape = $expression.Substring(1).Split('-')
                [SemVer]$ver = [SemVer]::Parse([regex]::Replace($escape[0], '[xX\*]', '0'))
                [SemVer]$newver = $null

                if ($ver.Major -ne 0) {
                    $newver = [SemVer]::new($ver.Major + 1)
                }
                elseif ($ver.Minor -ne 0) {
                    $newver = [SemVer]::new($ver.Major, $ver.Minor + 1)
                }
                elseif ($ver.Patch -ne 0) {
                    $newver = [SemVer]::new($ver.Major, $ver.Minor, $ver.Patch + 1)
                }
                elseif ($ver.Revision -ne 0) {
                    $newver = [SemVer]::new($ver.Major, $ver.Minor, $ver.Patch, $ver.Revision + 1)
                }
                else {
                    $newver = [SemVer]('0.1.0')
                }

                $maxSemVer = $newver
                $minSemVer = [SemVer]::Parse([regex]::Replace($escape[0], '[xX\*]', '0') + '-' + $escape[1])
                $this.MaximumVersion = $maxSemVer
                $this.MinimumVersion = $minSemVer
                $this._GraterOperator = [Operator]::MoreEqual
                $this._LowerOperator = [Operator]::LessThan

                $this.Expression = ('>={0} <{1}' -f [string]$minSemVer, [string]$maxSemVer)
            }
            catch {
                $isError = $true
            }
        }
        
        elseif ($expression.StartsWith('>')) {
            if ($expression.Substring(1).StartsWith('=')) {
                #Grater equals (e.g. '>=1.2.0'
                $local:tempVersion = $expression.Substring(2)
                if ([SemVer]::TryParse($tempVersion, [ref]$null)) {
                    $this.MinimumVersion = [SemVer]::Parse($tempVersion)
                    $this._GraterOperator = [Operator]::MoreEqual
                }
                else {
                    $isError = $true
                }
            }
            else {
                #Grater than (e.g. '>1.2.0'
                $local:tempVersion = $expression.Substring(1)
                if ([SemVer]::TryParse($tempVersion, [ref]$null)) {
                    $this.MinimumVersion = [SemVer]::Parse($tempVersion)
                    $this._GraterOperator = [Operator]::MoreThan
                }
                else {
                    $isError = $true
                }
            }
        }
        elseif ($expression.StartsWith('<')) {
            if ($expression.Substring(1).StartsWith('=')) {
                #Less equals (e.g. '<=1.2.0'
                $local:tempVersion = $expression.Substring(2)
                if ([SemVer]::TryParse($tempVersion, [ref]$null)) {
                    $this.MaximumVersion = [SemVer]::Parse($tempVersion)
                    $this._LowerOperator = [Operator]::LessEqual
                }
                else {
                    $isError = $true
                }
            }
            else {
                #Less than (e.g. '<1.2.0'
                $local:tempVersion = $expression.Substring(1)
                if ([SemVer]::TryParse($tempVersion, [ref]$null)) {
                    $this.MaximumVersion = [SemVer]::Parse($tempVersion)
                    $this._LowerOperator = [Operator]::LessThan
                }
                else {
                    $isError = $true
                }
            }
        }

        # Strict
        elseif ([SemVer]::TryParse($expression, [ref]$null)) {
            #Specified strict version (e.g. '1.2.0'
            $this.MinimumVersion = [SemVer]::Parse($expression)
            $this.MaximumVersion = $this.MinimumVersion
            $this._GraterOperator = [Operator]::MoreEqual
            $this._LowerOperator = [Operator]::LessEqual
            
            $this.Expression = [string]$this.MinimumVersion
        }

        else {
            $isError = $true
        }

        if ($isError) {
            throw [System.ArgumentException]::new(('Invalid range expression: "{0}"' -f $expression))
        }
    }
    #endregion <-- Constructor -->


    <#
    .SYNOPSIS
    private helper method for X-Range parsing
    #>
    #region <-- _RangeHelper() -->
    Hidden [void] _RangeHelper([string]$expression, [regex]$regex) {
        $escape = $expression.Split('-')

        $match = $regex.Match($escape[0])
    
        $max = $regex.Replace($escape[0], ([int]$match.Value + 1)).Replace('x', '0').Replace('X', '0').Replace('*', '0')
        $min = $escape[0].Replace('x', '0').Replace('X', '0').Replace('*', '0') + '-' + $escape[1]

        try {
            $maxSemVer = [SemVer]::Parse($max)
            $minSemVer = [SemVer]::Parse($min)
            $this.MaximumVersion = $maxSemVer
            $this.MinimumVersion = $minSemVer
            $this._GraterOperator = [Operator]::MoreEqual
            $this._LowerOperator = [Operator]::LessThan

            $this.Expression = ('>={0} <{1}' -f [string]$minSemVer, [string]$maxSemVer)
        }
        catch [System.FormatException] {
            throw [System.ArgumentException]::new(('Invalid range expression: "{0}"' -f $expression))
        }
    }
    #endregion <-- _RangeHelper() -->


    #region <-- IsSatisfied() -->

    <#
    .SYNOPSIS
    Test whether the given version satisfies this range.

    .PARAMETER version
    The version to test

    .RETURN
    Return true if the version satisfies the range.
    #>
    [bool] IsSatisfied([SemVer]$version) {
        return [SemVerRange]::IsSatisfied($this, $version)
    }

    
    <#
    .SYNOPSIS
    Test whether the given version satisfies a given range.

    .PARAMETER range
    The range for test

    .PARAMETER version
    The version to test

    .RETURN
    Return true if the version satisfies the range.
    #>
    static [bool] IsSatisfied([SemVerRange]$range, [SemVer]$version) {

        $ret = $true

        if ($range.MinimumVersion) {
            switch ($range._GraterOperator) {
                MoreEqual {
                    $ret = $ret -and ($version -ge $range.MinimumVersion)
                    break
                }

                MoreThan {
                    $ret = $ret -and ($version -gt $range.MinimumVersion)
                    break
                }

                Default {
                    throw [System.InvalidOperationException]::new()
                }
            }
        }

        if ($range.MaximumVersion) {
            switch ($range._LowerOperator) {
                LessEqual {
                    $ret = $ret -and ($version -le $range.MaximumVersion)
                    break
                }

                LessThan {
                    $ret = $ret -and ($version -lt $range.MaximumVersion)
                    break
                }

                Default {
                    throw [System.InvalidOperationException]::new()
                }
            }
        }

        return $ret
    }
    #endregion <-- IsSatisfied() -->


    #region <-- MaxSatisfying() -->

    <#
    .SYNOPSIS
    Get the highest version in the list that satisfies this range.

    .PARAMETER versions
    The list of versions to test

    .RETURN
    Returns the highest version in the list that satisfies the range, or null if none of them do.

    .EXAMPLE
    $Range = [SemVerRange]::new('>1.2.3')
    $Range.MaxSatisfying(@('1.2.0', '1.2.4', '1.2.99'))
    # => returns '1.2.99'
    #>
    [SemVer] MaxSatisfying([SemVer[]]$versions) {
        return [SemVerRange]::MaxSatisfying($this, $versions)
    }


    <#
    .SYNOPSIS
    Get a highest version in the list that satisfies the given range.

    .PARAMETER range
    The range for test

    .PARAMETER versions
    The list of versions to test

    .RETURN
    Returns the highest version in the list that satisfies the range, or null if none of them do.

    .EXAMPLE
    [SemVerRange]::MaxSatisfying('>1.2.3', @('1.2.0', '1.2.4', '1.2.99'))
    # => returns '1.2.99'
    #>
    static [SemVer] MaxSatisfying([SemVerRange]$range, [SemVer[]]$versions) {
        $sortedVersions = ($versions | Sort-Object -Descending -Unique)

        foreach ($v in $sortedVersions) {
            if ($range.IsSatisfied($v)) {
                return $v
            }
        }

        return $null
    }
    #endregion <-- MaxSatisfying() -->


    #region <-- MinSatisfying() -->

    <#
    .SYNOPSIS
    Get the lowest version in the list that satisfies this range.

    .PARAMETER versions
    The list of versions to test

    .RETURN
    Returns the lowest version in the list that satisfies the range, or null if none of them do.

    .EXAMPLE
    $Range = [SemVerRange]::new('>1.2.3')
    $Range.MinSatisfying(@('1.2.0', '1.2.4', '1.2.99'))
    # => returns '1.2.4'
    #>
    [SemVer] MinSatisfying([SemVer[]]$versions) {
        return [SemVerRange]::MinSatisfying($this, $versions)
    }


    <#
    .SYNOPSIS
    Get a lowest version in the list that satisfies the given range.

    .PARAMETER range
    The range for test

    .PARAMETER versions
    The list of versions to test

    .RETURN
    Returns the lowest version in the list that satisfies the range, or null if none of them do.

    .EXAMPLE
    [SemVerRange]::MinSatisfying('>1.2.3', @('1.2.0', '1.2.4', '1.2.99'))
    # => returns '1.2.4'
    #>
    static [SemVer] MinSatisfying([SemVerRange]$range, [SemVer[]]$versions) {
        $sortedVersions = ($versions | Sort-Object -Unique)

        foreach ($v in $sortedVersions) {
            if ($range.IsSatisfied($v)) {
                return $v
            }
        }

        return $null
    }
    #endregion <-- MinSatisfying() -->


    #endregion <-- Satisfying() -->

    <#
    .SYNOPSIS
    Get all versions in the list that satisfies this range.

    .PARAMETER versions
    The list of versions to test

    .RETURN
    Returns the all version in the list that satisfies the range, or null if none of them do.

    .EXAMPLE
    $Range = [SemVerRange]::new('>1.2.3')
    $Range.MinSatisfying(@('1.2.0', '1.2.4', '1.2.99'))
    # => returns '1.2.4' & '1.2.99'
    #>
    [SemVer[]] Satisfying([SemVer[]]$versions) {
        return [SemVerRange]::Satisfying($this, $versions)
    }

    
    <#
    .SYNOPSIS
    Get all versions in the list that satisfies the given range.

    .PARAMETER range
    The range for test

    .PARAMETER versions
    The list of versions to test

    .RETURN
    Returns the all version in the list that satisfies the range, or null if none of them do.

    .EXAMPLE
    [SemVerRange]::Satisfying('>1.2.3', @('1.2.0', '1.2.4', '1.2.99'))
    # => returns '1.2.4' & '1.2.99'
    #>
    static [SemVer[]] Satisfying([SemVerRange]$range, [SemVer[]]$versions) {
        return ($versions | Where-Object {$range.IsSatisfied($_)})
    }
    #endregion <-- Satisfying() -->


    #region <-- ToString() -->
    <#
    .SYNOPSIS
    Get the range expression string

    .RETURN
    Range expression string
    #>
    [string] ToString(){
        return $this.Expression
    }
    #endregion <-- ToString() -->

}
