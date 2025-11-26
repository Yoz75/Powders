module powders.rendering;

public import davincilib;
import kernel.ecs;
import kc = davincilib.color;
import kernel.jsonutil;
import powders.map;
import powders.particle.register;
import powders.particle.electricity : Conductor, ConductorState;
import powders.particle.temperature;
import raylib;

RenderMode currentRenderMode = RenderMode.color;

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
        // Ugly, but simple. 
        // Renderer is a singletone, so this instance will be assigned to Renderer.instance 
        new Renderer();

        SystemFactory!InitRendererSystem.create();
        SystemFactory!MapRenderSystem.create();
        SystemFactory!RenderableSystem.create();
        SystemFactory!RenderModeSystem.create();
    }
}   

private final class InitRendererSystem : BaseSystem
{
    protected override void beforeUpdate()
    {
        Renderer.instance.startFrame();
        Renderer.instance.clearScreen();
    }

    protected override void afterUpdate()
    {
        Renderer.instance.endFrame();
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

    immutable int[2] resolution = Renderer.instance.getWindowResolution();
    float[2] position;

    position[0] = remap!float(screenPosition[0], 0, resolution[0], 0, 1);
    position[1] = remap!float(screenPosition[1], 0, resolution[1], 0, 1);

    return position;
}

public int[2] relativeScreenPos2ScreenPos(float[2] relativePosition)
{
    import kernel.math;

    immutable int[2] resolution = Renderer.instance.getWindowResolution();

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
        mapSprite = Sprite.create(globalMap.resolution, kc.white);

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
        Renderer.instance.renderAtWorldPos([0, 0], mapSprite);
    }
}

private kc.Color temperature2Color(inout double temperature) pure
{
    import kernel.math;

    /// Maximal temperature, that rendered as a red color. Temperatures above this value are rendered as hot.
    enum maxWarmTemperature = 1000.0;
    enum maxHotTemperature = Temperature.max;

    kc.Color color;

    immutable ubyte normalizedWarm = 
    cast(ubyte) remap(temperature, 0, maxWarmTemperature, 0, 255);

    immutable ubyte normalizedHot = 
    cast(ubyte) remap(temperature, maxWarmTemperature, maxHotTemperature, 200, 255);

    immutable ubyte normalizedCold = 
    cast(ubyte) remap(temperature, 0, Temperature.min, 0, 255);

    ubyte warmColor = normalizedWarm * cast(ubyte) (temperature > 0 && temperature <= maxWarmTemperature);
    ubyte hotColor = normalizedHot * cast(ubyte) (temperature > maxWarmTemperature);
    ubyte coldColor = normalizedCold * cast(ubyte) (temperature < 0);

    // If temperature > 0 -- warm colors (or hot if temperature is too big), if 0 -- black, else -- cold colors
    color.r = cast(ubyte) (warmColor + hotColor);
    color.g = hotColor;
    color.b = cast(ubyte) (coldColor + hotColor);
    color.a = 255;
    return color;
}

private kc.Color sparkle2Color(ConductorState state, kc.Color renderableColor) pure
{
    final switch(state)
    {
        case ConductorState.head:
            return kc.blue;

        case ConductorState.tail:
            return kc.red;

        case ConductorState.nothing:
            return renderableColor;
    }
}

public final class RenderableSystem : MapEntitySystem!MapRenderable
{
    import powders.particle.temperature : Temperature;
    import powders.particle.electricity : Conductor;
    import powders.particle.electricity : Conductor;
    import raylib;

    /// A buffer, that contains prefious frame. It's needed to optimize updating.
    private kc.Color[][] lastFrameBuffer;

    /// Previous state of render mode. Needed to fix render modes after last optimization, bruh
    private RenderMode lastRenderMode;

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

    protected override void update()
    {
        if(lastRenderMode != currentRenderMode)
        {
            foreach(row; chunks)
            {
                foreach(ref chunk_; row)
                {
                    chunk_.state = ChunkState.dirty;
                }
            }
            final switch(currentRenderMode)
            {
                case RenderMode.color: 

                    foreach(x, y, entity_; globalMap)
                    {
                        immutable auto color = entity_.getComponent!MapRenderable.color;
                        lastFrameBuffer[y][x] = color;
                        MapRenderSystem.instance.mapSprite.setPixel([x, y], color); 
                    }
                    
                    break;
                case RenderMode.temperature:

                    foreach(x, y, entity_; globalMap)
                    {
                        immutable auto renderableColor = entity_.getComponent!MapRenderable.color;
                        immutable auto color = entity_.getComponent!Conductor.state.sparkle2Color(renderableColor);
                        lastFrameBuffer[y][x] = color;
                        MapRenderSystem.instance.mapSprite.setPixel([x, y], color); 
                    }

                    break;
                case RenderMode.sparkle:
                    foreach(x, y, entity_; globalMap)
                    {
                        immutable auto color = entity_.getComponent!Temperature().value.temperature2Color();
                        lastFrameBuffer[y][x] = color;
                        MapRenderSystem.instance.mapSprite.setPixel([x, y], color); 
                    }

                    break;
            }

            lastRenderMode = currentRenderMode;
        }

        super.update();
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref MapRenderable renderable)
    {
        debug
        {
            bool hasPosition = entity.hasComponent!Position();
            assert(hasPosition, "DEBUG: AT SOME REASON NOT EVERY ENTITY HAS A POSITION!!11!!1111111!!!!
            KERNEL PANIC!11 SEGMENTATION FAULT (CORE ISN'T DAMPED)");
        }

        immutable kc.Color[RenderMode.max + 1] renderMode2Color = 
        [
            RenderMode.color: renderable.color,
            RenderMode.temperature: entity.getComponent!Temperature.value.temperature2Color(),
            RenderMode.sparkle: entity.getComponent!Conductor.state.sparkle2Color(renderable.color)
        ];

        immutable auto position = entity.getComponent!Position();

        if(lastFrameBuffer[position.xy[1]][position.xy[0]] == renderMode2Color[currentRenderMode] 
         && lastRenderMode == currentRenderMode)
        {
            chunk.state = ChunkState.clean;
            return;
        }

        chunk.state = ChunkState.dirty;
        lastRenderMode = currentRenderMode;

        lastFrameBuffer[position.xy[1]][position.xy[0]] = renderMode2Color[currentRenderMode];
        kc.Color color;
        if(currentRenderMode == RenderMode.temperature)
        {
            color = entity.getComponent!Temperature().value.temperature2Color();
        }
        else if(currentRenderMode == RenderMode.sparkle)
        {
            immutable auto conductor = entity.getComponent!Conductor();
            color = conductor.state.sparkle2Color(renderable.color);
        }
        else
        {  
            color = renderable.color;          
        }
        
        MapRenderSystem.instance.mapSprite.setPixel(position.xy, color); 
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
    import std.math;

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


private class RenderModeSystem : BaseSystem
{
    import powders.input;

    protected override void update()
    {
        if(Input.isKeyDown(Keys.one))
        {
            currentRenderMode = RenderMode.color;
        }
        else if(Input.isKeyDown(Keys.two))
        {
            currentRenderMode = RenderMode.temperature;
        }
        else if(Input.isKeyDown(Keys.three))
        {
            currentRenderMode = RenderMode.sparkle;
        }
    }
}