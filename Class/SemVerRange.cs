using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

namespace pspm
{
    //:------------------------:
    #region SemVerRange
    //:------------------------:

    /// <summary>
    /// The SemVerRange class express a range of SemVer,
    /// allowing you to parse range expression string,
    /// and allowing you to test a SemVer satisfies the range or not.
    /// </summary>
    /// <example>
    /// <code>
    /// var Range = new SemVerRange("1.2.x");
    /// Range.IsSatisfied('1.2.0');  // =>true
    /// Range.IsSatisfied('1.3.0');  // =>false
    /// </code>
    /// </example>
    /// <seealso>
    /// You can refer to the range syntax in the document of npm-semver.
    /// (Some advanced syntax is not implemented yet, sorry.)
    /// https://docs.npmjs.com/misc/semver
    /// </seealso>
    public class SemVerRange
    {

        /// <summary>
        /// The minimum version of range
        /// </summary>
        public SemVer MinimumVersion { get; private set; }

        /// <summary>
        /// The maximum version of range
        /// </summary>
        public SemVer MaximumVersion { get; private set; }

        /// <summary>
        /// Whether or not to include the maximum version
        /// </summary>
        public bool IncludeMinimum { get; private set; }

        /// <summary>
        /// Whether or not to include the minimum version
        /// </summary>
        public bool IncludeMaximum { get; private set; }

        /// <summary>
        /// Expression string of range
        /// </summary>
        public string Expression { get; private set; }
        public SemVerRange[] RangeSet { get; private set; }


        /// <summary>
        /// Construct a new range that not matched any of versions (<0.0.0)
        /// </summary>
        public SemVerRange()
        {
            this.MaximumVersion = SemVer.Min;
            this.MinimumVersion = SemVer.Min;
            this.IncludeMaximum = false;
            this.IncludeMinimum = false;
            this.Expression = "<0.0.0";

            this.RangeSet = new SemVerRange[] { this };
        }


        /// <summary>
        /// Construct a new range from a min &amp; max version
        /// </summary>
        /// <param name="min">The minimum version of a range (&lt;=min)</param>
        /// <param name="max">The maximum version of a range (&lt;=max)</param>
        public SemVerRange(SemVer min, SemVer max)
        {
            this.MaximumVersion = min;
            this.MinimumVersion = max;
            this.IncludeMaximum = true;
            this.IncludeMinimum = true;
            this.Expression = $">={min.ToString()} <={max.ToString()}";

            this.RangeSet = new SemVerRange[] { this };
        }


        /// <summary>
        /// Construct a new range from a min &amp; max version
        /// </summary>
        /// <param name="min">The minimum version of a range (&lt;=min)</param>
        /// <param name="max">The maximum version of a range (&lt;=max)</param>
        /// <param name="includeMin">Whether or not to include the minimum version</param>
        /// <param name="includeMax">Whether or not to include the maximum version</param>
        public SemVerRange(SemVer min, SemVer max, bool includeMin, bool includeMax)
        {
            this.MaximumVersion = min;
            this.MinimumVersion = max;
            this.IncludeMaximum = includeMax;
            this.IncludeMinimum = includeMin;

            var opmin = (includeMin == true) ? ">=" : ">";
            var opmax = (includeMax == true) ? "<=" : "<";
            this.Expression = $"{opmin}{min.ToString()} {opmax}{max.ToString()}";

            this.RangeSet = new SemVerRange[] { this };
        }


        /// <summary>
        /// Construct a new range from range expression string
        /// </summary>
        /// <param name="expression">The range expression string</param>
        /// <exception cref="System.ArgumentException">Thrown when the range expression is invalid or unsupported</exception>
        public SemVerRange(string expression)
        {
            List<SemVerRange> rangeSet = new List<SemVerRange>();

            List<string> allExpressions = Regex.Split(expression.Trim(), @"\|\|").Select(e => e.Trim()).Where(e => !string.IsNullOrEmpty(e)).ToList();

            foreach (var subexp in allExpressions)
            {
                string[] subIntersection = subexp.Split(null).Select(s => s.Trim()).Where(e => !string.IsNullOrEmpty(e)).ToArray();

                List<SemVerRange> intersectionSet = new List<SemVerRange>();
                foreach (var sub in subIntersection)
                {
                    intersectionSet.Add(Parse(sub));
                }

                rangeSet.Add(IntersectAll(intersectionSet.ToArray()));
            }

            SemVerRange[] rangeSetArray = rangeSet.ToArray();
            if (rangeSetArray.Length >= 1)
            {
                this.MinimumVersion = rangeSetArray[0].MinimumVersion;
                this.MaximumVersion = rangeSetArray[0].MaximumVersion;
                this.IncludeMinimum = rangeSetArray[0].IncludeMinimum;
                this.IncludeMaximum = rangeSetArray[0].IncludeMaximum;
                this.Expression = rangeSetArray[0].Expression;
                this.RangeSet = rangeSetArray;
            }

            if (rangeSetArray.Length >= 2)
            {
                this.Expression = string.Join(" || ", rangeSetArray.Select(e => e.Expression));
            }
        }


        // Parse()
        private static SemVerRange Parse(string expression)
        {
            var isError = false;

            SemVerRange range = new SemVerRange();

            //All
            if (string.IsNullOrEmpty(expression) || expression.Equals("*"))
            {
                // empty or asterisk match all versions
                range.MaximumVersion = SemVer.Max;
                range.MinimumVersion = SemVer.Min;
                range.IncludeMaximum = true;
                range.IncludeMinimum = true;
                range.Expression = ">=0.0.0";
            }

            // X-Ranges (1.x, 1.2.x, 1.2.*)
            else if (Regex.IsMatch(expression, @"^\d+(\.\d+)?\.[x\*]", RegexOptions.IgnoreCase))
            {
                var regex = new Regex(@"\d+(?=\.[x\*])", RegexOptions.IgnoreCase);

                range = _RangeHelper(expression, regex);
            }

            // Partial range (1, 1.2)
            else if (Regex.IsMatch(expression, @"^\d+(\.\d+)?$", RegexOptions.IgnoreCase))
            {
                string newexp = expression + ".x";  //treat as X-Range
                var regex = new Regex(@"\d+(?=\.x)", RegexOptions.IgnoreCase);

                try
                {
                    range = _RangeHelper(newexp, regex);
                }
                catch (ArgumentException)
                {
                    isError = true;
                }
            }

            //Tilde Ranges
            else if (expression.StartsWith("~"))
            {
                // Tilde pattern 1 (~1, ~1.2)
                if (Regex.IsMatch(expression, @"^~\d+(\.\d+)?$", RegexOptions.IgnoreCase))
                {
                    var newexp = expression.Substring(1) + ".x";    // treat as X-Range
                    var regex = new Regex(@"\d+(?=\.x)", RegexOptions.IgnoreCase);

                    try
                    {
                        range = _RangeHelper(newexp, regex);
                    }
                    catch (ArgumentException)
                    {
                        isError = true;
                    }
                }
                // Tilde pattern 2 (~1.2.3, ~1.2.3-beta)
                else
                {
                    try
                    {
                        SemVer min = SemVer.Parse(expression.Substring(1));
                        SemVer max = new SemVer(min.Major, min.Minor + 1, 0);

                        range.MaximumVersion = max;
                        range.MinimumVersion = min;
                        range.IncludeMinimum = true;
                        range.IncludeMaximum = false;
                        range.Expression = $">={min.ToString()} <{max.ToString()}";
                    }
                    catch (Exception)
                    {
                        isError = true;
                    }
                }
            }

            // Caret Ranges (^1.2, ^0.2.3)
            else if (expression.StartsWith("^"))
            {
                try
                {
                    var escape = expression.Substring(1).Split('-');
                    SemVer ver = SemVer.Parse(Regex.Replace(escape[0], @"[xX\*]", "0"));
                    SemVer newver = null;

                    if (ver.Major != 0)
                    {
                        newver = new SemVer(ver.Major + 1);
                    }
                    else if (ver.Minor != 0)
                    {
                        newver = new SemVer(ver.Major, ver.Minor + 1);
                    }
                    else if (ver.Patch != 0)
                    {
                        newver = new SemVer(ver.Major, ver.Minor, ver.Patch + 1);
                    }
                    else if (ver.Revision != 0)
                    {
                        newver = new SemVer(ver.Major, ver.Minor, ver.Patch, ver.Revision + 1);
                    }
                    else
                    {
                        newver = new SemVer(0, 1, 0);
                    }

                    var maxSemVer = newver;
                    var minSemVer = SemVer.Parse(Regex.Replace(escape[0], @"[xX\*]", "0") + "-" + (escape.Length >= 2 ? escape[1] : ""));
                    range.MaximumVersion = maxSemVer;
                    range.MinimumVersion = minSemVer;
                    range.IncludeMinimum = true;
                    range.IncludeMaximum = false;

                    range.Expression = $">={minSemVer.ToString()} <{maxSemVer.ToString()}";
                }
                catch (Exception)
                {
                    isError = true;
                }
            }

            // Grater equals (>=1.2.0)
            else if (expression.StartsWith(">="))
            {
                var tmp = expression.Substring(2);

                if (SemVer.TryParse(tmp, out SemVer tmpVer))
                {
                    range.MaximumVersion = SemVer.Max;
                    range.MinimumVersion = tmpVer;
                    range.IncludeMaximum = true;
                    range.IncludeMinimum = true;
                    range.Expression = $">={tmpVer.ToString()}";
                }
                else
                {
                    isError = true;
                }
            }

            // Grater than (>1.2.0)
            else if (expression.StartsWith(">"))
            {
                var tmp = expression.Substring(1);

                if (SemVer.TryParse(tmp, out SemVer tmpVer))
                {
                    range.MaximumVersion = SemVer.Max;
                    range.MinimumVersion = tmpVer;
                    range.IncludeMaximum = true;
                    range.IncludeMinimum = false;
                    range.Expression = $">{tmpVer.ToString()}";
                }
                else
                {
                    isError = true;
                }
            }

            // Less equals (<=1.2.0)
            else if (expression.StartsWith("<="))
            {
                var tmp = expression.Substring(2);

                if (SemVer.TryParse(tmp, out SemVer tmpVer))
                {
                    range.MaximumVersion = tmpVer;
                    range.MinimumVersion = SemVer.Min;
                    range.IncludeMaximum = true;
                    range.IncludeMinimum = true;
                    range.Expression = $"<={tmpVer.ToString()}";
                }
                else
                {
                    isError = true;
                }
            }

            // Less than (<1.2.0)
            else if (expression.StartsWith("<"))
            {
                var tmp = expression.Substring(1);

                if (SemVer.TryParse(tmp, out SemVer tmpVer))
                {
                    range.MaximumVersion = tmpVer;
                    range.MinimumVersion = SemVer.Min;
                    range.IncludeMaximum = false;
                    range.IncludeMinimum = true;
                    range.Expression = $"<{tmpVer.ToString()}";
                }
                else
                {
                    isError = true;
                }
            }

            // Strict
            else
            {
                var tmp = expression.StartsWith("=") ? expression.Substring(1) : expression;

                if (SemVer.TryParse(tmp, out SemVer tmpVer))
                {
                    range.MaximumVersion = tmpVer;
                    range.MinimumVersion = tmpVer;
                    range.IncludeMaximum = true;
                    range.IncludeMinimum = true;
                    range.Expression = tmpVer.ToString();
                }
                else
                {
                    isError = true;
                }
            }

            if (isError == true)
            {
                throw new ArgumentException($"Invalid range expression: \"{expression}\"");
            }

            return range;
        }


        // _RangeHelper()
        private static SemVerRange _RangeHelper(string expression, Regex regex)
        {
            var escape = expression.Split('-');
            var match = regex.Match(escape[0]);

            var max = regex.Replace(escape[0], (int.Parse(match.Value) + 1).ToString()).Replace('x', '0').Replace('X', '0').Replace('*', '0');
            var min = escape[0].Replace('x', '0').Replace('X', '0').Replace('*', '0') + '-' + (escape.Length >= 2 ? escape[1] : "");

            try
            {
                var ret = new SemVerRange();
                var maxSemVer = SemVer.Parse(max);
                var minSemVer = SemVer.Parse(min);

                ret.MaximumVersion = maxSemVer;
                ret.MinimumVersion = minSemVer;
                ret.IncludeMinimum = true;
                ret.IncludeMaximum = false;
                ret.Expression = $">={minSemVer.ToString()} <{maxSemVer.ToString()}";

                return ret;
            }
            catch (FormatException)
            {
                throw new ArgumentException($"Invalid range expression: \"{expression}\"");
            }
        }


        /// <summary>
        /// Test whether the given version satisfies this range
        /// </summary>
        /// <param name="range">The range for test</param>
        /// <param name="version">The version to test</param>
        /// <returns>Return true if the version satisfies the range</returns>
        /// <exception cref="System.ArgumentNullException">Thrown when parameter is null</exception>
        public static bool IsSatisfied(SemVerRange range, SemVer version)
        {
            if (range == null || version == null) { throw new ArgumentNullException(); }

            foreach (var subRange in range.RangeSet)
            {
                bool ret = true;

                if (subRange.MinimumVersion != null)
                {
                    if (subRange.IncludeMinimum == true)
                    {
                        ret &= (version >= subRange.MinimumVersion);
                    }
                    else
                    {
                        ret &= (version > subRange.MinimumVersion);
                    }
                }

                if (subRange.MaximumVersion != null)
                {
                    if (subRange.IncludeMaximum == true)
                    {
                        ret &= (version <= subRange.MaximumVersion);
                    }
                    else
                    {
                        ret &= (version < subRange.MaximumVersion);
                    }
                }

                if (ret == true)
                {
                    // short-circuit evaluation
                    return true;
                }
            }

            return false;
        }

        /// <summary>
        /// Test whether the given version satisfies this range
        /// </summary>
        /// <param name="version">The version to test</param>
        /// <returns>Return true if the version satisfies the range</returns>
        /// <exception cref="System.ArgumentNullException">Thrown when parameter is null</exception>
        public bool IsSatisfied(SemVer version) => IsSatisfied(this, version);


        /// <summary>
        /// Get the highest version in the list that satisfies given range
        /// </summary>
        /// <param name="range">The range for test</param>
        /// <param name="versions">The list of versions to test</param>
        /// <returns>Returns the highest version in the list that satisfies the range, or null if none of them do</returns>
        /// <example>
        /// <code>SemVerRange.MaxSatisfying(">1.2.3", new SemVer[]{"1.2.0", "1.2.4", "1.2.99"}); // =>returns "1.2.99"</code>
        /// </example>
        /// <exception cref="System.ArgumentNullException">Thrown when parameter is null</exception>
        public static SemVer MaxSatisfying(SemVerRange range, IEnumerable<SemVer> versions)
        {
            if (versions == null || range == null) { throw new ArgumentNullException(); }

            var dsc = versions.Distinct().OrderByDescending(a => a);
            foreach (var v in dsc)
            {
                if (range.IsSatisfied(v) == true)
                {
                    return v;
                }
            }

            return null;
        }


        /// <summary>
        /// Get the highest version in the list that satisfies this range
        /// </summary>
        /// <param name="versions">The list of versions to test</param>
        /// <returns>Returns the highest version in the list that satisfies the range, or null if none of them do</returns>
        /// <exception cref="System.ArgumentNullException">Thrown when parameter is null</exception>
        public SemVer MaxSatisfying(IEnumerable<SemVer> versions) => MaxSatisfying(this, versions);


        /// <summary>
        /// Get the lowest version in the list that satisfies given range
        /// </summary>
        /// <param name="range">The range for test</param>
        /// <param name="versions">The list of versions to test</param>
        /// <returns>Returns the lowest version in the list that satisfies the range, or null if none of them do</returns>
        /// <example>
        /// <code>SemVerRange.MinSatisfying(">1.2.3", new Semver[]{"1.2.0", "1.2.4", "1.2.99"}); // =>returns "1.2.4"</code>
        /// </example>
        /// <exception cref="System.ArgumentNullException">Thrown when parameter is null</exception>
        public static SemVer MinSatisfying(SemVerRange range, IEnumerable<SemVer> versions)
        {
            if (versions == null || range == null) { throw new ArgumentNullException(); }

            var dsc = versions.Distinct().OrderBy(a => a);
            foreach (var v in dsc)
            {
                if (range.IsSatisfied(v) == true)
                {
                    return v;
                }
            }

            return null;
        }


        /// <summary>
        /// Get the lowest version in the list that satisfies this range
        /// </summary>
        /// <param name="versions">The list of versions to test</param>
        /// <returns>Returns the lowest version in the list that satisfies the range, or null if none of them do</returns>
        public SemVer MinSatisfying(IEnumerable<SemVer> versions) => MinSatisfying(this, versions);


        /// <summary>
        /// Get all versions in the list that satisfies the given range
        /// </summary>
        /// <param name="range">The range for test</param>
        /// <param name="versions">The list of versions to test</param>
        /// <returns>Returns all versions in the list that satisfies the range, or empty array if none of them do</returns>
        /// <example>
        /// <code>SemVerRange.Satisfying(">1.2.3", new SemVer[]{"1.2.0", "1.2.4", "1.2.99"}); // =>returns {"1.2.4", "1.2.9"}</code>
        /// </example>
        public static IEnumerable<SemVer> Satisfying(SemVerRange range, IEnumerable<SemVer> versions)
        {
            return versions.Where(v => range.IsSatisfied(v)).ToArray();
        }


        /// <summary>
        /// Get all versions in the list that satisfies the this range
        /// </summary>
        /// <param name="versions">The list of versions to test</param>
        /// <returns>Returns all versions in the list that satisfies the range, or empty array if none of them do</returns>
        public IEnumerable<SemVer> Satisfying(IEnumerable<SemVer> versions) => Satisfying(this, versions);


        /// <summary>
        /// Calculate the intersection between two ranges
        /// </summary>
        /// <param name="range0">The Range to intersect with range1</param>
        /// <param name="range1">The Range to intersect with range0</param>
        /// <returns>
        /// Return the range that intersects between two ranges
        /// NOTE: If either range0 or range1 is null, it returns the non-null range
        /// </returns>
        /// <example>
        /// <code>
        /// SemVerRange.Intersect(">1.0.0", "<=2.0.0");
        /// // => returns a new range that expressed for ">1.0.0 <=2.0.0"
        /// </code>
        /// </example>
        /// <exception cref="System.ArgumentNullException">Thrown if both range0 and range1 are null</exception>
        public static SemVerRange Intersect(SemVerRange range0, SemVerRange range1)
        {
            if (range0 == null && range1 == null) { throw new ArgumentNullException(); }
            if (range0 == null) { return range1; }
            if (range1 == null) { return range0; }

            SemVer newMax = null;
            SemVer newMin = null;
            bool newIncludeMax = false;
            bool newIncludeMin = false;

            SemVerRange higher, lower;
            Console.WriteLine("IntersectA");

            //sort
            if (range0.MaximumVersion > range1.MaximumVersion)
            {
                Console.WriteLine("sort 1");

                higher = range0;
                lower = range1;
            }
            else
            {
                Console.WriteLine("sort 2");

                higher = range1;
                lower = range0;
            }

            // no intersection
            Console.WriteLine("no Intersect");

            if (lower.MaximumVersion < higher.MinimumVersion)
            {
                return new SemVerRange();
            }

            // determine higher limit
            Console.WriteLine("determine higher limit");

            if (lower.MaximumVersion == higher.MinimumVersion)
            {
                if (lower.IncludeMaximum && higher.IncludeMinimum)
                {
                    newMax = lower.MaximumVersion;
                    newIncludeMax = true;
                }
                else
                {
                    return new SemVerRange();
                }
            }
            else if (lower.MaximumVersion == higher.MaximumVersion)
            {
                newMax = lower.MaximumVersion;
                newIncludeMax = (lower.IncludeMaximum && higher.IncludeMinimum);
            }
            else
            {
                newMax = lower.MaximumVersion;
                newIncludeMax = lower.IncludeMaximum;
            }

            // determine lower limit
            Console.WriteLine("determine lower limit");

            if (higher.MinimumVersion > lower.MinimumVersion)
            {
                newMin = higher.MinimumVersion;
                newIncludeMin = higher.IncludeMinimum;
            }
            else if (higher.MinimumVersion == lower.MinimumVersion)
            {
                newMin = higher.MinimumVersion;
                newIncludeMin = (higher.IncludeMinimum && lower.IncludeMinimum);
            }
            else
            {
                newMin = lower.MinimumVersion;
                newIncludeMin = lower.IncludeMinimum;
            }

            Console.WriteLine($"min:{newMin} max:{newMax} inmin:{newIncludeMin} inmax:{newIncludeMax}");
            return new SemVerRange(newMin, newMax, newIncludeMin, newIncludeMax);
        }


        /// <summary>
        /// Calculate the intersection between two ranges
        /// </summary>
        /// <param name="range">The Range to intersect with</param>
        /// <param name="range1">The Range to intersect with range0</param>
        /// <returns>
        /// Return the range that intersects between two ranges
        /// NOTE: If the input range is null, it returns this range
        /// </returns>
        public SemVerRange Intersect(SemVerRange range) => Intersect(this, range);


        /// <summary>
        /// Calculate the intersection of multiple ranges
        /// </summary>
        /// <param name="ranges">The collection of ranges</param>
        /// <returns>Return the range that intersects with all ranges</returns>
        /// <example>
        /// <code>SemVerRange.IntersectAll(new SemVerRange[]{">1.0.0", "<=2.0.0", "*"});</code>
        /// </example>
        /// <exception cref="System.ArgumentNullException">Thrown when input is null</exception>
        public static SemVerRange IntersectAll(ICollection<SemVerRange> ranges)
        {
            if (ranges == null) { throw new ArgumentNullException(); }
            if (ranges.Count <= 1) { return ranges.FirstOrDefault(); }

            SemVerRange ret = null;
            foreach (var r in ranges)
            {
                ret = Intersect(ret, r);
            }

            return ret;
        }


        /// <summary>
        /// Get the range expression string
        /// </summary>
        /// <returns>Range expression string</returns>
        public override string ToString() => this.Expression;
    }
    //:------------------------:
    #endregion SemVerRange
    //:------------------------:
}
