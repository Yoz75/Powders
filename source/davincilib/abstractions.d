module davincilib.abstractions;

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
///     create(int[2] resolution, Color color) -- static function, that returns a new `TSprite` instance
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

interface IRenderer(TSprite) if(isSpriteType!TSprite)
{
    /// Start frame or do nothing if not needed
    void startFrame();

    /// End frame or do nothing if not needed
    void endFrame();
    
    /// Get the resolution of render window
    /// Returns: the window resolution
    int[2] getWindowResolution();

    /// Should window be closed?
    bool shouldCloseWindow();

    /// Render an instance of `TSprite` at a screen position
    void renderAtScreenPos(int[2] position, ref in TSprite sprite);

    /// Render an instance of `TSprite` at a relative screen position (from 0 to 1 for both dimensions)
    void renderAtRelativeScreenPos(float[2] position, ref in TSprite sprite);
    
    /// Render an instance of `TSprite` at world position
    void renderAtWorldPos(float[2] position, ref in TSprite sprite);

    /// Clear screen using black color
    void clearScreen();
}