/// The module, in witch we add particles to the map
module powders.particle.building;

import kernel.ecs;
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