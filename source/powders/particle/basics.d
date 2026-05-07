/// The module, in witch described all components and sistems
module powders.particle.basics;

import kernel.ecs;
import powders.map;
import powders.particle.register;
import powders.io;
import powders.rendering;

alias ParticleId = string;
alias VelocityScalar = byte;

/// Component, that has every particle
@Component(OnDestroyAction.destroy) public struct Particle
{
    mixin MakeJsonizable;

public:
    /// The id of particle's type. Needed for creating/deleting etc.
    ParticleId typeId;
}


/// Marker component that tells game that this particle isn't normal particle and not supposed to stay (e.g delta temperature)
@Component(OnDestroyAction.destroy) public struct Hollow
{
    mixin MakeJsonizable;
}

public enum GravityDirection : VelocityScalar[2]
{
    none = [0, 0],
    down = [0, 1],
    up = [0, -1],
    left = [-1, 0],
    right = [1, 0]
}
// Component that says that this entity is affected by gravity
@Component(OnDestroyAction.destroy) public struct Gravity
{
    mixin MakeJsonizable;

public:
    static GravityDirection direction = GravityDirection.down;
    static VelocityScalar gravity = 10;
}

/// Component that says that this entity can move
@Component(OnDestroyAction.destroy) public struct Movable
{
    mixin MakeJsonizable;

public:
    bool isFalling;
    static VelocityScalar maxVelocity = cast(VelocityScalar) 100;
    /// Current velocity of the particle [x, y] in cells per update
    VelocityScalar[2] velocity = [0, 0];
}

// A component, that indicates that this particle should slip like sand
@Component(OnDestroyAction.destroy) public struct Powder
{
    mixin MakeJsonizable;
}

/// A component that indicates slip particles
@Component(OnDestroyAction.destroy) public struct Adhesion
{
    mixin MakeJsonizable;

public:
    /// The slipperiness of particle in range 0..1
    @JsonizeField float adhesion = 1;
}

/// A particle, that can turn into `result` when hits `other`
@Component(OnDestroyAction.destroy) public struct Combine
{
    mixin MakeJsonizable;
public:
    @JsonizeField ParticleId otherId;
    @JsonizeField ParticleId resultId;
}

@Component(OnDestroyAction.destroy) public struct Gas
{
    mixin MakeJsonizable;
}

public class MovableSystem : MapEntitySystem!Movable
{
    /// Calls when `self` moved and swapped with `other`
    public void delegate(Entity self, Entity other)[] onMoved;
    
    private ComponentPool!UpdateRenderableMarker markers;
    private ComponentPool!Position positions;
    private ComponentPool!Particle particles;

    public override void onCreated()
    {
        markers = currentWorld.getPoolOf!UpdateRenderableMarker;
        positions = currentWorld.getPoolOf!Position;
        particles = currentWorld.getPoolOf!Particle;

        onMoved ~= (Entity self, Entity other) 
        {
            markers.addComponent(self);
            markers.addComponent(other);
        };
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Movable movable)
    {
        import std.math : round;
        import std.algorithm : clamp;

        movable.isFalling = true;
        auto currentPosition = positions.getComponent(entity).xy;

        if (movable.velocity[0] == 0 && movable.velocity[1] == 0)
            return;

        movable.velocity[0] = movable.velocity[0].clamp(cast(VelocityScalar) -Movable.maxVelocity, Movable.maxVelocity);
        movable.velocity[1] = movable.velocity[1].clamp(cast(VelocityScalar) -Movable.maxVelocity, Movable.maxVelocity);        

        int[2] roundedVelocity = [cast(int) movable.velocity[0], cast(int) movable.velocity[1]];

        int[2] targetPosition;
        targetPosition[] = currentPosition[] + roundedVelocity[];

        auto finalPosition = findFurthestFreeCellOnLine(currentPosition, targetPosition);

        if(finalPosition == currentPosition)
        {
            movable.velocity = [0, 0];
            movable.isFalling = false;
            
            return;
        }

        Entity other = globalMap.getAt(finalPosition);

        globalMap.swap(entity, other);

        foreach(action; onMoved)
        {
            action(entity, other);
        }

        if(finalPosition != targetPosition)
            movable.velocity = [0, 0];
    }

    private int[2] findFurthestFreeCellOnLine(int[2] start, int[2] end)
    {
        import std.algorithm : max;
        import std.math : abs;

        immutable int dx = end[0] - start[0];
        immutable int dy = end[1] - start[1];

        immutable int steps = max(abs(dx), abs(dy));
        if (steps == 0)
            return start;

        double stepX = cast(double)dx / steps;
        double stepY = cast(double)dy / steps;

        int[2] lastFree = start;

        for (int i = 1; i <= steps; i++)
        {
            import powders.particle.loading : airTypeId;
            int x = cast(int) (start[0] + stepX * i);
            int y = cast(int) (start[1] + stepY * i);
            int[2] checkPos = [x, y];

            if (particles.getComponent(globalMap.getAt(checkPos)).typeId != airTypeId)
                break;

            lastFree = checkPos;
        }

        return lastFree;
    }
}

public class GravitySystem : System!Gravity
{
    import kernel.simulation;
    import powders.timecontrol;

    private ComponentPool!Movable movables;
    private ComponentPool!Gravity gravities;

    public override void onCreated()
    {
        movables = currentWorld.getPoolOf!Movable;
        gravities = currentWorld.getPoolOf!Gravity;
    }

    protected override void onUpdated()
    {
        if(globalGameState == GameState.pause) return;
        
        auto data = movables.getComponents();

        foreach(i, ref movable; data)
        {
            Entity entity = movables.dense2Entity(currentWorld, i);

            if(gravities.hasComponent(entity))
            {
                movable.velocity[] += Gravity.direction[] * Gravity.gravity;
            }
        }
    }
}

public class ChangeGravitySystem : BaseSystem
{
    protected override void onUpdated()
    {
        import powders.input;

        if (gameWindow.isKeyDown(Keys.up))
        {
            Gravity.direction = GravityDirection.up;
        }
        else if (gameWindow.isKeyDown(Keys.down))
        {
            Gravity.direction = GravityDirection.down;
        }
        else if (gameWindow.isKeyDown(Keys.left))
        {
            Gravity.direction = GravityDirection.left;
        }
        else if (gameWindow.isKeyDown(Keys.right))
        {
            Gravity.direction = GravityDirection.right;
        }
        else if (gameWindow.isKeyDown(Keys.e))
        {
            Gravity.direction = GravityDirection.none;
        }
    }
}

public class PowderSystem : System!Powder
{
    private uint fallDirection;
    private ComponentPool!Powder powders;
    private ComponentPool!Movable movables;

    public override void onCreated()
    {
        powders = currentWorld.getPoolOf!Powder();
        movables = currentWorld.getPoolOf!Movable();
    }

    protected override void onUpdated()
    {
        fallDirection++;
        auto data = powders.getComponents();

        foreach(i, ref powder; data)
        {
            Entity entity = powders.dense2Entity(currentWorld, i);
            updateComponent(entity, powder);
        }
    }

    pragma(inline, true)
    private void updateComponent(Entity entity, ref Powder powder)
    {
        /* at some reason sometimes there are "holes", delete this if you know how to fix that holes other way.
        immutable auto position = positions.getComponent(entity);
        immutable int[2] belowPosition = [position.xy[0] + Gravity.direction[0], position.xy[1] + Gravity.direction[1]];
        if(!globalMap.getAt(belowPosition).hasComponent!Particle)
        {
            return;
        }*/

        auto movable = movables.getComponent(entity);
        if(movable.isFalling) return;
        /*
               -1 0 1
            -1 [][][]
             0 []xx[]
             1 [][][]
        */
        immutable VelocityScalar[2][2][GravityDirection] biases = 
        [
            GravityDirection.none: [[0, 0], [0, 0]],
            GravityDirection.down: [[1, 1], [-1, 1]],
            GravityDirection.left: [[-1, -1], [-1, 1]],
            GravityDirection.right: [[1, -1], [1, 1]],
            GravityDirection.up: [[-1, -1], [1, -1]]
        ];

        // Every odd frame fall to one side and every even to the other
        movable.velocity = biases[Gravity.direction][fallDirection & 1];
    }
}

public class AdhesionSystem : System!Adhesion
{
    import std.random;

    private ComponentPool!Adhesion adhesions;
    private ComponentPool!Movable movables;
    private ComponentPool!Position positions;
    private ComponentPool!Particle particles;

    public override void onCreated()
    {
        adhesions = currentWorld.getPoolOf!Adhesion();
        movables = currentWorld.getPoolOf!Movable();
        positions = currentWorld.getPoolOf!Position();
        particles = currentWorld.getPoolOf!Particle();
    }

    protected override void onUpdated()
    {
        import powders.particle.loading : airTypeId;
        auto data = adhesions.getComponents();

        foreach(i, adhesion; data)
        {
            Entity entity = adhesions.dense2Entity(currentWorld, i);
            ref Movable movable = movables.getComponent(entity);
            if(movables.getComponent(entity).isFalling) return;    

            immutable auto position = positions.getComponent(entity);
            immutable int[2] belowPosition = [position.xy[0] + Gravity.direction[0], position.xy[1] + Gravity.direction[1]];

            // at some reason sometimes there are "holes", delete this if you know how to fix that holes other way.
            if(particles.getComponent(globalMap.getAt(belowPosition)).typeId == airTypeId)
            {
                return;
            }

            immutable VelocityScalar[2][2][GravityDirection] direction2Biases = 
            [
                GravityDirection.none: [[0, 0], [0, 0]],
                GravityDirection.down: [[-1, 0], [1, 0]],
                GravityDirection.left: [[0, -1], [0, 1]],
                GravityDirection.right: [[-1, 0], [1, 0]],
                GravityDirection.up: [[-1, 0], [1, 0]]
            ];

            VelocityScalar[2][2] resultBiases;

            if(uniform01() >= adhesion.adhesion)
            {
                resultBiases = direction2Biases[Gravity.direction];
            }
            else
            {
                resultBiases = [0, 0];
            }

            movable.velocity = resultBiases[uniform(0, 2)];
        }
    }
}

public class CombineSystem : System!Combine
{
    private ComponentPool!Position positions;
    private ComponentPool!Particle particles;
    private ComponentPool!Combine combines;

    public override void onCreated()
    {
        positions = currentWorld.getPoolOf!Position;
        particles = currentWorld.getPoolOf!Particle;
        combines = currentWorld.getPoolOf!Combine;
    }

    protected override void onUpdated()
    {
        import powders.particle.loading;
        import powders.particle.building;
        auto data = combines.getComponents();

        foreach(i, combine; data)
        {
            Entity self = combines.dense2Entity(currentWorld, i);
            Position position = positions.getComponent(self);

            auto neighbors = globalMap.getNeighborsAt(position.xy);

            foreach (row; neighbors)
            {
                foreach(entity; row)
                {
                    if(!particles.hasComponent(entity)) continue;
                    if(entity == self) continue;

                    immutable auto entityId = particles.getComponent(entity).typeId;

                    if(combine.otherId == entityId)
                    {
                        auto serializedResult = globalTypesDictionary[combine.resultId];
                        destroyParticle(self);
                        destroyParticle(entity);
                        buildParticle(self, serializedResult);
                        return;
                    }        
                }
            }
        }
    }
}

public class GasSystem : System!Gas
{
    private ComponentPool!Movable movables;
    private ComponentPool!Gas gases;

    public override void onCreated()
    {
        movables = currentWorld.getPoolOf!Movable;
        gases = currentWorld.getPoolOf!Gas;
    }
    
    protected override void onUpdated()
    {
        import std.random;

        auto data = gases.getComponents();

        immutable VelocityScalar[2][8] moveDirections = 
        [
            [-1, -1],
            [-1, 0],
            [-1, 1],
            [0, -1],
            [0, 1],
            [1, -1],
            [1, 0],
            [1, 1]
        ];

        foreach(i, gas; data)
        {
            Entity entity = gases.dense2Entity(currentWorld, i);
            ref Movable movable = movables.getComponent(entity);
            movable.velocity = moveDirections[uniform(0, 8)];
        }
    }
}