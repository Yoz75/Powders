module kernel.jsonutil;

import jsonizer;
import kernel.optional;
import std.file;

/// Error code if reading json file
public enum JSONErrorCode
{
    None = 0,
    FileNotFound,
    ParseError,
}

/// alias stuff to abstract jsonizer from user
alias JsonizeField = jsonize;

///ditto
public mixin template MakeJsonizable()
{
    public import jsonizer;
    mixin JsonizeMe;
}

/// Load an instance of `T` from file
/// Params:
///   path = path to file
/// Returns: an instance of T or error code if something went wrong
public Optional!(T, JSONErrorCode) loadFromFile(T)(const string path)
{
    if(!exists(path)) return Optional!(T, JSONErrorCode)(JSONErrorCode.FileNotFound);

    T result;
    try
    {
        result = readJSON!T(path);
        return Optional!(T, JSONErrorCode)(result);
    }
    catch(JsonizeTypeException ex)
    {
        return Optional!(T, JSONErrorCode)(JSONErrorCode.ParseError);    
    }
    
}
public void saveToFile(T)(const string path, const T value)
{
    writeJSON!T(path, value);
}
