using System;
using System.Text;
using System.Text.RegularExpressions;

namespace pspm
{
    public class SemVer : IComparable, IComparable<SemVer>, IEquatable<SemVer>
    {
        private int _Major;
        private int _Minor = 0;
        private int _Patch = 0;
        private int _Revision = 0;
        private string _PreReleaseLabel = "";
        private string _BuildLabel = "";

        private static Regex LabelValidator = new Regex("^[.0-9A-Za-z-]*$");

        //static member
        public static SemVer Max = new SemVer(int.MaxValue, int.MaxValue, int.MaxValue, int.MaxValue);
        public static SemVer Min = new SemVer(0);

        public int Major
        {
            get { return this._Major; }

            private set
            {
                if (value >= 0 && value <= int.MaxValue)
                {
                    this._Major = value;
                }
                else
                {
                    throw new ArgumentOutOfRangeException(string.Format("{0} should be between 0 and {1}", "Major", int.MaxValue.ToString()));
                }
            }
        }

        public int Minor
        {
            get { return this._Minor; }

            private set
            {
                if (value >= 0 && value <= int.MaxValue)
                {
                    this._Minor = value;
                }
                else
                {
                    throw new ArgumentOutOfRangeException(string.Format("{0} should be between 0 and {1}", "Minor", int.MaxValue.ToString()));
                }
            }
        }

        public int Patch
        {
            get { return this._Patch; }

            private set
            {
                if (value >= 0 && value <= int.MaxValue)
                {
                    this._Patch = value;
                }
                else
                {
                    throw new ArgumentOutOfRangeException(string.Format("{0} should be between 0 and {1}", "Patch", int.MaxValue.ToString()));
                }
            }
        }

        public int Revision
        {
            get { return this._Revision; }

            private set
            {
                if (value >= 0 && value <= int.MaxValue)
                {
                    this._Revision = value;
                }
                else
                {
                    throw new ArgumentOutOfRangeException(string.Format("{0} should be between 0 and {1}", "Revision", int.MaxValue.ToString()));
                }
            }
        }

        public string PreReleaseLabel
        {
            get { return this._PreReleaseLabel; }

            private set
            {
                if (LabelValidator.IsMatch(value))
                {
                    this._PreReleaseLabel = value;
                }
                else
                {
                    throw new ArgumentException(string.Format("{0} contains invalid character", "PreReleaseLabel"));
                }
            }
        }

        public string BuildLabel
        {
            get { return this._BuildLabel; }

            private set
            {
                if (LabelValidator.IsMatch(value))
                {
                    this._BuildLabel = value;
                }
                else
                {
                    throw new ArgumentException(string.Format("{0} contains invalid character", "BuildLabel"));
                }
            }
        }

        // Constructor
        public SemVer(int major)
        {
            this.Major = major;
        }

        public SemVer(int major, int minor) : this(major)
        {
            this.Minor = minor;
        }

        public SemVer(int major, int minor, int patch) : this(major, minor)
        {
            this.Patch = patch;
        }

        public SemVer(int major, int minor, int patch, int revision) : this(major, minor, patch)
        {
            this.Revision = revision;
        }

        public SemVer(int major, int minor, int patch, int revision, string prerelease) : this(major, minor, patch, revision)
        {
            this.PreReleaseLabel = prerelease;
        }

        public SemVer(int major, int minor, int patch, int revision, string prerelease, string build) : this(major, minor, patch, revision, prerelease)
        {
            this.BuildLabel = build;
        }

        public SemVer(Version version)
        {
            this.Major = (version.Major >= 0) ? version.Major : 0;
            this.Minor = (version.Minor >= 0) ? version.Minor : 0;
            this.Patch = (version.Build >= 0) ? version.Build : 0;
            this.Revision = (version.Revision >= 0) ? version.Revision : 0;
        }

        public SemVer(string expression)
        {
            SemVer semver = SemVer.Parse(expression);
            this.Major = semver.Major;
            this.Minor = semver.Minor;
            this.Patch = semver.Patch;
            this.Revision = semver.Revision;
            this.PreReleaseLabel = semver.PreReleaseLabel;
            this.BuildLabel = semver.BuildLabel;
        }


        // ToString()
        public override string ToString()
        {
            StringBuilder result = new StringBuilder();

            result.Append(this.Major).Append(".").Append(this.Minor).Append(".").Append(this.Patch);

            if (this.Revision > 0)
            {
                result.Append(".").Append(this.Revision);
            }

            if (!string.IsNullOrEmpty(this.PreReleaseLabel))
            {
                result.Append("-").Append(this.PreReleaseLabel);
            }

            if (!string.IsNullOrEmpty(this.BuildLabel))
            {
                result.Append("+").Append(this.BuildLabel);
            }

            return result.ToString();
        }


        // Parse()
        public static SemVer Parse(string expression)
        {
            //split major.minor.patch
            string[] numbers = expression.Split('-')[0].Split('+')[0].Split('.');

            int tMajor;
            if (int.TryParse(numbers[0], out tMajor))
            {
                if (tMajor < 0)
                {
                    throw new FormatException();
                }
            }
            else
            {
                throw new FormatException();
            }

            int tMinor;
            if (numbers.Length <= 1)
            {
                tMinor = 0;
            }
            else if (int.TryParse(numbers[1], out tMinor))
            {
                if (tMinor < 0)
                {
                    throw new FormatException();
                }
            }
            else
            {
                throw new FormatException();
            }

            int tPatch;
            if (numbers.Length <= 2)
            {
                tPatch = 0;
            }
            else if (int.TryParse(numbers[2], out tPatch))
            {
                if (tPatch < 0)
                {
                    throw new FormatException();
                }
            }
            else
            {
                throw new FormatException();
            }

            int tRevision;
            if (numbers.Length <= 3)
            {
                tRevision = 0;
            }
            else if (int.TryParse(numbers[3], out tRevision))
            {
                if (tRevision < 0)
                {
                    throw new FormatException();
                }
            }
            else
            {
                throw new FormatException();
            }

            //split prelease+buildmeta
            string tPreReleaseLabel = "";
            string tBuildLabel = "";

            string prerelease = "";
            int indexI = expression.IndexOf("-");
            if (indexI >= 1)
            {
                prerelease = expression.Substring(indexI + 1);
            }

            string build = "";
            int indexJ = expression.IndexOf("+");
            if (indexJ >= 1)
            {
                build = expression.Substring(indexJ + 1);
            }

            if (prerelease.Length > build.Length)
            {
                if (!string.IsNullOrEmpty(prerelease))
                {
                    var tmp = prerelease.Split('+');
                    tPreReleaseLabel = tmp[0].Trim();
                    if (tmp.Length > 1)
                    {
                        tBuildLabel = tmp[1].Trim();
                    }
                }
            }
            else
            {
                if (!string.IsNullOrEmpty(build))
                {
                    tBuildLabel = build.Trim();
                }

            }

            return new SemVer(tMajor, tMinor, tPatch, tRevision, tPreReleaseLabel, tBuildLabel);

        }


        // TryParse()
        public static bool TryParse(string expression, out SemVer result)
        {
            try
            {
                result = SemVer.Parse(expression);
                return true;
            }
            catch (Exception)
            {
                result = null;
                return false;
            }
        }


        int IComparable.CompareTo(object obj)
        {

            if (obj == null) { return 1; }


            SemVer semver = (SemVer)obj;

            // Compare Major
            if (this.Major != semver.Major)
            {
                return (this.Major > semver.Major) ? 1 : -1;
            }

            // Compare Minor
            else if (this.Minor != semver.Minor)
            {
                return (this.Minor > semver.Minor) ? 1 : -1;
            }

            //  Compare Patch
            else if (this.Patch != semver.Patch)
            {
                return (this.Patch > semver.Patch) ? 1 : -1;
            }

            //  Compare Revision
            else if (this.Revision != semver.Revision)
            {
                return (this.Revision > semver.Revision) ? 1 : -1;
            }

            //  Compare PrereleaseLabel

            // pre-release version has lower precedence than a normal version
            else if (string.IsNullOrEmpty(this.PreReleaseLabel))
            {
                return String.IsNullOrEmpty(semver.PreReleaseLabel) ? 0 : 1;
            }

            else if (string.IsNullOrEmpty(semver.PreReleaseLabel))
            {
                return -1;
            }

            else
            {
                string[] identifierMyself = this.PreReleaseLabel.Split('.');
                string[] identifierTarget = semver.PreReleaseLabel.Split('.');
                int minLength = Math.Min(identifierMyself.Length, identifierTarget.Length);


                for (int i = 0; i < minLength; i++)
                {
                    var my = identifierMyself[i];
                    var tr = identifierTarget[i];

                    int num_my, num_tr;
                    bool isNum_my = int.TryParse(my, out num_my);
                    bool isNum_tr = int.TryParse(tr, out num_tr);

                    // identifiers consisting of only digits are compared numerically
                    if (isNum_my && isNum_tr)
                    {
                        if (num_my == num_tr) { continue; }
                        else { return ((num_my < num_tr) ? -1 : 1); }
                    }
                    // Numeric identifiers always have lower precedence than non-numeric identifiers
                    else if (isNum_my)
                    {
                        return -1;
                    }
                    else if (isNum_tr)
                    {
                        return 1;
                    }
                    // identifiers with letters or hyphens are compared lexically in ASCII sort order.
                    else
                    {
                        if (my.Equals(tr, StringComparison.Ordinal)) { continue; }
                        else { return string.CompareOrdinal(my, tr); }
                    }
                }
            }

            return 0;
        }


        public int CompareTo(SemVer other)
        {
            return this.CompareTo(other);
        }


        public static int Compare(SemVer ver1, SemVer ver2)
        {
            if (ver1 != null)
            {
                return ver1.CompareTo(ver2);
            }

            if (ver2 != null)
            {
                return -1;
            }

            return 0;
        }


        public override bool Equals(object obj)
        {
            return this.Equals(obj as SemVer);
        }


        public bool Equals(SemVer other)
        {
            // If parameter is null, return false
            if (other == null) { return false; }

            // Optimization for a common success case.
            if (Object.ReferenceEquals(this, other)) { return true; }

            return (
                // SemVer 2.0 standard requires to ignore 'BuildLabel' (Build metadata).
                (this.Major == other.Major) &&
                (this.Minor == other.Minor) &&
                (this.Patch == other.Patch) &&
                (this.Revision == other.Revision) &&
                string.Equals(this.PreReleaseLabel, other.PreReleaseLabel, StringComparison.Ordinal)
            );
        }


        public override int GetHashCode()
        {
            return this.ToString().GetHashCode();
        }


        //Operator override
        public static bool operator ==(SemVer ver1, SemVer ver2)
        {
            if ((object)ver1 == null)
            {
                return ((object)ver2 == null);
            }

            if ((object)ver2 == null)
            {
                return false;
            }

            return ver1.Equals(ver2);
        }

        public static bool operator !=(SemVer ver1, SemVer ver2)
        {
            return !(ver1 == ver2);
        }

        public static bool operator <(SemVer ver1, SemVer ver2)
        {
            if ((object)ver1 == null || (object)ver2 == null)
            {
                throw new ArgumentNullException();
            }

            return (ver1.CompareTo(ver2) < 0);
        }

        public static bool operator >(SemVer ver1, SemVer ver2)
        {
            return (ver2 < ver1);
        }

        public static bool operator <=(SemVer ver1, SemVer ver2)
        {
            if ((object)ver1 == null || (object)ver2 == null)
            {
                throw new ArgumentNullException();
            }

            return (ver1.CompareTo(ver2) <= 0);
        }

        public static bool operator >=(SemVer ver1, SemVer ver2)
        {
            return (ver2 <= ver1);
        }
    }
}
