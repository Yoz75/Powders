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

/// Marker component that tells renderable system to update particle
@Component(OnDestroyAction.destroy) public struct UpdateRenderableMarker
{
    mixin MakeJsonizable;
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

//ТУДУ: сделать наследников этого класса (на каждый рендер мод по одному) и чтоб они там себе внутри буфферы заполняли и выводили, а не это говно с чанками
private abstract class MapShaderProvider
{
    protected IBasicShader shader;

    public IShader getShader() => shader;

    public final void prepare()
    {
        onPrepare();
    }

    protected abstract void onPrepare();
}

private final class MapRenderSystem : BaseSystem
{
    static MapRenderSystem instance;
    private Sprite mapSprite;
    private IBasicShader mapShader;

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

    protected override void onBeforeUpdate()
    {
        mapSprite.applyChanges();
        gameWindow.renderAtWorldPos(mapSprite);
    }
}

/// Function type, that convert entity to color. E.g convert entity's temperature to color and etc
alias renderModeConverter = kc.Color function(Entity entity);

public final class RenderableSystem : System!UpdateRenderableMarker
{
    private renderModeConverter currentRenderModeConverter;

    public override void onCreated()
    {
        updateAll();
    }
    protected override void onUpdated()
    {
        import kernel.simulation;
        World world = Simulation.currentWorld;
        auto data = ComponentPool!UpdateRenderableMarker.instance.getComponents(world);
        Entity[] updatedEntities = new Entity[data.length];

        foreach(i, marker; data)
        {
            immutable Entity entity = ComponentPool!UpdateRenderableMarker.instance.dense2Entity(world, i);
            updatedEntities[i] = entity;

            immutable auto position = entity.getComponent!Position();

            kc.Color color = currentRenderModeConverter(entity);        
            MapRenderSystem.instance.mapSprite.setPixel(position.xy, color);
        }
        
        foreach(entity; updatedEntities)
        {
            entity.removeComponent!UpdateRenderableMarker();
        }
    }

    private void updateAll()
    {
        foreach (x, y, entity; globalMap)
        {
            entity.addComponent!UpdateRenderableMarker();
        }
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
    private struct RenderMode
    {
        renderModeConverter converter;
        Keys key;
    }

    public static RenderModeSystem instance;
    import powders.input;

    private RenderMode[] renderModes;
    private RenderableSystem renderableSystemInstance;

    public this()
    {
        instance = this;
    }

    public void addRenderMode(renderModeConverter converter, Keys selectKey)
    {
        renderModes ~= RenderMode(converter, selectKey);
    }

    public renderModeConverter getCurrentRenderModeConverter()
    {
        return renderableSystemInstance.currentRenderModeConverter;
    }

    public override void onCreated()
    {
        renderableSystemInstance = cast(RenderableSystem) RenderableSystem.instance;

        addRenderMode(&color2color, Keys.one);
        renderableSystemInstance.currentRenderModeConverter = &color2color;
    }

    protected override void onUpdated()
    {
        foreach(renderMode; renderModes)
        {
            if(gameWindow.isKeyPressed(renderMode.key))
            {
                renderableSystemInstance.currentRenderModeConverter = renderMode.converter;
                renderableSystemInstance.updateAll();
            }
        }
    }

    private static Color color2color(Entity entity)
    {
        MapRenderable renderable = entity.getComponent!MapRenderable();
        return renderable.color;
    }
}