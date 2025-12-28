module powders.entry;

import kernel.ecs;
import kernel.simulation;
import kernel.versions;
import powders.map;
import powders.particle.init;
import powders.rendering;
import powders.input;
import powders.ui;
import powders.timecontrol;
import powders.statistics;

private class CreateMapSystem : BaseSystem
{
    public override void onCreated()
    {
        enum defaultRes = 512;
        globalMap = Map([defaultRes, defaultRes]);
    }
}

private class ExitSystem : BaseSystem
{
    import core.stdc.stdlib : exit;

    protected override void onUpdated()
    {
        if(gameWindow.shouldCloseWindow) exit(100);
    }
}

private class ProfileSystem : BaseSystem
{
    import std.datetime : Duration;
    import std.algorithm;
    import std.array : array;
    import std.stdio : writeln;
    import std.typecons : Tuple, tuple;

    private enum profileFrames = 500;
    private enum profileLogInterval = 50;

    private int frameCounter;
    Duration[BaseSystem] totalTimes;

    public override void onCreated()
    {
        Simulation.addOnUpdateProfile(&onUpdateProfile);
    }

    protected override void onUpdated()
    {
        if (gameWindow.isKeyDown(Keys.p))
        {
            Simulation.isProfiling = !Simulation.isProfiling;
        }

        if (!Simulation.isProfiling)
            return;

        frameCounter++;

        if (frameCounter % profileLogInterval == 0)
        {
            writeln("Profiled ", frameCounter, " frames");
        }

        if (frameCounter >= profileFrames)
        {
            auto entries = totalTimes
                .byKeyValue
                .map!(kv => tuple(kv.key, kv.value))
                .array;

            entries.sort!((a, b) => a[1] > b[1]);

            writeln("-------------------------------------------------------------");
            foreach (entry; entries)
            {
                writeln("System: ", entry[0], ". Average time: ", entry[1] / profileFrames);
            }
            writeln("-------------------------------------------------------------");

            frameCounter = 0;
            totalTimes.clear;

            Simulation.isProfiling = false;
        }
    }

    private void onUpdateProfile(BaseSystem system, Duration time)
    {
        if((system in totalTimes) is null)
        {
            totalTimes[system] = Duration.init;
        }

        totalTimes[system] += time;
    }
}


/// Entry point for powders
public void powdersMain()
{
    import davincilib.raylibimpl;

    import std.functional : toDelegate;
    
    programVersion = Version.fromString(import("appVersion.txt"));

    World gameWorld = World.create();
    gameWindow = new Window();
    gameWindow.initWindow([1200, 900], false, "powders!");
    gameWindow.setTargetFPS(240);

    Simulation.run!(CreateMapSystem, InitialRenderSystem, InitialInputSystem,
     InitialParticlesSystem, InitialUISystem, ExitSystem, TimeControlSystem, InitialStatisticsSystem, ProfileSystem)
    (gameWorld, toDelegate(&beforeUpdate), toDelegate(&afterUpdate));

    import core.stdc.stdlib : exit;
    exit(69);
}

private void beforeUpdate()
{

}

private void afterUpdate()
{
    globalMap.finalizeTick();
}