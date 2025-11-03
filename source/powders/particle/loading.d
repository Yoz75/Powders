/// The module, in witch we load types from settings
module powders.particle.loading;

import powders.io;
import powders.path;
import powders.particle.basics;
import powders.particle.register;
import std.file;

/// Loaded types, but as dictionary
public SerializedParticleType[ParticleId] globalTypesDictionary;

/// All categories, loaded by `tryLoadTypes`
public Category[] globalLoadedCategories;

/// Every exception, that occurs when loading particles from configs
class ParticleLoadException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) pure nothrow @nogc @safe
    {
        super(msg, file, line, nextInChain);
    }
}

/// Exception, that occurs, when the game couldn't associate directory's name with any component name
public class WrongComponentLoadException : ParticleLoadException
{
    this(string msg, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) 
    pure nothrow @nogc @safe
    {
        super(msg, file, line, nextInChain);
    }
}

/// Type, that contains ID of particle's type and its components. This is needed for loading types from settings
public struct SerializedParticleType
{
    mixin MakeJsonizable;
public:
    /// The id of particle
    @JsonizeField ParticleId typeID;
    // The dictionary of raw .json values of components by their names
    @JsonizeField string[string] components;
}

public struct Category
{
    string name;
    SerializedParticleType[] types;
}

/// Try load categories and their types from settings to `globalLoadedCategories`
///Throws: `ParticleTypeLoadException`
public void loadParticleCategories()
{
    immutable string particlesDirectory = getSettingsPath() ~ "Particles" ~ pathSeparator;

    if(!exists(particlesDirectory))
    {
        throw new ParticleLoadException("Particles directory doesn't exists!");
    }

    globalLoadedCategories = processCategories(particlesDirectory);
}

private:

Category[] processCategories(string path)
{
    Category[] categories;

    foreach(categoryEntry; dirEntries(path, SpanMode.shallow))
    {
        if(!categoryEntry.isDir) continue;

        Category category;
        category.name = categoryEntry.name.extractDirName();
        category.types = processTypes(categoryEntry.name);

        categories ~= category;
    }

    assert(categories.length > 0, "at some reason we couldn't process categories (maybe there's no categories?!)");

    return categories;
}

SerializedParticleType[] processTypes(string path)
{
    SerializedParticleType[] types;

    foreach (typeEntry; dirEntries(path, SpanMode.shallow))
    {
        /// typeEntry is a directory inside particles directory, every directory inside this is recognized as a type direcotry
        if(!typeEntry.isDir()) continue;
        
        SerializedParticleType type;

        // Foreach because if we just assign value some characters at the and of id will be null! 
        // Idk why this happen, but it is what it is
        foreach (i, char idChar; typeEntry.name.extractDirName()) //get only the name of directory
        {
            type.typeID[i] = idChar;
        }

        type.components = processComponents(typeEntry);

        globalTypesDictionary[type.typeID] = type;
        types ~= type;
    }

    assert(types.length > 0, "at some reasone we couldn't process types! Maybe there's no types in a directory???");

    return types;
}

/// Process components of a type and get them
/// Params:
///   path = path to the type
/// Returns: associative array, where key is name of component and value is serialized component
string[string] processComponents(string path)
{
    string[string] components;

    foreach(componentEntry; dirEntries(path, SpanMode.shallow))
    {
        if(!componentEntry.isFile()) continue;

        // Get the name of component's json file from full path
        string componentName = extractFileName(componentEntry.name);

        auto component = componentName in globalComponents;
        if(component is null)
        {
            throw new WrongComponentLoadException("Component " ~ componentName ~ " does not exists!");
        }

        // A huge kostyl lol (not only this code, but the whole concept)
        components[componentName] = readText(componentEntry.name);    
    }

    assert(components.length > 0, "at some reason we couldn't load components! Maybe there's no attached components to a type?");

    return components;
}

/// Extract file's name without extension from file's path
pure string extractFileName(string path)
{
    import std.array; 
    return path.split(pathSeparator)[$-1].split('.')[0];
}

/// Extract directory's name from it's path
pure string extractDirName(string path)
{
    import std.array;
    return path.split(pathSeparator)[$-1];
}