module powders.rendering;

public import davincilib;
import kernel.ecs;
import kernel.simulation;
import kc = davincilib.color;
import kernel.jsonutil;
import powders.map;
import powders.particle.register;

IWindow!(Sprite, Camera) gameWindow;

/// Marker component that tells our game to update MapRenderable of this entity
@Component(OnDestroyAction.destroy) public struct ShouldUpdateRenderableMarker
{
    mixin MakeJsonizable;
}

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

    private IComponentPool!MapRenderable renderablePool;
    private IComponentPool!ShouldUpdateRenderableMarker markerPool;

    public this()
    {
        instance = this;
    }

    public override void onCreated()
    {
        import powders.particle.basics;
        mapSprite = Sprite.create(globalMap.resolution, kc.white);

        renderablePool = Simulation.currentWorld.getPoolOf!MapRenderable();
        markerPool = Simulation.currentWorld.getPoolOf!ShouldUpdateRenderableMarker();

        foreach (ref Entity entity; globalMap)
        {
            MapRenderable renderable;
            renderable.color = kc.black;
            renderablePool.addComponent(entity.id, renderable);
            markerPool.addComponent(entity.id, ShouldUpdateRenderableMarker.init);
        }
    }

    protected override void onBeforeUpdate()
    {
        mapSprite.applyChanges();
        gameWindow.renderAtWorldPos([0, 0], mapSprite);
    }
}

/// Function type, that convert entity to color. E.g convert entity's temperature to color and etc
alias renderModeConverter = kc.Color function(Entity entity);

public final class RenderableSystem : System!MapRenderable
{
    private IComponentPool!MapRenderable renderablePool;
    private IComponentPool!ShouldUpdateRenderableMarker renderableMarkerPool;
    private IComponentPool!Position positionPool;

    private renderModeConverter currentRenderModeConverter;

    public override void onCreated()
    {
        renderablePool = Simulation.currentWorld.getPoolOf!MapRenderable();
        renderableMarkerPool = Simulation.currentWorld.getPoolOf!ShouldUpdateRenderableMarker();
        positionPool = Simulation.currentWorld.getPoolOf!Position();
    }

    protected override void onAdd(IEventComponentPool!MapRenderable pool, Entity entity)
    {
        renderableMarkerPool.addComponent(entity.id, ShouldUpdateRenderableMarker.init);
    }

    protected override void onUpdated()
    {
        import kernel.simulation;

        mixin whereHasMany!(MapRenderable, Position, ShouldUpdateRenderableMarker);
        mixin whereHasMany!(Position, MapRenderable, ShouldUpdateRenderableMarker);

        ComponentId[] updatedRenderableIds = whereHas(renderablePool, positionPool, renderableMarkerPool);

        //all pareticles have map renderable so everything is ok
        ComponentId[] positionIds = whereHas(positionPool, renderablePool, renderableMarkerPool);

        foreach(i, id; updatedRenderableIds)
        {
            ref MapRenderable renderable = renderablePool.getComponentWithId(id);
            ref Position position = positionPool.getComponentWithId(positionIds[i]);

            updateComponent(renderable, position);
        }
    }

    //pragma(inline, true)
    private void updateComponent(ref MapRenderable renderable, Position position)
    {        
        auto entity = globalMap.getAt(position.xy);
        kc.Color color = currentRenderModeConverter(entity);
        MapRenderSystem.instance.mapSprite.setPixel(position.xy, color);
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
        return (cast(RenderableSystem) RenderableSystem.instance).currentRenderModeConverter;
    }

    public override void onCreated()
    {
        addRenderMode(&color2color, Keys.one);
        (cast(RenderableSystem) RenderableSystem.instance).currentRenderModeConverter = &color2color;
    }

    protected override void onUpdated()
    {
        foreach(renderMode; renderModes)
        {
            if(gameWindow.isKeyPressed(renderMode.key))
            {
                (cast(RenderableSystem) RenderableSystem.instance).currentRenderModeConverter = renderMode.converter;
            }
        }
    }

    private static Color color2color(Entity entity)
    {
        auto pool = Simulation.currentWorld.getPoolOf!MapRenderable();
        
        MapRenderable renderable = pool.getComponent(entity.id);
        return renderable.color;
    }
}