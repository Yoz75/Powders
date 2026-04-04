module powders.statistics.infoproviders;

import kernel.ecs;
import powders.statistics.displayinfo;

public class TemperatureInfoProvider : ParticleInfoProvider
{
    import powders.particle.temperature;

    protected override string getInfo(const Entity entity)
    {
        import std.conv : to;

        immutable Temperature temperature = entity.getComponent!Temperature();
        return "Temperature: " ~ temperature.value.to!string ~ "*C";
    }
}

public class TypeNameProvider : ParticleInfoProvider
{
    import powders.particle.temperature;

    protected override string getInfo(const Entity entity)
    {
        import powders.particle.basics : Particle;
        import std.conv : to;

        if(!entity.hasComponent!Particle())
        {
            return "Nothing";
        }

        immutable Particle particle = entity.getComponent!Particle();
        return particle.typeId.dup;
    }
}