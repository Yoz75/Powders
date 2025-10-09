module powders.path;

import std.file;

version(Windows)
{
    private enum char separator = '\\';
}
else
{
    private enum char separator = '/';
}
string getSettingsPath()
{
    enum settingsFolderName = "settings";

    auto cwd = getcwd();

    immutable path = cwd ~ separator ~ settingsFolderName ~ separator;

    if(!exists(path))
    {
        mkdirRecurse(path);
    }

    return path;    
}