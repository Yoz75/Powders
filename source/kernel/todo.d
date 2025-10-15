module kernel.todo;

public mixin template TODO(dstring message, string file = __FILE__)
{
    pragma(msg, "TODO: " ~ message ~ " from file: " ~ file);
}