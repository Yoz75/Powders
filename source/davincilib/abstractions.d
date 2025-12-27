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

/// A god interface for handling all User I\O stuff
mixin TODO!"Try to make this interface not a god one!";
interface IWindow(TSprite, TCamera) if(isSpriteType!TSprite)
{
public:

    /// Initialize render window
    /// Params:
    ///   resolution = the resolution of window
    ///   isFullscreen = should window be fullscreen or not
    ///   title = the title of window
    void initWindow(immutable int[2] resolution, immutable bool isFullscreen, immutable string title);

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
    void renderAtScreenPos(immutable int[2] position, immutable TSprite sprite);

    /// Render an instance of `TSprite` at a relative screen position (from 0 to 1 for both dimensions)
    void renderAtRelativeScreenPos(immutable float[2] position, immutable TSprite sprite);
    
    /// Render an instance of `TSprite` at world position
    void renderAtWorldPos(immutable float[2] position, immutable TSprite sprite);

    /// Clear screen using black color
    void clearScreen();

    /// Should we close the window or not?
    bool shouldCloseWindow();

    /// Is key down?
    /// Returns: true if key is down, false if not
    bool isKeyDown(immutable Keys key);

    /// Was key prassed this frame?
    /// Returns: true if key was pressed this frame, false otherwise
    bool isKeyPressed(immutable Keys key);

    /// Get position of mouse
    /// Returns: position of mouse as float[2]
    float[2] getMousePosition();

    /// Get position of mouse, but at world coordinates
    /// Returns: position of mouse as float[2]
    float[2] getMouseWorldPosition();

    /// Get the state of a mouse button
    /// Returns: true when down and false otherwise
    bool isMouseButtonDown(immutable MouseButtons button);

    bool drawGUIButton(immutable int[2] absoluteScale, immutable int[2] absolutePosition, immutable string text);

    void drawText(immutable string text, immutable int[2] position, immutable int fontSize, immutable dvc.Color color);

    /// Create sprite using `TSprite.create` method, that attached to this window
    TSprite createAttachedSprite(immutable int[2] resolution, immutable davincilib.Color color);

    /// Set the target frame rate of the window
    void setTargetFPS(immutable int fps);

    /// Get the time in seconds for last drawn frame
    float getDeltaTime();

    /// Get the movement of wheel
    float getMouseWheelMove();

    float[2] convertScreen2WorldPosition(immutable int[2] screenPosition);

    void setPixelOfSprite(immutable TSprite attachedSprite, immutable int[2] position,
        immutable davincilib.Color color);

    void applySpriteChanges(immutable TSprite attachedSprite);

    bool[Keys.max + 1] getKeyStates();
}