module davincilib.abstractions;

import kernel.todo;
import dvc = davincilib.color;

/// Add sprite type's fields to your type. This mixin adds such fields like `color`, `scale`, `origin`, and `rotation`. 
/// But you should implement other staff by yourself.
mixin template AddSpriteFields()
{
    static import dvc = davincilib.color;
    public dvc.Color color;
    public float[2] scale = [1, 1], origin = [0.5, 0.5];
    public float rotation = 0;
}

import std.traits;
import std.typetuple;
/// Template, that validates that `TSprite` is a valid sprite type. To be valid type `TSprite` must have next members:
///     color, scale, origin, rotation -- I think there's clear everything.
///     create(int[2] resolution, Color color, IWindow window) -- static function, that returns a new `TSprite`. This method should be called in the render thread.
///     setPixel(int[2], Color color) -- self-describing code, bro
///     applyChanges() -- a function, that applies made by `setPixel` changes or does nothing (implementation specific)
///     free() -- a function, that frees resources of sprite or does nothing (ditto)
template isSpriteType(TSprite)
{
    enum bool isSpriteType = 
        is(typeof(TSprite.color) == dvc.Color) &
        is(typeof(TSprite.scale) == float[2]) &
        is(typeof(TSprite.origin) == float[2]) &
        is(typeof(TSprite.rotation) == float) &

        isFunction!(TSprite.create) &
        isFunction!(TSprite.setPixel) &
        isFunction!(TSprite.applyChanges) &
        isFunction!(TSprite.free) &

        is(Parameters!(TSprite.create) == AliasSeq!(int[2], dvc.Color)) &
        is(Parameters!(TSprite.setPixel) == AliasSeq!(int[2], dvc.Color)) &
        (Parameters!(TSprite.applyChanges) == AliasSeq!()) &
        (Parameters!(TSprite.free) == AliasSeq!());
}

/// Hint that tells driver how we will use our buffer
public enum BufferUsageHint
{
    /// Fast data flow, From cpu to gpu
    StreamCPU2GPU =0x88E0,
    /// Fast data flow, From gpu to cpu
    StreamGPU2CPU,
    /// Fast data flow, From gpu to gpu
    StreamGPU2GPU,

    /// Data's being written once and being read many times, From cpu to gpu
    StaticCPU2GPU,
    /// Data's being written once and being read many times, From gpu to cpu
    StaticGPU2CPU,
    /// Data's being written once and being read many times, From gpu to gpu
    StaticGPU2GPU,

    /// Medium data flow, From cpu to gpu
    DynamicCPU2GPU,
    /// Medium data flow, From gpu to cpu
    DynamicGPU2CPU,
    /// Medium data flow, From gpu to gpu
    DynamicGPU2GPU,
}

public enum UniformType
{
    float_ = 0,
    vector2,
    vector3,
    vector4,

    int_,
    vector2i,
    vector3i,
    vector4i,

    uint_,
    vector2ui,
    vector3ui,
    vector4ui,

    sampler2d
}

public enum MouseButtons
{
    left = 0,
    right = 1
}

public enum Keys
{
    none = 0,
    apostrophe = 39,
    space = 32,
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

/// A god interface for handling all User I\O stuff and graphics stuff
mixin TODO!"Try to make this interface not a god one!";
interface IWindow(TSprite, TCamera) if(isSpriteType!TSprite)
{
public:

    /// Initialize render window
    /// Params:
    ///   resolution = the resolution of window
    ///   isFullscreen = should window be fullscreen or not
    ///   title = the title of window
    void initWindow(int[2] resolution, bool isFullscreen, string title);

    /// Get the render camera of window.
    TCamera getCamera();

    /// Set the render camera of window
    void setCamera(TCamera camera);

    void startFrame();

    void endFrame();

    /// Get the resolution of render window
    /// Returns: the window resolution
    int[2] getWindowResolution();

    /// Should window be closed?
    bool shouldCloseWindow();

    /// Render an instance of `TSprite` at a screen position
    void renderAtScreenPos(int[2] position, TSprite sprite);

    /// Render an instance of `TSprite` at a relative screen position (from 0 to 1 for both dimensions)
    void renderAtRelativeScreenPos(float[2] position, TSprite sprite);
    
    /// Render an instance of `TSprite` at world position
    void renderAtWorldPos(float[2] position, TSprite sprite);

    /// Clear screen using black color
    void clearScreen();

    /// Should we close the window or not?
    bool shouldCloseWindow();

    /// Is key down?
    /// Returns: true if key is down, false if not
    bool isKeyDown(Keys key);

    /// Was key prassed this frame?
    /// Returns: true if key was pressed this frame, false otherwise
    bool isKeyPressed(Keys key);

    /// Get position of mouse
    /// Returns: position of mouse as float[2]
    float[2] getMousePosition();

    /// Get position of mouse, but at world coordinates
    /// Returns: position of mouse as float[2]
    float[2] getMouseWorldPosition();

    /// Get time of rendering previous frame
    float getDeltaTime();

    /// Get the state of a mouse button
    /// Returns: true when down and false otherwise
    bool isMouseButtonDown(MouseButtons button);

    bool drawGUIButton(int[2] absoluteScale, int[2] absolutePosition, string text);

    void drawText(string text, int[2] position, int fontSize, dvc.Color color);

    /// Set the target frame rate of the window
    void setTargetFPS(int fps);

    /// Get the movement of wheel
    float getMouseWheelMove();

    float[2] convertScreen2WorldPosition(int[2] screenPosition);

    /// Get a new uninitialized shader buffer
    /// Returns: instance of some class that implements `IShaderBuffer`
    IShaderBuffer getNewUninitedBuffer();

    /// Get a new unitialized compute shader
    /// Returns: instance of some class that implements `IComputeShader`
    IComputeShader getNewUninitedComputeShader();

    /// Get a new unitialized basic shader
    /// Returns: instance of some class that implements `IBasicShader`
    IBasicShader getNewUninitedBasicShader();
}

enum ShaderStage
{
    Vertex,
    Fragment,
    Compute
}

/// A buffer allocated on GPU
public interface IShaderBuffer
{
    /// Initialize this buffer
    /// Params:
    /// size = size of buffer in bytes
    /// data = the initial data of buffer, if `data` == null, buffer won't be initialized
    /// hint = hint that tells driver how we'll use our buffer
    void initMe(uint size, void* data, BufferUsageHint hint);

    /// Get internal id of the buffer
    uint getInternalID();

    /// Free GPU resources of the buffer
    void free();
    
    /// Update SSBO buffer's value.
    /// Params:
    /// data = the new data
    /// offset = ofset of data
    void update (void[] data, uint offset = 0);

    /// Read SSBO buffer's value
    /// Params:
    /// data = the array that'll be overwritten
    /// offset = offset of data
    void read(void[] data, uint offset = 0);
}


public interface IComputeShader : IShader
{
    /// Init the shader: compile and link its code from sources
    /// Params:
    /// source = the source code of the shader
    void initMe(string source);

    /// Execute the shader
    void execute(uint[3] groupSizes);
}

public interface IBasicShader : IShader
{
    /// Init the shader: compile and link its vertex and fragment parts
    /// Params:
    /// vs = vertex shader
    /// fs = fragment shader
    void initMe(string vs, string fs);

    /// Begin current shader mode
    void beginMode();
    
    /// End current shader mdoe
    void endMode();
}

/// A program executed on GPU
public interface IShader
{
    /// Free the shader's resources
    void free();

    /// Attach a GPU buffer to a shader. You can attach a single buffer to multiple shaders
    /// Params:
    /// shader = the shader
    /// buffer = the attach buffer
    /// bindingIndex = the binding index of buffer in shader's code
    void attachBuffer(IShaderBuffer buffer, uint bindingIndex);

    /// Detach a buffer from a shader
    /// Params:
    /// shader = the shader;
    /// index = the index of buffer in shader's code
    void detachBuffer(uint bindingIndex);

    /// Get uniform variable of this shader
    /// Params:
    /// name = the name of variable in shader
    /// type = the type of variable in shader
    /// Returns: instance of some class that implements IUniform
    IUniform getUniform(string name, UniformType type);
}

/// A shader uniform variable
public interface IUniform
{
    /// Set the value of uniform
    /// Params:
    /// value = the pointer to value
    /// count = if uniform is an array, this parameter must be length of the array, otherwise 1
    void setValue(void* value, uint count = 1);
}