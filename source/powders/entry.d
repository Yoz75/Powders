module powders.entry;

import kernel.ecs;
import kernel.simulation;
import kernel.color;
import powders.map;
import powders.particle;
import powders.rendering;
import powders.input;

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
    import raylib : WindowShouldClose;
    import core.stdc.stdlib : exit;

    protected override void update()
    {
        if(WindowShouldClose()) exit(0);
    }
}

/// Entry point for powders
public void powdersMain()
{
    import raylib;
    import std.functional : toDelegate;
    
    World gameWorld;

    SetTargetFPS(240);
    InitWindow(800, 600, "Powders");
    Simulation.run!(CreateMapSystem, InitialRenderSystem, InitialInputSystem, InitialParticlesSystem, ExitSystem)
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