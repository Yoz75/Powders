module powders.statistics.infoproviders;

import kernel.ecs;
import powders.statistics.displayinfo;

public class TemperatureInfoProvider : ParticleInfoProvider
{
    import powders.particle.temperature;

    private ComponentPool!Temperature temperatures;

    public this(World world)
    {
        temperatures = world.getPoolOf!Temperature;
    }

    protected override string getInfo(Entity entity)
    {
        import std.conv : to;

        immutable Temperature temperature = temperatures.getComponent(entity);  
        return "Temperature: " ~ temperature.value.to!string ~ "*C";
    }
}

public class TypeNameProvider : ParticleInfoProvider
{
    import powders.particle.basics : Particle;

    
    private ComponentPool!Particle particles;

    public this(World world)
    {
        particles = world.getPoolOf!Particle;
    }

    protected override string getInfo(Entity entity)
    {
        import std.conv : to;

        if(!particles.hasComponent(entity))
        {
            return "Nothing";
        }

        immutable Particle particle = particles.getComponent(entity);
        return particle.typeId.dup;
    }
}