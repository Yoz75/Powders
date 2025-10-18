module powders.entry;

import kernel.ecs;
import kernel.simulation;
import kernel.color;
import kernel.versions;
import powders.map;
import powders.particle.init;
import powders.rendering;
import powders.input;
import powders.ui;

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
    
    programVersion = Version.fromString(import("appVersion.txt"));

    World gameWorld;
    
    immutable int width = GetScreenWidth();
    immutable int height = GetScreenHeight();

    SetConfigFlags(ConfigFlags.FLAG_WINDOW_UNDECORATED);
    InitWindow(width, height, "Powders Game");

    SetTargetFPS(240);

    Simulation.run!(CreateMapSystem, InitialRenderSystem, InitialInputSystem,
     InitialParticlesSystem, InitialUISystem, ExitSystem)
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