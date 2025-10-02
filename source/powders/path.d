module powders.path;

import std.file : getcwd;

string getSettingsPath()
{
    enum settingsFolderName = "settings";

    auto cwd = getcwd();
    return cwd ~ "/" ~ settingsFolderName ~ "/";
}