/// Implementation of davincilib.abstractions using raylib
module davincilib.raylibimpl;

import davincilib.color;
import davincilib.abstractions;
import raylib;

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

    void setPixel(int[2] position, dvc.Color color)
    {
        ImageDrawPixel(&image, position[0], position[1], cast(raylib.Color) color);   
    }  
    
    /// Update texture's data after image manipulaton
    void applyChanges()
    {
        UpdateTexture(texture, image.data);
    }
    

    void free()
    {
        UnloadTexture(texture);
    }
}

/// Convert position from range 0..resolution to 0..1
/// Params:
///   screenPosition = raw screen position
/// Returns: 
public float[2] screenPos2RelativeScreenPos(uint[2] screenPosition)
{
    import kernel.math;

    immutable int[2] resolution = Renderer.instance.getWindowResolution();
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

public class Renderer : IRenderer!Sprite
{
public:
    static Renderer instance;
    Camera2D camera = Camera2D(Vector2(0, 0), Vector2(0, 0), 0f, 1f);

    this()
    {
        instance = this;
    }    

    void startFrame() { BeginDrawing(); }
    void endFrame() { EndDrawing(); }

    int[2] getWindowResolution() const
    {
        int[2] resolution;

        resolution[0] = GetScreenWidth();
        resolution[1] = GetScreenHeight();

        return resolution;
    }

    bool shouldCloseWindow()
    {
        return WindowShouldClose();
    }

    void clearScreen() const
    {
        ClearBackground(raylib.Color(0, 0, 0, 255));
    }

    /// Render a sprite at world position
    /// Params:
    ///   position = the position
    ///   sprite = the sprite rendered at `position`
    void renderAtWorldPos(float[2] position, ref in Sprite sprite)
    {
        BeginMode2D(camera);

        immutable source = Rectangle(0, 0, sprite.texture.width, sprite.texture.height);

        immutable auto destination = Rectangle(position[0], position[1], 
        sprite.texture.width * sprite.scale[0], 
        sprite.texture.height * sprite.scale[1]);

        immutable auto origin = Vector2(sprite.origin[0], sprite.origin[1]);

        DrawTexturePro(sprite.texture, source, destination, origin, sprite.rotation, cast(raylib.Color) sprite.color);
        EndMode2D();
    }

    /// Render a sprite at a relative screen position
    /// Params:
    ///   position = the position within range [0, 0] .. [1, 1], where [0, 0] -- upper left corner
    ///   sprite = the sprite rendered at `position`
    void renderAtRelativeScreenPos(float[2] position, ref in Sprite sprite)
    {
        import kernel.math;

        auto absolutePosition = relativeScreenPos2ScreenPos(position, getWindowResolution());

        renderAtScreenPos(absolutePosition, sprite);
    }

    /// Render a sprite at an absolute screen position
    /// Params:
    ///   position = the position
    ///   sprite = the sprite rendered at `position`
    void renderAtScreenPos(int[2] position, ref in Sprite sprite)
    {
        import std.stdio; writeln(position);
        immutable auto source = Rectangle(0, 0, sprite.texture.width, sprite.texture.height);

        immutable auto destination = Rectangle(position[0], position[1], 
        sprite.texture.width * sprite.scale[0], 
        sprite.texture.height * sprite.scale[1]);

        immutable auto origin = Vector2(sprite.origin[0], sprite.origin[1]);

        DrawTexturePro(sprite.texture, source, destination, origin, sprite.rotation, cast(raylib.Color) sprite.color);
    }
}
