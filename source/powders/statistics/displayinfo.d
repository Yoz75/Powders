module powders.statistics.displayinfo;

import kernel.ecs;
import powders.rendering;
import powders.map;

/// Something, that provides some information that should be displayed
// For example, `TemperatureInfoCollector` provides information about particle temperature
public interface IInfoProvider
{
public:
    /// Provide information that should be displayed.
    /// Returns: information that should be displayed.
    string getInfo();
}

public abstract class ParticleInfoProvider : IInfoProvider
{
    public string getInfo()
    {
        auto mousePosition = mouse2MapSpritePosition();

        if(mousePosition[0] < 0 || mousePosition[1] < 0)
        {
            return "";
        } 

        const Entity particleUnderMouse = globalMap.getAt(mousePosition);
        return getInfo(particleUnderMouse);        
    }

    protected abstract string getInfo(const Entity entityUnderMouth);
}

/// System, that displays various information. E.g about particle or simulation state
public class DisplayInfoSystem : BaseSystem
{
    import powders.ui;
    public static DisplayInfoSystem instance;
    private UIText text;

    private IInfoProvider[] infoProviders;
    private enum float[2] textPosition = [0.85, 0.03];

    public this()
    {
        instance = this;
        text = new UIText();
        text.position = textPosition;
    }
    
    public final void addInfoCollector(IInfoProvider provider)
    {
        infoProviders ~= provider;
    }

    public override void onUpdated()
    {
        import std.array;
        auto stringBuilder = appender!string();

        foreach(collector; infoProviders)
        {
            string info = collector.getInfo();

            stringBuilder.put(info);
            stringBuilder.put(' ');
        }
        stringBuilder.put('\0');
        
        text.text = stringBuilder.data;
    }
}