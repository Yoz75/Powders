module powders.input;

import kernel.ecs;
import kernel.jsonutil;
import powders.path;

/// System, that starts other systems in powders.input module
public class InitialInputSystem : BaseSystem
{
    public override void onCreated()
    {
        SystemFactory!MovementSystem.create();
    }
}

public struct PlayerMovementSettings
{
    mixin MakeJsonizable;
public:
    @JsonizeField float zoomSensetivity = 1.0f;
}

private class MovementSystem : BaseSystem
{
    enum moveSpeed = 10f;
    enum zoomSpeed = 0.05f;

    private float requestedZoom = 0;

    private PlayerMovementSettings settings;

    public override void onCreated()
    {
        import powders.io;
        import powders.rendering : gameWindow, Camera;
        enum settingsFileName = "input.json";

        loadOrSave!PlayerMovementSettings(getSettingsPath() ~ settingsFileName, settings);

        Camera camera = gameWindow.getCamera();
        camera.zoom = 0.75;
        gameWindow.setCamera(camera);
    }

    protected override void onUpdated()
    {
        import powders.rendering;

        enum float totalZoomMultiplier = 0.075;
        enum float addZoom = 0.05;
        enum float minimalZoom = 0.1;
        
        Camera camera = gameWindow.getCamera();

        float wheel = gameWindow.getMouseWheelMove();
        if (wheel != 0)
        {            

            float[2] mouseWorldPos = gameWindow.getMouseWorldPosition();

            gameWindow.getMousePosition();
            camera.setOffset(gameWindow.getMousePosition());
            camera.setTarget(mouseWorldPos);
            
            float zoom = wheel * totalZoomMultiplier * settings.zoomSensetivity;

            requestedZoom += zoom;            
        }

        if(requestedZoom > 0)
        {
            requestedZoom -= addZoom * settings.zoomSensetivity;
            camera.zoom += addZoom * settings.zoomSensetivity;

            if(requestedZoom - addZoom < 0) requestedZoom = 0;
        }

        else if(requestedZoom < 0)
        {
            requestedZoom += addZoom * settings.zoomSensetivity;
            camera.zoom -= addZoom * settings.zoomSensetivity;

            if(requestedZoom + addZoom > 0) requestedZoom = 0;
        }

        if (camera.zoom < minimalZoom) camera.zoom = minimalZoom;

        immutable float moveSpeed = 100.0f * gameWindow.getDeltaTime() / camera.zoom;
        if (gameWindow.isKeyDown(Keys.w)) camera.target.y -= moveSpeed;
        if (gameWindow.isKeyDown(Keys.s)) camera.target.y += moveSpeed;
        if (gameWindow.isKeyDown(Keys.a)) camera.target.x -= moveSpeed;
        if (gameWindow.isKeyDown(Keys.d)) camera.target.x += moveSpeed;

        gameWindow.setCamera(camera);
    }
}