/// The module, in witch we initialize all particle-related stuff
module powders.particle.init;

import kernel.ecs;
import davincilib.color;
import powders.map;
import powders.rendering;
import powders.particle.basics;
import powders.particle.register;
import powders.particle.loading;
import powders.particle.creating;
import powders.particle.wireworld;
import powders.particle.temperature;

/// System, that starts other systems in powders.particle module
public class InitialParticlesSystem : BaseSystem
{
    import powders.particle.building;
    
    public override void onCreated()
    {
        registerDefaultModules();
        loadParticleCategories();

        if(globalLoadedCategories.length <= 0)
        {
            throw new Exception("There is no types in settings!");
        }

        assert(globalMap != Map.init, "Initial particle system is being initialized, but map is still wasn't inited!");

        SystemFactory!MovableSystem.create();
        SystemFactory!GravitySystem.create();
        SystemFactory!PowderSystem.create();
        SystemFactory!AdhesionSystem.create();
        SystemFactory!ChangeGravitySystem.create();
        SystemFactory!CombineSystem.create();
        SystemFactory!GasSystem.create();

        SystemFactory!CreateParticleSystem.create();
        SystemFactory!ShapeChangerSystem.create();

        SystemFactory!TemperatureSystem.create();
        SystemFactory!DeltaTemperatureSystem.create();
        SystemFactory!MeltableSystem.create();
        SystemFactory!SolidableSystem.create();
        SystemFactory!ConvectionSystem.create();

        SystemFactory!WWorldConductorSystem.create();
        SystemFactory!WWorldSparkleSystem.create();
        immutable auto mapResolution = globalMap.resolution;

        foreach(entity; globalMap)
        {
            buildAir(entity);
        }

        foreach (x, y, entity; globalMap)
        {
            if((x == 0 || y == 0) || (x == mapResolution[0] - 1 || y == mapResolution[1] - 1))
            {
                destroyParticle(entity);
                buildBorder(entity);
            }
        }

        (cast(MovableSystem) MovableSystem.instance).onMoved ~= (Entity self, Entity other)
        {
            (cast(TemperatureSystem) TemperatureSystem.instance).updateTemperatureOf(self);
            (cast(TemperatureSystem) TemperatureSystem.instance).updateTemperatureOf(other);
        };
    }
}
