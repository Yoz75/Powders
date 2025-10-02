module kernel.optional;

struct Optional(TValue, TError)
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

    /// Create optional with all members set (use when would be faster to explicitly set hasValue, e.g avoid branching)
    /// Params:
    ///   value = 
    ///   error = 
    ///   hasValue = 
    this(TValue value, TError error, bool hasValue)
    {
        this.value = value;
        this.error = error;
        this.hasValue = hasValue;
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
}