module powders.particle;

import kernel.ecs;
import kernel.color;
import powders.map;
import powders.rendering;

public struct Temperature
{
public:
    /// Temperature of the particle (Celsius)
    double value;
}

public enum MoveDirection : byte
{
    none = 0,
    negative = -1,
    positive = 1
}

/// Just a marker component of every particle.
public struct Particle
{
    public:
    float mass = 1;
}

public enum GravityDirection : int[2]
{
    none = [0, 0],
    down = [0, 1],
    up = [0, -1],
    left = [-1, 0],
    right = [1, 0]
}
// Marker component that says that this entity is affected by gravity
public struct Gravity
{
    public:
    static GravityDirection direction = GravityDirection.down;
    static float gravity = 9.81;
}

/// Component that says that this entity can move (and fall) like sand
public struct Sand
{
public:
    static float maxVelocity = 16;
    /// Current velocity of the particle [x, y] in cells per update
    float[2] velocity;
}

public struct SandParticleBundle
{
public:
    Temperature temperature;
    Sand sand;
    Particle particle;
    Gravity gravity;
    Adhesion adhesion;
}

public struct StaticParticleBundle
{
public:
    Temperature temperature;
    Particle particle;
}

/// A component that indicates slip particles
public struct Adhesion
{
public:
    /// The slipperiness of particle in range 0..1
    float adhesion = 1;
    /// Can the particle slip, or not?
    bool isActive;
}

/// System, that starts other systems in powders.particle module
public class InitialParticlesSystem : BaseSystem
{
    public override void onCreated()
    {
        assert(globalMap != Map.init, "Initial particle system is being initialized, but map is still wasn't inited!");
        SystemFactory!SandSystem.create();
        SystemFactory!ParticleSpawnSystem.create();
        SystemFactory!GravitySystem.create();
        SystemFactory!AdhesionSystem.create();
        SystemFactory!ChangeGravitySystem.create();
        SystemFactory!SandControllerSelector.create();

        immutable auto mapResolution = globalMap.resolution;

        foreach (i; 0..mapResolution[0])
        {
            auto entity = globalMap.getAt([i, mapResolution[1] - 1]);
            entity.addBundle!StaticParticleBundle();
            entity.getComponent!MapRenderable().value.color = white;
        }
    }
}

/// Something, that can make particles of some type and delete them
public abstract class ParticleLifeController
{
public:
    /// Make entity a particle of some type
    abstract void make(Entity entity);
    abstract void dispose(Entity entity);
}

public class DebugSandController : ParticleLifeController
{
public:
    override void make(Entity entity)
    {
        entity.addBundle!SandParticleBundle();
        entity.getComponent!Adhesion().value.adhesion = 1;
        entity.getComponent!MapRenderable().value.color = Color(255, 0, 0);
    }

    override void dispose(Entity entity)
    {
        entity.removeBundle!SandParticleBundle();
        entity.getComponent!MapRenderable().value.color = black;
    }
}

public class SandController : ParticleLifeController
{
public:
    override void make(Entity entity)
    {
        entity.addBundle!SandParticleBundle();
        entity.getComponent!Adhesion().value.adhesion = 0.98;
        entity.getComponent!MapRenderable().value.color = Color(255, 255, 0);
    }

    override void dispose(Entity entity)
    {
        entity.removeBundle!SandParticleBundle();
        entity.getComponent!MapRenderable().value.color = black;
    }
}

pragma(msg, "TODO: Delete this shit at particle.d and make a GUI");
private class SandControllerSelector : BaseSystem
{
    protected override void update()
    {
        import powders.input;
        if(Input.isKeyDown(Keys.one))
        {
            ParticleSpawnSystem.instance.selectController(new DebugSandController);
        }
        else if(Input.isKeyDown(Keys.two))
        {
            ParticleSpawnSystem.instance.selectController(new SandController);   
        }
    }
}

public class ParticleSpawnSystem : BaseSystem
{
    public static ParticleSpawnSystem instance;
    private ParticleLifeController currentController = new DebugSandController();

    public this()
    {
        instance = this;
    }

    public void selectController(ParticleLifeController controller)
    {
        assert(controller !is null, "maker can't be null!");
        currentController = controller;
    }

    protected override void update()
    {
        import powders.input;
        import raylib : IsMouseButtonDown, MouseButton;

        if (IsMouseButtonDown(MouseButton.MOUSE_BUTTON_LEFT))
        {
            auto position = mouse2MapSpritePosition();

            if (position[0] < 0 || position[1] < 0)
                return;

            auto entity = globalMap.getAt([position[0], position[1]]);
            currentController.make(entity);
        }
        else if(IsMouseButtonDown(MouseButton.MOUSE_BUTTON_RIGHT))
        {
            auto position = mouse2MapSpritePosition();

            if(position[0] < 0 || position[1] < 0)
                return;

            auto entity = globalMap.getAt([position[0], position[1]]);
            currentController.dispose(entity);
        }
    }
}

private class SandSystem : MapEntitySystem!Sand
{
    protected override void updateComponent(Entity entity, ref Sand sand)
    {
        import std.math : round;
        import std.algorithm : clamp;

        auto adhesion = entity.getComponent!Adhesion();

        if(adhesion.hasValue) adhesion.value.isActive = false;

        auto currentPosition = entity.getComponent!Position().value.xy;

        if (sand.velocity[0] == 0 && sand.velocity[1] == 0)
            return;

        sand.velocity[0] = sand.velocity[0].clamp(-Sand.maxVelocity, Sand.maxVelocity);
        sand.velocity[1] = sand.velocity[1].clamp(-Sand.maxVelocity, Sand.maxVelocity);

        int[2] roundedVelocity = [cast(int) sand.velocity[0].round, cast(int) sand.velocity[1].round];

        int[2] targetPosition;
        targetPosition[] = currentPosition[] + roundedVelocity[];

        auto finalPosition = findFurthestFreeCellOnLine(currentPosition, targetPosition);

        if(finalPosition == currentPosition)
        {
            sand.velocity = [0, 0];
            if(adhesion.hasValue) adhesion.value.isActive = true;
            return;
        }

        globalMap.swap(entity, globalMap.getAt(finalPosition));

        if(finalPosition != targetPosition)
            sand.velocity = [0, 0];
    }

    private int[2] findFurthestFreeCellOnLine(int[2] start, int[2] end)
    {
        import std.algorithm : max;
        import std.math : abs;

        int dx = end[0] - start[0];
        int dy = end[1] - start[1];

        int steps = max(abs(dx), abs(dy));
        if (steps == 0)
            return start;

        double stepX = cast(double)dx / steps;
        double stepY = cast(double)dy / steps;

        int[2] lastFree = start;

        for (int i = 1; i <= steps; i++)
        {
            int x = cast(int) (start[0] + stepX * i);
            int y = cast(int) (start[1] + stepY * i);
            int[2] checkPos = [x, y];

            if (globalMap.getAt(checkPos).hasComponent!Particle())
                break;

            lastFree = checkPos;
        }

        return lastFree;
    }
}

private class GravitySystem : MapEntitySystem!Gravity
{
    protected override void updateComponent(Entity entity, ref Gravity gravity)
    {
        if(entity.hasComponent!Sand())
        {
            auto sand = entity.getComponent!Sand().value;
            sand.velocity[] += Gravity.direction[] * gravity.gravity * entity.getComponent!Particle().value.mass;
        }
    }
}

private class ChangeGravitySystem : BaseSystem
{
    protected override void update()
    {
        import powders.input;
        import raylib : IsKeyPressed, KeyboardKey;

        if (Input.isKeyDown(Keys.up))
        {
            Gravity.direction = GravityDirection.up;
        }
        else if (Input.isKeyDown(Keys.down))
        {
            Gravity.direction = GravityDirection.down;
        }
        else if (Input.isKeyDown(Keys.left))
        {
            Gravity.direction = GravityDirection.left;
        }
        else if (Input.isKeyDown(Keys.right))
        {
            Gravity.direction = GravityDirection.right;
        }
    }
}

private class AdhesionSystem : MapEntitySystem!Adhesion
{
    protected override void updateComponent(Entity entity, ref Adhesion adhesion)
    {
        import std.random;

        assert(entity.hasComponent!Sand(), "Adhesion component can be only on Sand particles!");
            
        if(!adhesion.isActive) return;
        
        /*
               -1 0 1
            -1 [][][]
             0 []xx[]
             1 [][][]
        */
        // should be int[2][2], but float[2][2] because of boilerplate
        enum float[2][2][GravityDirection] direction2LeftRightBiases = 
        [
            GravityDirection.none: [[0, 0], [0, 0]],
            GravityDirection.down: [[-1, 0], [1, 0]],
            GravityDirection.left: [[0, -1], [0, 1]],
            GravityDirection.right: [[-1, 0], [1, 0]],
            GravityDirection.up: [[-1, 0], [1, 0]]
        ];

        enum float[2][2][GravityDirection] direction2DiagonalBiases = 
        [
            GravityDirection.none: [[0, 0], [0, 0]],
            GravityDirection.down: [[1, 1], [-1, 1]],
            GravityDirection.left: [[-1, -1], [-1, 1]],
            GravityDirection.right: [[1, -1], [1, 1]],
            GravityDirection.up: [[-1, -1], [1, -1]]
        ];

        float[2][2][GravityDirection] direction2Biases;

        if(uniform01() < adhesion.adhesion)
        {
            direction2Biases = direction2DiagonalBiases;    
        }
        else
        {
            direction2Biases = direction2LeftRightBiases;
        }



        entity.getComponent!Sand().value.velocity[] = 
        direction2Biases[Gravity.direction][uniform(0, 2)][];
    }
}
