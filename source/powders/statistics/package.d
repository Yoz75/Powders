module powders.statistics;

import kernel.ecs;
public import powders.statistics.displayinfo;
public import powders.statistics.infoproviders;

public class InitialStatisticsSystem : BaseSystem
{
    public override void onCreated()
    {
        SystemFactory!DisplayInfoSystem.create();
        DisplayInfoSystem.instance.addInfoCollector(new TemperatureInfoProvider());
        DisplayInfoSystem.instance.addInfoCollector(new TypeNameProvider());
        SystemFactory!FPSInfoSystem.create();
    }
}


private class FPSInfoSystem : BaseSystem
{
    import powders.ui;

    private UIText text;
    private float timer = 0;
    /// Draw FPS every `fpsDrawInterval` seconds
    private enum fpsDrawInterval = 0.05;
    
    public override void onCreated()
    {
        text = new UIText();
        text.position = [0.015, 0.03];
    }

    protected override void onUpdated()
    {
        import powders.rendering;
        import std.conv : to;

        immutable deltaTime = gameWindow.getDeltaTime();
        timer += deltaTime;

        if(timer >= fpsDrawInterval)
        {
            timer = 0;
            text.text = "FPS: " ~ to!string(1 / gameWindow.getDeltaTime()) ~ '\0';
        }
    }
}