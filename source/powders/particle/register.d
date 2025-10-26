/// The module, in witch we detect and register types as components 
///(literally say "hey, this type has Component attribute, that's a component!")
module powders.particle.register;

import powders.rendering;
import powders.particle.basics;
import std.meta;
import std.traits;

/// A useless thing, we need it only to emulate hash set in `globalComponents`
struct Dummy
{

}
/// All found components
public shared Dummy[string] globalComponents;

/// Default modules, that contain components
public alias defaultModules = AliasSeq!(powders.particle.basics, powders.rendering);

/// What we should do with component, when particle is being destroyed?
public enum OnDestroyAction
{
    /// Destroy the component, when particle is being destroyed
    destroy = 0,
    /// Assign T.init value to the component when particle is being destroyed
    setInit,
    /// Keep component "as-is", when particle is being destroyed
    keep
}

/// Attribute, that says that some struct is a component and can be serialized and deserialized as component
public struct Component
{
public:
    OnDestroyAction onDestroyAction;
}

/// Get all component structs in a module `name` as AliasSeq(Components...).
/// This template returns types, that contain `Component` attribute, but `Component` itself
public template getComponentsInModule(alias name)
{
    alias getComponentsInModule = getSymbolsByUDA!(name, Component);
}

/// Get the component attribute, attached to type `T`. 
/// This template assumes, that `T` has Component attribute
public template getComponentAttributeOf(T)
{
    enum Component getComponentAttributeOf = getUDAs!(T, Component)[0];
}

/// Register all components in a module
public void registerModule(alias name)()
{
    static foreach (i, attributed; getComponentsInModule!(name))
    {    
        globalComponents[attributed.stringof] = Dummy();
    }
}

/// Register all components in `defaultModules`
public void registerDefaultModules()
{
    static foreach(module_; defaultModules)
    {
        registerModule!(module_)();
    }
}