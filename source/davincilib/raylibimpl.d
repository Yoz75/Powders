/// Implementation of davincilib.abstractions using raylib
module davincilib.raylibimpl;

import davincilib.color;
import davincilib.abstractions;
import std.traits : isNumeric;
import raylib;

struct Camera
{
    Camera2D raylibCamera;
    alias raylibCamera this;

    void opAssign(Camera2D camera) shared
    {        
        raylibCamera = camera;
    }

    void setOffset(float[2] offset)
    {
        raylibCamera.offset = Vector2(offset[0], offset[1]);
    }

    void setTarget(float[2] target)
    {
        raylibCamera.target = Vector2(target[0], target[1]);
    }
}

public struct Sprite
{
    mixin AddSpriteFields;

    Image image;
    Texture texture;

    static Sprite create(int[2] resolution, dvc.Color color)
    {
        Sprite sprite;

        /*
            Fucking d's floats are NaN's by default.
            Maybe that's a good thing, but NOT EVEN SINGLE OTHER LANGUAGE I KNOW DOES THAT, THEY HAVE ZERO BY DEFAULT.
        */
        sprite.scale[] = 1f;
        sprite.origin[] = .5f;
        sprite.rotation = 0f;

        sprite.color = color;
        sprite.image = GenImageColor(resolution[0], resolution[1], Colors.WHITE);
        sprite.texture = LoadTextureFromImage(sprite.image);

        return sprite;
    }

    void setPixel(int[2] position, dvc.Color color) inout
    {
        ImageDrawPixel(cast(Image*) &image, position[0], position[1], cast(raylib.Color) color);   
    }  
    
    /// Update texture's data after image manipulaton
    void applyChanges() inout
    {
        UpdateTexture(texture, image.data);
    }
    

    void free() inout
    {
        UnloadTexture(texture);
    }
}

/// Convert position from range 0..resolution to 0..1
/// Params:
///   screenPosition = raw screen position
/// Returns: 
public float[2] screenPos2RelativeScreenPos(uint[2] screenPosition, Window window)
{
    import kernel.math;

    immutable int[2] resolution = window.getWindowResolution();
    float[2] position;

    position[0] = remap!float(screenPosition[0], 0, resolution[0], 0, 1);
    position[1] = remap!float(screenPosition[1], 0, resolution[1], 0, 1);

    return position;
}

public int[2] relativeScreenPos2ScreenPos(float[2] relativePosition, int[2] resolution)
{
    import kernel.math;

    int[2] absolutePosition;

    absolutePosition[0] = cast(int) remap!float(relativePosition[0], 0, 1, 0, resolution[0]);
    absolutePosition[1] = cast(int) remap!float(relativePosition[1], 0, 1, 0, resolution[1]);

    return absolutePosition;
}

import core.thread;
import std.concurrency;

// ConsoleFontInfoEx ahhh core😭😭😭
private struct InitWindowInfo
{
    int[2] resolution;
    bool isFullscreen;
    string title;
}

/// Render sprite at screen position
/// Params:
///   position = the sprite's position
///   sprite = the sprite itself
private void renderSpriteAtScreen(T)(immutable T[2] position, immutable Sprite sprite) if(isNumeric!T)
{
    immutable source = Rectangle(0, 0, sprite.texture.width, sprite.texture.height);
    immutable auto destination = Rectangle(position[0], position[1], 

    sprite.texture.width * sprite.scale[0], 
    sprite.texture.height * sprite.scale[1]);

    immutable auto origin = Vector2(sprite.origin[0], sprite.origin[1]);
    DrawTexturePro(sprite.texture, source, destination, origin, sprite.rotation, cast(raylib.Color) sprite.color);
}

private struct RenderThreadContext
{
public:

    int[2] windowResolution, screenResolution;
    bool shouldCloseWindow;
    bool wasInited = false;

    Camera* camera;
    bool[Keys.max + 1] keyDownStates;
    bool[Keys.max + 1] keyPressedStates;
    float[2] mousePosition = [0, 0], mouseWorldPosition = [0, 0];
    float deltaTime;
    float mouseWheelMove;
    bool[MouseButtons.max + 1] mouseButtonsDownStates;
    bool[MouseButtons.max + 1] mouseButtonsPressedStates;
}

/*
    CALL THESE FUNCTIONS ONLY IN THE RENDER THREAD
*/
private void updateKeys(shared RenderThreadContext* context)
{
    import raylib;
    
    for(int i; i < context.keyDownStates.length; i++)
    {
        // Idk why (maybe because of multythreading) the scheme with current states and previous states just don't work :\
        context.keyPressedStates[i] = IsKeyPressed(i);
        context.keyDownStates[i] = IsKeyDown(i);
    }
}

private void updateMousePosition(shared RenderThreadContext* context)
{
    import raylib;

    auto tempMousePosition = GetMousePosition();
    auto tempMouseWorldPosition = GetScreenToWorld2D(tempMousePosition, *context.camera);

    context.mousePosition = [tempMousePosition.x, tempMousePosition.y];
    context.mouseWorldPosition = [tempMouseWorldPosition.x, tempMouseWorldPosition.y];
}

private void updateouseButtons(shared RenderThreadContext* context)
{
    import raylib;

    for(int i; i < context.mouseButtonsDownStates.length; i++)
    {
        context.mouseButtonsDownStates[i] = IsMouseButtonDown(i);
        context.mouseButtonsPressedStates[i] = IsMouseButtonPressed(i);
    }
}
/*
    END
*/

private alias raylibMessage = void delegate() immutable @system;
private alias anotherRaylibMessage = void delegate() immutable nothrow @nogc @system;
private void raylibThread(immutable InitWindowInfo initInfo, shared RenderThreadContext* context) //ptr because spawn has a strange behaviour according to refs
{
    import raylib;

    auto messageHandler = (raylibMessage msg)
    {
        import std.stdio;
        msg();
    };

    auto anotherMessageHandler = (anotherRaylibMessage msg)
    {
        msg();
    };

    if(initInfo.isFullscreen)
    {
        SetConfigFlags((ConfigFlags.FLAG_FULLSCREEN_MODE | ConfigFlags.FLAG_BORDERLESS_WINDOWED_MODE));    
        InitWindow(GetScreenWidth(), GetScreenHeight(), initInfo.title.ptr);
    }
    else
    {
        InitWindow(initInfo.resolution[0], initInfo.resolution[1], initInfo.title.ptr);
    }
    
    context.wasInited = true;

    context.screenResolution = [GetScreenWidth(), GetScreenHeight()];

    while(true)
    {
        updateKeys(context);
        updateMousePosition(context);
        updateouseButtons(context);

        context.shouldCloseWindow = WindowShouldClose();
        context.windowResolution = [GetScreenWidth(), GetScreenHeight()];
        context.deltaTime = GetFrameTime();
        context.mouseWheelMove = GetMouseWheelMove();

        receiveTimeout(-1.msecs, messageHandler, anotherMessageHandler);
    }
}

public class Window : IWindow!(Sprite, Camera)
{
    import kernel.optional;

    private Tid raylibThreadId;
    private shared Camera camera;
    private shared RenderThreadContext renderContext;

    void initWindow(immutable int[2] resolution, immutable bool isFullscreen, immutable string title)
    {
        camera  = Camera2D(Vector2(0, 0), Vector2(0, 0), 0, 0);
        renderContext.camera = &camera;

        InitWindowInfo initInfo;

        initInfo.resolution = resolution;
        initInfo.isFullscreen = isFullscreen;
        initInfo.title = title;

        raylibThreadId = spawn(&raylibThread, initInfo, &renderContext);

        while(!renderContext.wasInited) {wait();}
    }
    
    void startFrame()
    {
        raylibThreadId.send(() immutable {BeginDrawing();});
    }

    void endFrame()
    {
        raylibThreadId.send(() immutable {EndDrawing();});
    }

    Camera getCamera()
    {
        return camera;
    }

    void setCamera(Camera camera)
    {
        this.camera = camera;
    }

    /// Get the resolution of render window
    /// Returns: the window resolution
    int[2] getWindowResolution()
    {
        return renderContext.windowResolution;
    }

    /// Should window be closed?
    bool shouldCloseWindow()
    {
        return renderContext.shouldCloseWindow;
    }

    /// Render an instance of `TSprite` at a screen position
    void renderAtScreenPos(immutable int[2] position, immutable Sprite sprite)
    {
        raylibThreadId.send(() immutable
        {
            renderSpriteAtScreen(position, sprite);
        });
    }

    /// Render an instance of `TSprite` at a relative screen position (from 0 to 1 for both dimensions)
    void renderAtRelativeScreenPos(immutable float[2] position, immutable Sprite sprite)
    {
        auto absolutePosition = relativeScreenPos2ScreenPos(position, getWindowResolution());
        renderAtScreenPos(absolutePosition, sprite);
    }
    
    /// Render an instance of `TSprite` at world position
    void renderAtWorldPos(immutable float[2] position, immutable Sprite sprite)
    {
        raylibThreadId.send(() immutable
        {
            BeginMode2D(camera);
            renderSpriteAtScreen(position, sprite);
            EndMode2D();
        });
    }

    /// Clear screen using black color
    void clearScreen()
    {
        raylibThreadId.send(() immutable
        {
            ClearBackground(raylib.Colors.BLACK);
        });
    }

    /// Is key down?
    /// Returns: true if key is down, false if not
    bool isKeyDown(immutable Keys key)
    {
        return renderContext.keyDownStates[key];
    }

    /// Was key prassed this frame?
    /// Returns: true if key was pressed this frame, false otherwise
    bool isKeyPressed(immutable Keys key)
    {
        return renderContext.keyPressedStates[key];
    }

    /// Get position of mouse
    /// Returns: position of mouse as float[2]
    float[2] getMousePosition()
    {
        return renderContext.mousePosition;
    }

    /// Get position of mouse, but at world coordinates
    /// Returns: position of mouse as float[2]
    float[2] getMouseWorldPosition()
    {
        return renderContext.mouseWorldPosition;
    }
    
    import raygui;

    bool drawGUIButton(immutable int[2] absoluteScale, immutable int[2] absolutePosition, immutable string text)
    {
        struct Dummy {}

        __gshared Optional!(bool, Dummy) result;
        result = Dummy();

        raylibThreadId.send(() immutable
        { 
            result = GuiButton(Rectangle(absolutePosition[0], absolutePosition[1], 
                absoluteScale[0], absoluteScale[1]), text.ptr) > 0;
        });

        while(!result.hasValue) {wait();}

        return result.value;
    }

    Sprite createAttachedSprite(immutable int[2] resolution, immutable davincilib.Color color)
    {
        struct Dummy {}
        
        __gshared Optional!(Sprite, Dummy) result;
        result = Dummy();
        raylibThreadId.send(() immutable
        { 
            result = Sprite.create(resolution, color);
        });        

        while(!result.hasValue) {wait();}

        return result.value;
    }

    void setTargetFPS(immutable int fps)
    {
        raylibThreadId.send(() immutable
        {
            SetTargetFPS(fps);
        });
    }

    float getDeltaTime()
    {
        return renderContext.deltaTime;
    }

    float getMouseWheelMove()
    {
        return renderContext.mouseWheelMove;
    }

    bool isMouseButtonDown(immutable MouseButtons button)
    {
        return renderContext.mouseButtonsDownStates[button];
    }

    float[2] convertScreen2WorldPosition(immutable int[2] screenPosition) pure
    {
        immutable float screenX = cast(float)screenPosition[0];
        immutable float screenY = cast(float)screenPosition[1];

        immutable float relativeX = (screenX - camera.offset.x) / camera.zoom;
        immutable float relativeY = (screenY - camera.offset.y) / camera.zoom;

        immutable float rotationRadians = -camera.rotation * PI / 180.0f;

        immutable float rotationCosine = cos(rotationRadians);
        immutable float rotationSine = sin(rotationRadians);

        immutable float worldX =
            camera.target.x +
            relativeX * rotationCosine -
            relativeY * rotationSine;

        immutable float worldY =
            camera.target.y +
            relativeX * rotationSine +
            relativeY * rotationCosine;

        return [worldX, worldY];
    }


    void setPixelOfSprite(immutable Sprite attachedSprite, immutable int[2] position, immutable davincilib.Color color)
    {
        raylibThreadId.send(() immutable
        {
            attachedSprite.setPixel(position, color);
        });
    }

    void applySpriteChanges(immutable Sprite attachedSprite)
    {
        raylibThreadId.send(() immutable
        {
            attachedSprite.applyChanges();
        });
    }

    /// Just a thing that waits 1 msec, so compiler won't optimize out loops
    pragma(inline, true) private void wait()
    {
        import core.thread; Thread.getThis.sleep(1.nsecs);
    }
}