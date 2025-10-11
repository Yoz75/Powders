module powders.io;

import kernel.jsonutil;

/// Load data from settings file or leave it default if couldn't
/// Params:
///   path = full path to the data
///   data = 
void loadOrSave(T)(string path, ref T data)
{
    auto dataOptional = loadFromFile!T(path); 
    if(!dataOptional.hasValue)
    {
        saveToFile(path, data);
    }
    else
    {
        data = dataOptional.value;
    }
}