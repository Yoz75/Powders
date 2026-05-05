/// The module, in witch we add particles to the map
module powders.particle.building;

import kernel.todo;
import kernel.ecs;
import powders.map : Position;
import powders.rendering;
import powders.particle.basics;
import powders.particle.register;
import powders.particle.loading;
import jsonizer;

private T getCachedComponent(T)(const SerializedParticleType type)
{
    import kernel.optional;
    /// Don't use `T value` here and value == T.init. This fails at some reason with DeltaTemperature and some other components
    static Optional!T[const SerializedParticleType] type2Value;
    auto value = type in type2Value;

    if(value is null || !value.hasValue)
    {
        type2Value[type] = fromJSONString!T(type.components[T.stringof]);
    }

    return type2Value[type].value;
}

/// Build the air particle
/// Params:
///   entity = the entity to become air
pragma(inline, true)
public void buildAir(Entity entity)
{
    buildParticle(entity, globalTypesDictionary[airTypeId]);
}

/// Build the border particle
/// Params:
///   entity = the entity to become air
pragma(inline, true)
public void buildBorder(Entity entity)
{
    buildParticle(entity, globalTypesDictionary[borderTypeId]);
}

/// Build entity as a some particle type
/// Params:
///   entity = the entity
///   type = the particle's type
public void buildParticle(Entity entity, in SerializedParticleType type)
{
    foreach(key, value; type.components)
    {
        LSwitch: switch(key)
        {
            mixin TODO!"build particle is already slow because of GC. 
                \"getPoolOf\" line makes the function EVEN SLOWER. Optimize in future please";
            static foreach (module_; defaultModules)
            {
                static foreach (Component; getComponentsInModule!(module_))
                {
                    case Component.stringof:
                    {            
                        auto pool = entity.world.getPoolOf!Component;            
                        pragma(msg, "MSG: registered a new component " ~ Component.stringof);
                        
                        static if(is(Component == Particle))
                        {
                            Component particle;
                            particle.typeId = type.typeID;
                            pool.addComponent(entity);
                            break LSwitch;
                        }

                        enum componentAttribute = getComponentAttributeOf!(Component);
                        enum onAddAction = componentAttribute.onAddAction;

                        // By default, addComponent does nothing when there is a component already.
                        // So we can do nothing when onAddAction is ignore, but if it's recreate, we should remove component and add it again with new value
                        static if(onAddAction == OnAddAction.recreate)
                        {
                            if(pool.hasComponent(entity))
                            {
                                pool.removeComponent(entity);
                            }
                        }

                        // TLDR: add component using parsed from json value
                        // Find raw json data in AA of type by getting `Component` (attribute) of `Component` 
                        // (type, that contains this attribute) and parse it
                        Component component = getCachedComponent!Component(type);
                        pool.addComponent(entity, component);
                    break LSwitch;
                    }
                }
            }
            default:
                throw new Exception("Not all components are foreached!");
        }
    }

    entity.world.getPoolOf!UpdateRenderableMarker().addComponent(entity);
}

/// Destroy all components of `entity`.
public void destroyParticle(Entity entity)
{
    mixin TODO!("Try to make this think not by removing all components, but something else (like associative array)");
    mixin TODO!"build particle is already slow because of GC. 
        \"getPoolOf\" line makes the function EVEN SLOWER. Optimize in future please";
    static foreach (module_; defaultModules)
    {
        static foreach (Component; getComponentsInModule!(module_))
        {
            {
                enum componentAttribute = getComponentAttributeOf!(Component);
                enum onDestroyAction = componentAttribute.onDestroyAction;

                auto pool =  entity.world.getPoolOf!Component;

                static if(onDestroyAction == OnDestroyAction.destroy)
                {
                    pool.removeComponent(entity);
                }
                else static if(onDestroyAction == OnDestroyAction.setInit)
                {
                    pool.addComponent(entity, Component.init);
                }
                else static if(onDestroyAction == OnDestroyAction.keep)
                {
                    // do nothing, keep the component
                }
            }
        }
    }
    
    entity.world.getPoolOf!UpdateRenderableMarker().addComponent(entity);
}