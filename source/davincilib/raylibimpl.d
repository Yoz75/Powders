/// Implementation of davincilib.abstractions using raylib
module davincilib.raylibimpl;

import davincilib.color;
import davincilib.abstractions;
import std.traits : isNumeric;
import raylib;
import raygui;

struct Optional(TValue, TError)
{
public:

    /*union 
    {*/
        TValue value;
        TError error;
    /*}*/

    bool hasValue;

    this(TValue value)
    {
        this.value = value;
        hasValue = true;
    }

    this(TError error)
    {
        this.error = error;
        hasValue = false;
    }

    /// Create optional with all members set (use when would be faster to explicitly set hasValue, e.g avoid branching)
    /// Params:
    ///   value = 
    ///   error = 
    ///   hasValue = 
    this(TValue value, TError error, bool hasValue)
    {
        this.value = value;
        this.error = error;
        this.hasValue = hasValue;
    }

    void opAssign(TValue value)
    {
        this.value = value;
        hasValue = true;
    }

    void opAssign(TError value)
    {
        error = value;
        hasValue = false;
    }
}

struct Camera
{
    Camera2D raylibCamera;
    alias raylibCamera this;

    void opAssign(Camera2D camera)
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
private void renderSpriteAtScreen(T)(T[2] position, Sprite sprite) if(isNumeric!T)
{
    immutable source = Rectangle(0, 0, sprite.texture.width, sprite.texture.height);
    immutable auto destination = Rectangle(position[0], position[1], 

    sprite.texture.width * sprite.scale[0], 
    sprite.texture.height * sprite.scale[1]);

    immutable auto origin = Vector2(sprite.origin[0], sprite.origin[1]);
    DrawTexturePro(sprite.texture, source, destination, origin, sprite.rotation, cast(raylib.Color) sprite.color);
}

public class Window : IWindow!(Sprite, Camera)
{
    private Camera camera;

    void initWindow(int[2] resolution, bool isFullscreen, string title)
    {
        camera = Camera2D(Vector2(0, 0), Vector2(0, 0), 0, 0);

        if(isFullscreen)
        {
            SetConfigFlags((ConfigFlags.FLAG_FULLSCREEN_MODE | ConfigFlags.FLAG_BORDERLESS_WINDOWED_MODE));    
            InitWindow(GetScreenWidth(), GetScreenHeight(), title.ptr);
        }
        else
        {
            InitWindow(resolution[0], resolution[1], title.ptr);
        }
    }
    
    void startFrame()
    {
        BeginDrawing();
    }

    void endFrame()
    {
        EndDrawing();
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
        return [GetScreenWidth(), GetScreenHeight()];
    }

    /// Should window be closed?
    bool shouldCloseWindow()
    {
        return WindowShouldClose();
    }

    /// Render an instance of `TSprite` at a screen position
    void renderAtScreenPos(int[2] position, Sprite sprite)
    {
        renderSpriteAtScreen(position, sprite);        
    }

    /// Render an instance of `TSprite` at a relative screen position (from 0 to 1 for both dimensions)
    void renderAtRelativeScreenPos(float[2] position, Sprite sprite)
    {
        auto absolutePosition = relativeScreenPos2ScreenPos(position, getWindowResolution());
        renderAtScreenPos(absolutePosition, sprite);
    }
    
    /// Render an instance of `TSprite` at world position
    void renderAtWorldPos(float[2] position, Sprite sprite)
    {
        BeginMode2D(camera);
        renderSpriteAtScreen(position, sprite);
        EndMode2D();        
    }

    /// Clear screen using black color
    void clearScreen()
    {
        ClearBackground(raylib.Colors.BLACK);        
    }

    /// Is key down?
    /// Returns: true if key is down, false if not
    bool isKeyDown(Keys key)
    {
        return IsKeyDown(key);
    }

    /// Was key prassed this frame?
    /// Returns: true if key was pressed this frame, false otherwise
    bool isKeyPressed(Keys key)
    {
        return IsKeyPressed(key);
    }

    /// Get position of mouse
    /// Returns: position of mouse as float[2]
    float[2] getMousePosition()
    {
        immutable auto pos = GetMousePosition();
        return [pos.x, pos.y];
    }

    /// Get position of mouse, but at world coordinates
    /// Returns: position of mouse as float[2]
    float[2] getMouseWorldPosition()
    {
        immutable auto pos = GetScreenToWorld2D(GetMousePosition(), camera);

        return[pos.x, pos.y];
    }

    /// Get time of rendering previous frame
    float getDeltaTime()
    {
        return GetFrameTime();
    }

    bool drawGUIButton(int[2] absoluteScale, int[2] absolutePosition, string text)
    {
        return GuiButton(Rectangle(absolutePosition[0], absolutePosition[1], 
                absoluteScale[0], absoluteScale[1]), text.ptr) > 0;
    }

    void drawText(string text, int[2] position, int fontSize, davincilib.Color color)
    {
        DrawText(text.ptr, position[0], position[1], fontSize, cast(raylib.Color) color);        
    }

    void setTargetFPS(int fps)
    {
        SetTargetFPS(fps);
    }

    float getMouseWheelMove()
    {
        return GetMouseWheelMove();
    }

    bool isMouseButtonDown(MouseButtons button)
    {
        return IsMouseButtonDown(button);
    }

    float[2] convertScreen2WorldPosition(int[2] screenPosition) pure
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


    void setPixelOfSprite(Sprite attachedSprite, int[2] position, davincilib.Color color)
    {
        attachedSprite.setPixel(position, color);        
    }

    /// Just a thing that waits 1 msec, so compiler won't optimize out loops
    pragma(inline, true) private void wait()
    {
        import core.thread; Thread.getThis.sleep(1.nsecs);
    }

    /// Get a new uninitialized shader buffer
    /// Returns: instance of some class that implements `IShaderBuffer`
    IShaderBuffer getNewUninitedBuffer() => new RaylibShaderBuffer();

    /// Get a new unitialized compute shader
    /// Returns: instance of some class that implements `IComputeShader`
    IComputeShader getNewUninitedComputeShader() => new RaylibComputeShader();

    IBasicShader getNewUninitedBasicShader() => new RaylibBasicShader();
}


private void checkErrors()
{
    rlCheckErrors();
}


/// A buffer allocated on GPU
public class RaylibShaderBuffer : IShaderBuffer
{
    private uint glID;
    
    /// Initialize this buffer
    /// Params:
    /// size = size of buffer in bytes
    /// data = the initial data of buffer, if `data` == null, buffer won't be initialized
    /// hint = hint that tells driver how we'll use our buffer
    void initMe(uint size, void* data, BufferUsageHint hint)
    {
        glID = rlLoadShaderBuffer(size, data, hint);
        checkErrors();
    }

    /// Get internal id of the buffer
    uint getInternalID() => glID;

    /// Free GPU resources of the buffer
    void free()
    {
        rlUnloadShaderBuffer(glID);
        checkErrors();
    }
    
    /// Update SSBO buffer's value.
    /// Params:
    /// data = the new data
    /// offset = ofset of data
    void update (void[] data, uint offset = 0)
    {
        rlUpdateShaderBuffer(glID, data.ptr, cast(uint) data.length, offset);  
        checkErrors();
    }

    /// Read SSBO buffer's value
    /// Params:
    /// data = the array that'll be overwritten
    /// elementSize = size of one element in array
    /// offset = offset of data
    void read(void[] data, uint offset = 0)
    {
        rlReadShaderBuffer(glID, data.ptr, cast(uint) data.length, offset);
        checkErrors();
    }
}

/// A program executed on GPU
private class RaylibBasicShader : IBasicShader
{
    private Shader shader;

    // Key is buffer's binding index, value is glID
    private uint[uint] attachedBuffers;

    /// Init the shader: compile and link its vertex and fragment parts
    /// Params:
    /// vs = vertex shader
    /// fs = fragment shader
    void initMe(string vs, string fs)
    {
        shader = LoadShaderFromMemory(vs.ptr, fs.ptr);
    }

    /// Free the shader's resources
    void free()
    {
        // associative arrays support value iterations (like there) and key-value iterations
        foreach(bufferId; attachedBuffers)
        {
            rlUnloadShaderBuffer(bufferId);
            rlCheckErrors();
        }

        UnloadShader(shader);
    }

    /// Attach a GPU buffer to a shader. You can attach a single buffer to multiple shaders
    /// Params:
    /// shader = the shader
    /// buffer = the attach buffer
    /// index = the index of buffer in shader's code
    void attachBuffer(IShaderBuffer buffer, uint bindingIndex)
    {
        attachedBuffers[bindingIndex] = buffer.getInternalID();
    }

    /// Detach a buffer from a shader
    /// Params:
    /// shader = the shader;
    /// index = the index of buffer in shader's code
    void detachBuffer(uint bindingIndex)
    {
        attachedBuffers.remove(bindingIndex);
    }

    /// Begin current shader mode
    void beginMode()
    {
        BeginShaderMode(shader);
    }
    
    /// End current shader mdoe
    void endMode()
    {
        EndShaderMode();
    }

    /// Get uniform variable of this shader
    /// Params:
    /// name = the name of variable in shader
    /// type = the type of variable in shader
    /// Returns: instance of some class that implements IUniform
    IUniform getUniform(string name, UniformType type)
    {
        RaylibUniform uniform = new RaylibUniform();

        uniform.glID = rlGetLocationUniform(shader.id, name.ptr);

        uniform.shaderGlID = shader.id;
        uniform.type = type;

        return uniform;
    }
}

/// A program executed on GPU
private class RaylibComputeShader : IComputeShader
{
    private uint glID;

    // Key is buffer's binding index, value is glID
    private uint[uint] attachedBuffers;

    /// Init the shader: compile and link its code from sources
    /// Params:
    /// source = the source code of the shader
    void initMe(string source)
    {
        glID = rlLoadComputeShaderProgram(rlCompileShader(source.ptr, RL_COMPUTE_SHADER));
        checkErrors();
    }

    /// Free the shader's resources
    void free()
    {
        // associative arrays support value iterations (like there) and key-value iterations
        foreach(bufferId; attachedBuffers)
        {
            rlUnloadShaderBuffer(bufferId);
            rlCheckErrors();
        }

        rlUnloadShaderProgram(glID);
        checkErrors();
    }

    /// Attach a GPU buffer to a shader. You can attach a single buffer to multiple shaders
    /// Params:
    /// shader = the shader
    /// buffer = the attach buffer
    /// index = the index of buffer in shader's code
    void attachBuffer(IShaderBuffer buffer, uint bindingIndex)
    {
        attachedBuffers[bindingIndex] = buffer.getInternalID();
    }

    /// Detach a buffer from a shader
    /// Params:
    /// shader = the shader;
    /// index = the index of buffer in shader's code
    void detachBuffer(uint bindingIndex)
    {
        attachedBuffers.remove(bindingIndex);
    }

    /// Execute the shader
    void execute(uint[3] groupSizes)
    {
        rlEnableShader(glID);

        foreach(bufferIndex, bufferId; attachedBuffers)
        {
            rlBindShaderBuffer(bufferId, bufferIndex);
        }

        rlComputeShaderDispatch(groupSizes[0], groupSizes[1], groupSizes[2]);
        checkErrors();

        rlDisableShader();
    }

    /// Get uniform variable of this shader
    /// Params:
    /// name = the name of variable in shader
    /// type = the type of variable in shader
    /// Returns: instance of some class that implements IUniform
    IUniform getUniform(string name, UniformType type)
    {
        RaylibUniform uniform = new RaylibUniform();

        uniform.glID = rlGetLocationUniform(glID, name.ptr);
        checkErrors();

        uniform.shaderGlID = glID;
        uniform.type = type;

        return uniform;
    }
}

private class RaylibUniform : IUniform
{
    private uint glID;
    private uint shaderGlID;
    private UniformType type;

    /// Set the value of uniform
    /// Params:
    /// value = the pointer to value
    /// count = if uniform is an array, this parameter must be length of the array, otherwise 1
    void setValue(void* value, uint count = 1)
    {
        rlEnableShader(shaderGlID);
        rlSetUniform(glID, value, type, count);
        checkErrors();
        rlDisableShader();
    }
}