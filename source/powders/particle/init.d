/// The module, in witch we initialize all particle-related stuff
module powders.particle.init;

import kernel.ecs;
import kernel.color;
import powders.map;
import powders.rendering;
import powders.particle.basics;
import powders.particle.register;
import powders.particle.loading;
import powders.particle.creating;

/// System, that starts other systems in powders.particle module
public class InitialParticlesSystem : BaseSystem
{
    public override void onCreated()
    {
        registerDefaultModules();
        tryLoadTypes();

        if(globalLoadedTypes.length <= 0)
        {
            throw new Exception("There is no types in settings!");
        }

        assert(globalMap != Map.init, "Initial particle system is being initialized, but map is still wasn't inited!");
        SystemFactory!PowderSystem.create();
        SystemFactory!GravitySystem.create();
        SystemFactory!AdhesionSystem.create();
        SystemFactory!ChangeGravitySystem.create();
        SystemFactory!CreateParticleSystem.create();
        SystemFactory!CombineSystem.create();
        SystemFactory!TemperatureSystem.create();

        immutable auto mapResolution = globalMap.resolution;

        foreach (i; 0..mapResolution[0])
        {
            auto entity = globalMap.getAt([i, mapResolution[1] - 1]);
            entity.addComponent!Particle(Particle.init);
            entity.addComponent!Temperature(Temperature.init);
            entity.getComponent!MapRenderable().value.color = white;
        }

        foreach(entity; globalMap)
        {
            entity.addComponent!Temperature(Temperature.init);
        }
    }
}
