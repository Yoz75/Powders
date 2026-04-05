module powders.path;

import std.file;

version(Windows)
{
    enum char pathSeparator = '\\';
}
else
{
    enum char pathSeparator = '/';
}

/// Get path of app's data (it can be any directory, not only C:\Users\user\AppData)
/// Returns: the path
string getAppDataPath()
{
    auto cwd = getcwd();

    return cwd ~ pathSeparator; 
}   

string getParticlesPath()
{
    enum particlesFolderName = "particles";

    immutable string path = getAppDataPath ~ particlesFolderName ~ pathSeparator;

    if(!exists(path))
    {
        mkdirRecurse(path);
    }

    return path;
}

string getSettingsPath()
{
    enum settingsFolderName = "settings";

    immutable string path = getAppDataPath ~ settingsFolderName ~ pathSeparator;

    if(!exists(path))
    {
        mkdirRecurse(path);
    }

    return path;
}