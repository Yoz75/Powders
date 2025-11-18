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
                    case Component.stringof:
                        pragma(msg, "MSG: registered a new component " ~ Component.stringof);
                        
                        static if(is(Component == Particle))
                        {
                            Component particle;
                            particle.typeId = type.typeID;
                            entity.addComponent!Component(particle);
                            break LSwitch;
                        }

                        // TLDR: add component using parsed from json value
                        // Find raw json data in AA of type by getting `Component` (attribute) of `Component` 
                        // (type, that contains this attribute) and parse it
                        Component component = 
                        fromJSONString!Component(type.components[Component.stringof]);
                        entity.addComponent!Component(component);
                    break LSwitch;
                }
            }
            default:
                throw new Exception("Not all components are foreached!");
        }
    }

    entity.getComponent!Particle().typeId = type.typeID;
}

public void destroyParticle(Entity entity)
{
    bool hasParticle = entity.hasComponent!Particle();

    if(!hasParticle) return;

    mixin TODO!("Try to make this think not by removing all components, but something else (like associative array)");
    static foreach (module_; defaultModules)
    {
        static foreach (Component; getComponentsInModule!(module_))
        {
            {
                enum componentAttribute = getComponentAttributeOf!(Component);
                enum onDestroyAction = componentAttribute.onDestroyAction;

                static if(onDestroyAction == OnDestroyAction.destroy)
                {
                    entity.removeComponent!Component();
                }
                else static if(onDestroyAction == OnDestroyAction.setInit)
                {
                    entity.addComponent!Component(Component.init);
                }
                else static if(onDestroyAction == OnDestroyAction.keep)
                {
                    // do nothing, keep the component
                }
            }
        }
    }
}