module powders.rendering;

public import kernel.color;
import kernel.ecs;
import kc = kernel.color;
import kernel.jsonutil;
import powders.map;
import powders.particle.register;
import raylib;

/// Global camera instance
Camera2D globalCamera = Camera2D(Vector2(0, 0), Vector2(0, 0), 0, 1);

/// Global renderer instance
Renderer globalRenderer;

/// A thing, renderable on map
@Component(MapRenderable.stringof) public struct MapRenderable
{
    mixin MakeJsonizable;
public:
    /// Main color
    @JsonizeField kc.Color color;
}

/// System, that starts other systems in powders.rendering module
public final class InitialRenderSystem : BaseSystem
{
    public override void onCreated()
    {
        SystemFactory!InitRendererSystem.create();
        SystemFactory!MapRenderSystem.create();
        SystemFactory!RenderableSystem.create();
    }
}   

private final class InitRendererSystem : BaseSystem
{
    protected override void beforeUpdate()
    {
        globalRenderer.startFrame();
        globalRenderer.clearScreen();
    }

    protected override void afterUpdate()
    {
        globalRenderer.endFrame();
    }
}

/// Get map's pixel position, pointed by mouse
/// Returns: pixel on map, pointed by mouse or [-1, -1] if mouse is out of map
public int[2] mouse2MapSpritePosition()
{
    assert(MapRenderSystem.instance !is null, 
    "MapRenderSystem isn't initialized yet, but mouse2mapPosition was called!");

    return mouseWorld2TexturePosition(MapRenderSystem.instance.mapSprite);
}

/// Convert position from range 0..resolution to 0..1
/// Params:
///   screenPosition = raw screen position
/// Returns: 
public float[2] screenPos2RelativeScreenPos(uint[2] screenPosition)
{
    import kernel.math;

    immutable uint[2] resolution = globalRenderer.getResolution();
    float[2] position;

    position[0] = remap!float(screenPosition[0], 0, resolution[0], 0, 1);
    position[1] = remap!float(screenPosition[1], 0, resolution[1], 0, 1);

    return position;
}

public uint[2] relativeScreenPos2ScreenPos(float[2] relativePosition)
{
    import kernel.math;

    immutable uint[2] resolution = globalRenderer.getResolution();

    uint[2] absolutePosition = [0, 0];

    absolutePosition[0] =cast(uint) remap!float(relativePosition[0], 0, 1, 0, resolution[0]);
    absolutePosition[1] = cast(uint) remap!float(relativePosition[1], 0, 1, 0, resolution[1]);

    return absolutePosition;
}

private final class MapRenderSystem : BaseSystem
{
    static MapRenderSystem instance;
    private Sprite mapSprite;

    public this()
    {
        instance = this;
    }

    public override void onCreated()
    {
        import powders.particle.basics;
        mapSprite = Sprite.create(globalMap.resolution);

        foreach (ref Entity entity; globalMap)
        {
            MapRenderable renderable;
            renderable.color = kc.black;
            entity.addComponent!MapRenderable(renderable);
        }
    }

    protected override void update()
    {
        mapSprite.applyChanges();
        globalRenderer.renderAtWorldPosition([0, 0], mapSprite);
    }
}

private final class RenderableSystem : MapEntitySystem!MapRenderable
{
    import raylib;

    protected override void updateComponent(Entity entity, ref MapRenderable renderable)
    {
        auto position = entity.getComponent!Position();
        assert(position.hasValue, "DEBUG: AT SOME REASON NOT EVERY ENTITY HAS A POSITION!!11!!1111111!!!!
         KERNEL PANIC!11 SEGMENTATION FAULT (CORE ISN'T DAMPED)");

        MapRenderSystem.instance.mapSprite.setPixel(position.value.xy, renderable.color); 
    }
}

public struct Sprite
{
public:
    /// Sprite's tint color
    kc.Color color;
    /// Sprite's image
    Image image;
    /// Sprite's scale
    float[2] scale;
    /// Sprite's origin (for rotation and scaling)
    float[2] origin;
    /// Sprite's rotation (degrees)
    float rotation;

    /// The raylib's texture for the sprite
    private Texture2D texture;

    static Sprite create(int[2] resolution)
    {
        Sprite sprite;

        /*
            Fucking d's floats are NaN's by default.
            Maybe that's a good thing, but NOT EVEN SINGLE OTHER LANGUAGE I KNOW DOES THAT, THEY HAVE ZERO BY DEFAULT.
        */
        sprite.scale[] = 1f;
        sprite.origin[] = .5f;
        sprite.rotation = 0f;

        sprite.color = kc.white;
        sprite.image = GenImageColor(resolution[0], resolution[1], Colors.WHITE);
        sprite.texture = LoadTextureFromImage(sprite.image);

        return sprite;
    }

    /// Update texture's data after image manipulaton
    pragma(inline, true)
    {
        void setPixel(int[2] position, kc.Color color)
        {
            ImageDrawPixel(&image, position[0], position[1], cast(raylib.Color) color);   
        }

        void applyChanges()
        {
            UpdateTexture(texture, image.data);
        }
    }

    void free()
    {
        UnloadTexture(texture);
    }
}

/// Get pixel position on texture, pointed by mouse
public int[2] mouse2TexturePosition(ref in Sprite sprite)
{
    import raylib;
    import powders.input;
    import std.math : cos, sin;

    immutable float[2] position = Input.getMousePosition();

    immutable cx = sprite.origin[0] * sprite.texture.width * sprite.scale[0];
    immutable cy = sprite.origin[1] * sprite.texture.height * sprite.scale[1];

    immutable float lx = position[0] - cx;
    immutable float ly = position[1] - cy;

    immutable rad = -sprite.rotation * DEG2RAD;
    immutable cosr = cos(rad);
    immutable sinr = sin(rad);

    immutable rx = lx * cosr - ly * sinr;
    immutable ry = lx * sinr + ly * cosr;

    immutable tx = rx / sprite.scale[0] + sprite.origin[0] * sprite.texture.width;
    immutable ty = ry / sprite.scale[1] + sprite.origin[1] * sprite.texture.height;

    if (tx < 0 || ty < 0 || tx >= sprite.texture.width || ty >= sprite.texture.height)
        return [-1, -1];
    return [cast(int)tx, cast(int)ty];
} 

/// Get pixel position on texture, pointed by mouse, but with world coordinates
public int[2] mouseWorld2TexturePosition(ref in Sprite sprite)
{
    import raylib;
    import powders.input;
    import std.math : cos, sin;

    immutable float[2] position = Input.getMouseWorldPosition();

    immutable cx = sprite.origin[0] * sprite.texture.width * sprite.scale[0];
    immutable cy = sprite.origin[1] * sprite.texture.height * sprite.scale[1];

    immutable float lx = position[0] - cx;
    immutable float ly = position[1] - cy;
    
    immutable rad = -sprite.rotation * DEG2RAD;
    immutable cosr = cos(rad);
    immutable sinr = sin(rad);

    immutable rx = lx * cosr - ly * sinr;
    immutable ry = lx * sinr + ly * cosr;

    immutable tx = rx / sprite.scale[0] + sprite.origin[0] * sprite.texture.width;
    immutable ty = ry / sprite.scale[1] + sprite.origin[1] * sprite.texture.height;

    if (tx < 0 || ty < 0 || tx >= sprite.texture.width || ty >= sprite.texture.height)
        return [-1, -1];
    return [cast(int)tx, cast(int)ty];
} 


/// Rendererstruct to render staff
public struct Renderer
{
    public void startFrame() { BeginDrawing(); }
    public void endFrame() { EndDrawing(); }

    public uint[2] getResolution() const
    {
        uint[2] resolution;

        resolution[0] = GetScreenWidth();
        resolution[1] = GetScreenHeight();

        return resolution;
    }

    public void clearScreen() const
    {
        ClearBackground(raylib.Color(0, 0, 0, 255));
    }

    /// Render a sprite at world position
    /// Params:
    ///   position = the position
    ///   sprite = the sprite rendered at `position`
    public void renderAtWorldPosition(float[2] position, ref in Sprite sprite)
    {
        BeginMode2D(globalCamera);

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
    public void renderAtRelativeScreenPosition(float[2] position, ref in Sprite sprite)
    {
        import kernel.math;

        auto absolutePosition = relativeScreenPos2ScreenPos(position);

        renderAtScreenPosition(absolutePosition, sprite);
    }

    /// Render a sprite at an absolute screen position
    /// Params:
    ///   position = the position
    ///   sprite = the sprite rendered at `position`
    public void renderAtScreenPosition(uint[2] position, ref in Sprite sprite)
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