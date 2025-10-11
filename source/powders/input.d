module powders.input;

import kernel.ecs;
import kernel.jsonutil;
import powders.path;

public enum Keys
{
    none = 0,
    apostrophe = 39,
    comma = 44,
    minus,
    period,
    slash,
    zero,
    one,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    semicolon,
    equal,
    a = 65,
    b,
    c,
    d,
    e,
    f,
    g,
    h,
    i,
    j,
    k,
    l,
    m,
    n,
    o,
    p,
    q,
    r,
    s,
    t,
    u,
    v,
    w,
    x,
    y,
    z,
    escape = 256,
    right = 262,
    left,
    down,
    up
    // Currently i don't need more keys.
}


/// Static class for input
public struct Input // I could use here global functions, but their names differ from raylib functions only by 1 letter
{
    import raylib;
public:
static:
    /// Was key pressed this frame?
    /// Returns: true if was, false if not
    bool isKeyDown(Keys key)
    {
        return raylib.IsKeyDown(key);
    }

    /// Get position of mouse
    /// Returns: position of mouse as float[2]
    float[2] getMousePosition()
    {
        auto rawPosition = GetMousePosition();
        
        return [rawPosition.x, rawPosition.y];
    }

    /// Get position of mouse, but at world coordinates
    /// Returns: position of mouse as float[2]
    float[2] getMouseWorldPosition()
    {
        import powders.rendering : globalCamera;
        auto rawPosition = GetScreenToWorld2D(GetMousePosition(), globalCamera);

        return [rawPosition.x, rawPosition.y];
    }
}

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
        enum settingsFileName = "input.json";

        loadOrSave!PlayerMovementSettings(getSettingsPath() ~ settingsFileName, settings);
    }

    protected override void update()
    {
        import raylib;
        import powders.rendering : globalCamera;

        enum float totalZoomMultiplier = 0.075;
        enum float addZoom = 0.05;
        enum float minimalZoom = 0.1;
        
        float wheel = GetMouseWheelMove();
        if (wheel != 0)
        {
            // We use raylib function GetMousePosition and now our wrap because we need raylib.Vector2
            // Converting Vector2 to float[2] and then back to Vector2 would be dumb
            Vector2 mouseWorldPos = GetScreenToWorld2D(GetMousePosition(), globalCamera);
            globalCamera.offset = GetMousePosition();
            globalCamera.target = mouseWorldPos;
            
            float zoom = wheel * totalZoomMultiplier * settings.zoomSensetivity;

            requestedZoom += zoom;            
        }

        if(requestedZoom > 0)
        {
            requestedZoom -= addZoom * settings.zoomSensetivity;
            globalCamera.zoom += addZoom * settings.zoomSensetivity;

            if(requestedZoom - addZoom < 0) requestedZoom = 0;
        }

        else if(requestedZoom < 0)
        {
            requestedZoom += addZoom * settings.zoomSensetivity;
            globalCamera.zoom -= addZoom * settings.zoomSensetivity;

            if(requestedZoom + addZoom > 0) requestedZoom = 0;
        }

        if (globalCamera.zoom < minimalZoom) globalCamera.zoom = minimalZoom;

        immutable float moveSpeed = 100.0f * GetFrameTime() / globalCamera.zoom;
        if (Input.isKeyDown(Keys.w)) globalCamera.target.y -= moveSpeed;
        if (Input.isKeyDown(Keys.s)) globalCamera.target.y += moveSpeed;
        if (Input.isKeyDown(Keys.a)) globalCamera.target.x -= moveSpeed;
        if (Input.isKeyDown(Keys.d)) globalCamera.target.x += moveSpeed;
    }
}