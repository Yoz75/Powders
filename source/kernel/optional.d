module kernel.optional;

/// Type that tells that Result has `TError.init` value.
/// ------
/// Result!(T, U) result;
/// result = None();
/// ------
struct None
{
}

alias Optional(TValue) = Result!(TValue, bool);

struct Result(TValue, TError)
{
public:

    /*union 
    {*/
        TValue value;
        TError error;
    /*}*/

    bool hasValue;

    this(TValue value)
    {
        this.value = value;
        hasValue = true;
    }

    this(TError error)
    {
        this.error = error;
        hasValue = false;
    }

    void opAssign(TValue value)
    {
        this.value = value;
        hasValue = true;
    }

    void opAssign(TError value)
    {
        error = value;
        hasValue = false;
    }

    void opAssign(None none)
    {
        error = TError.init;
        hasValue = false;
    }
}