module kernel.versions;

/// The program's version
public shared Version programVersion;

/// Semantic version
public struct Version
{
    size_t major, minor, patch;

    /// Parse version from string in format major.minor.patch
    /// Params:
    ///   stringVersion = 
    /// Returns: 
    public static Version fromString(immutable string stringVersion) pure
    {
        import std.array;
        import std.conv : to;

        Version result;

        string[] splitted = split(stringVersion, '.');

        result.major = splitted[0].to!size_t;
        result.minor = splitted[1].to!size_t;
        result.patch = splitted[2].to!size_t;

        return result;
    }

    /// Get version's representation as string
    /// Returns: 
    public string toString() const pure
    {
        import std.conv : to;

        return major.to!string ~ '.' ~ minor.to!string ~ '.' ~ patch.to!string ~ '.';
    }
}