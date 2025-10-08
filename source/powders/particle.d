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

/// Component, that has every particle
public struct Particle
{
    public:
    enum idSize = 12;
    /// The id of particle's type. Needed for creating/deleting etc.
    char[idSize] typeId;
    /// Particle's mass
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
public struct Powder
{
public:
    static float maxVelocity = 16;
    /// Current velocity of the particle [x, y] in cells per update
    float[2] velocity;
}

public struct PowderParticleBundle
{
public:
    Temperature temperature;
    Powder powder;
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
        SystemFactory!PowderSystem.create();
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

    /// Associative array, that contains all life controllers for specific particles
    /// (needed for simpler disposing and creating)
    static ParticleLifeController[char[Particle.idSize]] id2Controller; 

    /// Create a new particle life controller
    static T create(this T)()
    {
        T self = new T();
        id2Controller[self.getTypeId()] = self;

        return self;
    }

    /// Get unique id of particle's type
    abstract char[Particle.idSize] getTypeId();

    /// Make entity a particle of some type
    abstract void make(Entity entity);

    /// Dispose particle
    abstract void dispose(Entity entity);
}

public class DebugSandController : ParticleLifeController
{
public:
    override char[Particle.idSize] getTypeId() => "DebugSand";

    override void make(Entity entity)
    {
        entity.addBundle!PowderParticleBundle();
        entity.getComponent!Particle().value.typeId = getTypeId();
        entity.getComponent!Adhesion().value.adhesion = 1;
        entity.getComponent!MapRenderable().value.color = Color(255, 0, 0);
    }

    override void dispose(Entity entity)
    {
        entity.removeBundle!PowderParticleBundle();
        entity.getComponent!MapRenderable().value.color = black;
    }
}

public class SandController : ParticleLifeController
{
public:

    override char[Particle.idSize] getTypeId() => "Sand";

    override void make(Entity entity)
    {
        entity.addBundle!PowderParticleBundle();
        entity.getComponent!Particle().value.typeId = getTypeId();
        entity.getComponent!Adhesion().value.adhesion = 0.98;
        entity.getComponent!MapRenderable().value.color = Color(255, 255, 0);
    }

    override void dispose(Entity entity)
    {
        entity.removeBundle!PowderParticleBundle();
        entity.getComponent!MapRenderable().value.color = black;
    }
}

pragma(msg, "TODO: Delete this shit at particle.d and make a GUI");
private class SandControllerSelector : BaseSystem  
{
    private ParticleLifeController debugSandController;
    private ParticleLifeController sandController;

    public override void onCreated()
    {
        debugSandController = ParticleLifeController.create!DebugSandController();
        sandController = ParticleLifeController.create!SandController();
    }

    protected override void update()
    {
        import powders.input;
        if(Input.isKeyDown(Keys.one))
        {
            ParticleSpawnSystem.instance.selectController(debugSandController);
        }
        else if(Input.isKeyDown(Keys.two))
        {
            ParticleSpawnSystem.instance.selectController(sandController);   
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
            
            auto particle = entity.getComponent!Particle;

            if(particle.hasValue)
            {
                auto controller = particle.value.typeId in ParticleLifeController.id2Controller;
                if(controller is null) return;

                controller.dispose(entity);
            }

        }
    }
}

private class PowderSystem : MapEntitySystem!Powder
{
    protected override void updateComponent(Entity entity, ref Powder powder)
    {
        import std.math : round;
        import std.algorithm : clamp;

        auto adhesion = entity.getComponent!Adhesion();

        if(adhesion.hasValue) adhesion.value.isActive = false;

        auto currentPosition = entity.getComponent!Position().value.xy;

        if (powder.velocity[0] == 0 && powder.velocity[1] == 0)
            return;

        powder.velocity[0] = powder.velocity[0].clamp(-Powder.maxVelocity, Powder.maxVelocity);
        powder.velocity[1] = powder.velocity[1].clamp(-Powder.maxVelocity, Powder.maxVelocity);

        int[2] roundedVelocity = [cast(int) powder.velocity[0].round, cast(int) powder.velocity[1].round];

        int[2] targetPosition;
        targetPosition[] = currentPosition[] + roundedVelocity[];

        auto finalPosition = findFurthestFreeCellOnLine(currentPosition, targetPosition);

        if(finalPosition == currentPosition)
        {
            powder.velocity = [0, 0];
            if(adhesion.hasValue) adhesion.value.isActive = true;
            return;
        }

        globalMap.swap(entity, globalMap.getAt(finalPosition));

        if(finalPosition != targetPosition)
            powder.velocity = [0, 0];
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
        if(entity.hasComponent!Powder())
        {
            auto sand = entity.getComponent!Powder().value;
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

        assert(entity.hasComponent!Powder(), "Adhesion component can be only on Powder particles!");
            
        if(!adhesion.isActive) return;
        
        auto position = entity.getComponent!Position().value;

        int[2] belowPosition = [position.xy[0] + Gravity.direction[0], position.xy[1] + Gravity.direction[1]];

        // at some reason sometimes there are "holes", delete this if you know how to fix that holes other way.
        if(!globalMap.getAt(belowPosition).hasComponent!Particle)
        {
            return;
        }

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

        entity.getComponent!Powder().value.velocity[] = 
        direction2Biases[Gravity.direction][uniform(0, 2)][];
    }
}
