module powders.rendering;

public import davincilib;
import kernel.ecs;
import kc = davincilib.color;
import kernel.jsonutil;
import powders.map;
import powders.particle.register;

IWindow!(Sprite, Camera) gameWindow;

/// A thing, renderable on map
@Component(OnDestroyAction.setInit) public struct MapRenderable
{
    mixin MakeJsonizable;
public:
    /// Main color
    @JsonizeField kc.Color color = kc.Color(0, 0, 0, 255);
}

/// System, that starts other systems in powders.rendering module
public final class InitialRenderSystem : BaseSystem
{
    public override void onCreated()
    {
        SystemFactory!InitRendererSystem.create();
        SystemFactory!MapRenderSystem.create();
        SystemFactory!RenderableSystem.create();
        SystemFactory!RenderModeSystem.create();
    }
}   

private final class InitRendererSystem : BaseSystem
{
    protected override void onBeforeUpdate()
    {
        gameWindow.startFrame();
        gameWindow.clearScreen();
    }

    protected override void onAfterUpdate()
    {
        gameWindow.endFrame();
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
public float[2] screenPos2RelativeScreenPos(int[2] screenPosition)
{
    import kernel.math;

    immutable int[2] resolution = gameWindow.getWindowResolution();
    float[2] position;

    position[0] = remap!float(screenPosition[0], 0, resolution[0], 0, 1);
    position[1] = remap!float(screenPosition[1], 0, resolution[1], 0, 1);

    return position;
}

public int[2] relativeScreenPos2ScreenPos(float[2] relativePosition)
{
    import kernel.math;

    immutable int[2] resolution = gameWindow.getWindowResolution();

    int[2] absolutePosition = [0, 0];

    absolutePosition[0] =cast(int) remap!float(relativePosition[0], 0, 1, 0, resolution[0]);
    absolutePosition[1] = cast(int) remap!float(relativePosition[1], 0, 1, 0, resolution[1]);

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
        mapSprite = gameWindow.createAttachedSprite(globalMap.resolution, kc.white);

        foreach (ref Entity entity; globalMap)
        {
            MapRenderable renderable;
            renderable.color = kc.black;
            entity.addComponent!MapRenderable(renderable);
        }
    }

    protected override void onBeforeUpdate()
    {
        gameWindow.applySpriteChanges(cast (immutable Sprite) mapSprite);
        gameWindow.renderAtWorldPos([0, 0], cast (immutable Sprite) mapSprite);
    }
}

/// Function type, that convert entity to color. E.g convert entity's temperature to color and etc
alias renderModeConverter = kc.Color function(Entity entity);

public final class RenderableSystem : MapEntitySystem!MapRenderable
{
    private renderModeConverter currentRenderModeConverter;

    /// A buffer, that contains prefious frame. It's needed to optimize updating.
    private kc.Color[][] lastFrameBuffer;

    /// Previous state of render mode. Needed to fix render modes after last optimization, bruh
    private renderModeConverter lastRenderModeConverter;

    public override void onCreated()
    {
        isPausable = false;

        immutable int[2] resolution = globalMap.resolution;

        lastFrameBuffer = new kc.Color[][](resolution[0], resolution[1]);
    }

    protected override void onAdd(Entity entity)
    {
        markDirty(entity);
    }

    protected override void onAfterUpdate()
    {
        if(lastRenderModeConverter != currentRenderModeConverter)
        {
            foreach(row; chunks)
            {
                foreach(ref chunk_; row)
                {
                    chunk_.makeDirty();
                }
            }

            foreach(x, y, entity_; globalMap)
            {
                immutable auto color = currentRenderModeConverter(entity_);
                lastFrameBuffer[y][x] = color;
                gameWindow.setPixelOfSprite(cast(immutable Sprite) MapRenderSystem.instance.mapSprite, [x, y], color);
            }
        }
            
        super.onUpdated();
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref MapRenderable renderable)
    {
        debug
        {
            bool hasPosition = entity.hasComponent!Position();
            assert(hasPosition, "DEBUG: AT SOME REASON NOT EVERY ENTITY HAS A POSITION!!11!!1111111!!!!
            KERNEL PANIC!11 SEGMENTATION FAULT (CORE ISN'T DAMPED)");
        }

        immutable auto position = entity.getComponent!Position();

        if(lastFrameBuffer[position.xy[1]][position.xy[0]] == currentRenderModeConverter(entity)
            && lastRenderModeConverter == currentRenderModeConverter)
        {
            chunk.makeClean();
            return;
        }

        chunk.makeDirty();
        lastRenderModeConverter = currentRenderModeConverter;

        kc.Color color = lastFrameBuffer[position.xy[1]][position.xy[0]] = currentRenderModeConverter(entity);
        
        gameWindow.setPixelOfSprite(cast(immutable Sprite) MapRenderSystem.instance.mapSprite,
            [position.xy[0], position.xy[1]], color);
    }
}

/// Get pixel position on texture, pointed by mouse
public int[2] mouse2TexturePosition(ref in Sprite sprite)
{
    import powders.input;
    import std.math : cos, sin, PI;

    immutable float[2] position = gameWindow.getMousePosition();

    immutable cx = sprite.origin[0] * sprite.texture.width * sprite.scale[0];
    immutable cy = sprite.origin[1] * sprite.texture.height * sprite.scale[1];

    immutable float lx = position[0] - cx;
    immutable float ly = position[1] - cy;

    immutable rad = -sprite.rotation * (PI / 180);
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
    import powders.input;
    import std.math;

    immutable float[2] position = gameWindow.getMouseWorldPosition();

    immutable cx = sprite.origin[0] * sprite.texture.width * sprite.scale[0];
    immutable cy = sprite.origin[1] * sprite.texture.height * sprite.scale[1];

    immutable float lx = position[0] - cx;
    immutable float ly = position[1] - cy;
    
    immutable rad = -sprite.rotation * (PI / 180);
    immutable cosr = cos(rad);
    immutable sinr = sin(rad);

    immutable rx = lx * cosr - ly * sinr;
    immutable ry = lx * sinr + ly * cosr;

    immutable tx = rx / sprite.scale[0] + sprite.origin[0] * sprite.texture.width;
    immutable ty = ry / sprite.scale[1] + sprite.origin[1] * sprite.texture.height;

    if (tx < 0 || ty < 0 || tx >= sprite.texture.width || ty >= sprite.texture.height)
        return [-1, -1];
    return [cast(int) tx.round(), cast(int) ty.round()];
} 

/// Render modes
public enum RenderMode
{
    /// Render particle's color
    color,
    /// Render particle's temperature
    temperature,
    /// Render particle's sparkle or color if not conductor
    sparkle
}


public class RenderModeSystem : BaseSystem
{
    public static RenderModeSystem instance;
    import powders.input;

    private renderModeConverter[Keys.max + 1] renderModes;

    public this()
    {
        instance = this;
    }

    public void addRenderMode(renderModeConverter converter, Keys selectKey)
    {
        renderModes[selectKey] = converter;
    }

    public renderModeConverter getCurrentRenderModeConverter()
    {
        return (cast(RenderableSystem) RenderableSystem.instance).currentRenderModeConverter;
    }

    public override void onCreated()
    {
        addRenderMode(&color2color, Keys.one);
        (cast(RenderableSystem) RenderableSystem.instance).currentRenderModeConverter = &color2color;
    }

    protected override void onUpdated()
    {
        auto states = gameWindow.getKeyStates();
        foreach(i, state; states)
        {
            if(state && renderModes[i] != renderModeConverter.init)
            {
                (cast(RenderableSystem) RenderableSystem.instance).currentRenderModeConverter = renderModes[i];
            }
        }
    }

    private static Color color2color(Entity entity)
    {
        MapRenderable renderable = entity.getComponent!MapRenderable();
        return renderable.color;
    }
}