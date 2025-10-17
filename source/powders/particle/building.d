/// The module, in witch we add particles to the map
module powders.particle.building;

import kernel.todo;
import kernel.ecs;
import powders.map : Position;
import powders.rendering : MapRenderable, black;
import powders.particle.basics;
import powders.particle.register;
import powders.particle.loading;
import jsonizer;

/// Build entity as a some particle type
/// Params:
///   entity = the entity
///   type = the particle's type
public void buildParticle(Entity entity, SerializedParticleType type)
{
    foreach(key, value; type.components)
    {
        LSwitch: switch(key)
        {
            static foreach (module_; defaultModules)
            {
                static foreach (Component; getComponentsInModule!(module_))
                {
                    case getComponentAttributeOf!(Component).name:
                        pragma(msg, "MSG: registered a new component " ~ Component.stringof);

                        // TLDR: add component using parsed from json value
                        // Find raw json data in AA of type by getting `Component` (attribute) of `Component` 
                        // (type, that contains this attribute) and parse it
                        Component component = 
                        fromJSONString!Component(type.components[getComponentAttributeOf!(Component).name]);
                        entity.addComponent!Component(component);
                    break LSwitch;
                }
            }
            default:
                throw new Exception("Not all components are foreached!");
        }
    }
}

public void destroyParticle(Entity entity)
{
    auto particle = entity.getComponent!Particle();

    if(!particle.hasValue) return;

    mixin TODO!("Try to make this think not by removing all components, but by something else (like associative array)");
    mixin TODO!("Also, make this not a kostyl. Maybe some information in component attribute, that says, should we
     remove this component, set a special value to it or do nothing?");
    static foreach (module_; defaultModules)
    {
        static foreach (Component; getComponentsInModule!(module_))
        {
            static if(!is(Component == Position) && !is(Component == MapRenderable))
            {
                entity.removeComponent!Component();            
            }
            static if(is(Component == MapRenderable))
            {
                entity.getComponent!MapRenderable().value.color = black;
            }
        }
    }
}