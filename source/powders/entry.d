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
import powders.memory;

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

    protected override void update()
    {
        if(gameWindow.shouldCloseWindow) exit(0);
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
    gameWindow.initWindow([1200, 900], true, "powders!");
    gameWindow.setTargetFPS(240);

    Simulation.run!(CreateMapSystem, InitialRenderSystem, InitialInputSystem,
     InitialParticlesSystem, InitialUISystem, ExitSystem, TimeControlSystem, GC_CleanupSystem)
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