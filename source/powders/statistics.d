module powders.statistics;

import kernel.ecs;
import powders.rendering;
import powders.map;

/// Something, that can grab entity and collect info about one of components of this entity and make a human readable string from it.
// For example, `TemperatureInfoCollector`, that converts `Temperature.value` to a human readable string.
public interface IParticleInfoCollector
{
public:
    /// Grab entity and collect info about one of its components, return it as human readable string
    /// Params:
    ///   particle = entity, that represents particle, from which we will collect info
    /// Returns: Human readable string with info about component
    string getInfo(const Entity particle);
}

public class InitialStatisticsSystem : BaseSystem
{
    public override void onCreated()
    {
        SystemFactory!ParticleInfoSystem.create();
    }
}

public final class ParticleInfoSystem : BaseSystem
{
    import powders.ui;
    public static ParticleInfoSystem instance;
    private UIText text;

    private IParticleInfoCollector[] infoCollectors;

    private enum float[2] textPosition = [0.85, 0.03];

    public this()
    {
        instance = this;
        text = new UIText();
        text.position = textPosition;

        addInfoCollector(new TemperatureInfoCollector());
        addInfoCollector(new TypeNameCollector());
    }
    
    public void addInfoCollector(IParticleInfoCollector collector)
    {
        infoCollectors ~= collector;
    }

    public override void onUpdated()
    {
        import std.array;

        auto mousePosition = mouse2MapSpritePosition();

        if(mousePosition[0] < 0 || mousePosition[1] < 0)
        {
            text.text = "";
            return;
        } 

        immutable Entity particleUnderMouse = globalMap.getAt(mousePosition);

        auto stringBuilder = appender!string();

        foreach(collector; infoCollectors)
        {
            string info = collector.getInfo(particleUnderMouse);

            stringBuilder.put(info);
            stringBuilder.put(' ');
        }
        stringBuilder.put('\0');
        
        text.text = stringBuilder.data;
    }
}

private class TemperatureInfoCollector : IParticleInfoCollector
{
    import powders.particle.temperature;
public:
    string getInfo(const Entity entity)
    {
        import std.conv : to;

        immutable Temperature temperature = entity.getComponent!Temperature();
        return "Temperature: " ~ temperature.value.to!string ~ "*C";
    }
}

private class TypeNameCollector : IParticleInfoCollector
{
    import powders.particle.temperature;
public:
    string getInfo(const Entity entity)
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