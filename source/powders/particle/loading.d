/// The module, in witch we load types from settings
module powders.particle.loading;

import powders.io;
import powders.path;
import powders.particle.basics;
import powders.particle.register;
import std.file;

/// Types, loaded by `tryLoadTypes`
public SerializedParticleType[] globalLoadedTypes;
/// Loaded types, but as dictionary
public SerializedParticleType[ParticleId] globalTypesDictionary;

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

/// Try load types from settings to `globalLoadedTypes`
///Throws: `ParticleTypeLoadException`
public void tryLoadTypes()
{
    immutable string particlesDirectory = getSettingsPath() ~ "Particles" ~ pathSeparator;

    if(!exists(particlesDirectory))
    {
        throw new ParticleLoadException("Particles directory doesn't exists!");
    }

    foreach (typeEntry; dirEntries(particlesDirectory, SpanMode.shallow))
    {
        import std.array; 

        /// typeEntry is a directory inside particles directory, every directory inside this is recognized as a type direcotry
        if(!typeEntry.isDir()) continue;
        
        SerializedParticleType type;

        // Foreach because if we just assign value some characters at the and of id will be null! 
        // Idk why this happen, but it is what it is
        foreach (i, char idChar; typeEntry.name.split(pathSeparator)[$-1]) //get only the name of directory
        {
            type.typeID[i] = idChar;
        }

        foreach(componentEntry; dirEntries(typeEntry, SpanMode.shallow))
        {
            if(!componentEntry.isFile()) continue;

            // Get the name of component's json file from full path
            string componentName = componentEntry.name.split(pathSeparator)[$-1].split('.')[0];

            auto component = componentName in globalComponents;
            if(component is null)
            {
                throw new WrongComponentLoadException("Component " ~ componentName ~ " does not exists!");
            }

            // A huge kostyl lol (not only this code, but the whole concept)
            type.components[componentName] = readText(componentEntry.name);
        }

        globalLoadedTypes ~= type;
        globalTypesDictionary[type.typeID] = type;
    }
}