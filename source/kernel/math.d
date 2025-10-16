module kernel.math;

import std.traits: isNumeric;

/// Check if point P is on line AB
/// Params:
///   a = A
///   b = B
///   p = P
/// Returns: true if P is on line AB, fals otherwise
public bool isOnLine(T)(T[2] a, T[2] b, T[2] p) if(isNumeric!T)
{
    return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) == 0;
}