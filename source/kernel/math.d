module kernel.math;

import std.traits: isNumeric;

public T remap(T)(T value, T fromMin, T fromMax, T toMin, T toMax) if(isNumeric!T)
{
    T t = (cast(T) (value - fromMin)) / (cast(T) (fromMax - fromMin));
    return toMin + t * (toMax - toMin);
}