/// The module, in witch described all components and sistems
module powders.particle.basics;

import kernel.todo;
import kernel.ecs;
import kernel.simulation;
import powders.map;
import powders.particle.register;
import powders.io;
import powders.rendering;

alias ParticleId = char[Particle.idSize];

/// Component, that has every particle
@Component(OnDestroyAction.destroy) public struct Particle
{
    mixin MakeJsonizable;

public:
    enum idSize = 16;
    /// The id of particle's type. Needed for creating/deleting etc.
    ParticleId typeId;
}

public enum GravityDirection : int[2]
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
    static float gravity = 9.81;
}

/// Component that says that this entity can move
@Component(OnDestroyAction.destroy) public struct Movable
{
    mixin MakeJsonizable;

public:
    bool isFalling;
    static float maxVelocity = 512;
    /// Current velocity of the particle [x, y] in cells per update
    float[2] velocity = [0, 0];
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
    ParticleId otherId;
    ParticleId resultId;

    @JsonizeField this(string other, string result)
    {
        foreach(i, char otherChar; other)
        {
            otherId[i] = otherChar;
        }

        foreach(i, char resultChar; result)
        {
            resultId[i] = resultChar;
        }
    }
}

public class MovableSystem : System!Movable
{
    /// Calls when `self` moved and swapped with `other`
    public void delegate(Entity self, Entity other)[] onMoved;

    private IComponentPool!Movable movablePool;
    private IComponentPool!Position positionPool;
    private IComponentPool!Particle particlePool;

    public override void onCreated()
    {
        movablePool = Simulation.currentWorld.getPoolOf!Movable();
        positionPool = Simulation.currentWorld.getPoolOf!Position();
        particlePool = Simulation.currentWorld.getPoolOf!Particle();
    }

    protected override void onUpdated()
    {
        import std.random;

        ComponentId[] movableIds = whereHas(movablePool, positionPool);
        ComponentId[] positionIds = whereHas(positionPool, movablePool);

        foreach(i, id; movableIds)
        {
            ref Movable movable = movablePool.getComponentWithId(id);
            ref Position position = positionPool.getComponentWithId(positionIds[i]);
            updateComponent(movable, position);
        }
    }

    pragma(inline, true)
    private void updateComponent(ref Movable movable, ref Position position)
    {
        import std.math : round;
        import std.algorithm : clamp;

        movable.isFalling = true;
        auto currentPosition = position.xy;

        if (movable.velocity[0] == 0 && movable.velocity[1] == 0)
            return;

        movable.velocity[0] = movable.velocity[0].clamp(-Movable.maxVelocity, Movable.maxVelocity);
        movable.velocity[1] = movable.velocity[1].clamp(-Movable.maxVelocity, Movable.maxVelocity);        

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

        Entity entity = globalMap.getAt(position.xy);
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
            int x = cast(int) (start[0] + stepX * i);
            int y = cast(int) (start[1] + stepY * i);
            int[2] checkPos = [x, y];

            if(particlePool.hasComponent(globalMap.getAt(checkPos).id))
                break;

            lastFree = checkPos;
        }

        return lastFree;
    }
}

public class GravitySystem : System!Gravity
{
    import kernel.simulation;

    private IComponentPool!Movable movablePool;
    private IComponentPool!Gravity gravityPool;

    public override void onCreated()
    {
        movablePool = Simulation.currentWorld.getPoolOf!Movable();
        gravityPool = Simulation.currentWorld.getPoolOf!Gravity();
    }

    protected override void onUpdated()
    {
        ComponentId[] movableIds = whereHas(movablePool, gravityPool);
        
        foreach(id; movableIds)
        {
            ref Movable movable = movablePool.getComponentWithId(id);
            movable.velocity[] += Gravity.direction[] * Gravity.gravity;
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
    private IComponentPool!Powder powderPool;
    private IComponentPool!Movable movablePool;
    private IComponentPool!Position positionPool;

    public override void onCreated()
    {
        powderPool = Simulation.currentWorld.getPoolOf!Powder();
        movablePool = Simulation.currentWorld.getPoolOf!Movable();
        positionPool = Simulation.currentWorld.getPoolOf!Position();
    }

    protected override void onUpdated()
    {
        mixin whereHasMany!(Powder, Movable, Position);
        mixin whereHasMany!(Movable, Powder, Position);
        mixin whereHasMany!(Position, Powder, Movable);

        ComponentId[] powderIds = whereHas(powderPool, movablePool, positionPool);
        ComponentId[] movableIds = whereHas(movablePool, powderPool, positionPool);
        ComponentId[] positionIds = whereHas(positionPool, powderPool, movablePool);

        foreach(i, id; powderIds)
        {
            ref Powder powder = powderPool.getComponentWithId(id);
            ref Movable movable = movablePool.getComponentWithId(movableIds[i]);
            ref Position position = positionPool.getComponentWithId(positionIds[i]);

            updateComponent(powder, movable, position, i);
        }
    }

    pragma(inline, true)
    private void updateComponent(ref Powder powder, ref Movable movable, ref Position position, Id entityId)
    {
        static uint fallDirection;
        fallDirection++;

        mixin TODO!"Fix this shit!";
        /* at some reason sometimes there are "holes", delete this if you know how to fix that holes other way.
        immutable int[2] belowPosition = [position.xy[0] + Gravity.direction[0], position.xy[1] + Gravity.direction[1]];
        if(!globalMap.getAt(belowPosition).hasComponent!Particle)
        {
            return;
        }*/

        if(movable.isFalling) return;

        /*
               -1 0 1
            -1 [][][]
             0 []xx[]
             1 [][][]
        */
        enum float[2][2][GravityDirection] biases = 
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
    private IComponentPool!Adhesion adhesionPool;
    private IComponentPool!Movable movablePool;

    private immutable float[2][2][GravityDirection] direction2Biases = 
        [
            GravityDirection.none: [[0, 0], [0, 0]],
            GravityDirection.down: [[-1, 0], [1, 0]],
            GravityDirection.left: [[0, -1], [0, 1]],
            GravityDirection.right: [[-1, 0], [1, 0]],
            GravityDirection.up: [[-1, 0], [1, 0]]
        ];

    import std.random;

    public override void onCreated()
    {
        adhesionPool = Simulation.currentWorld.getPoolOf!Adhesion();
        movablePool = Simulation.currentWorld.getPoolOf!Movable();
    }

    protected override void onUpdated()
    {
        ComponentId[] adhesionIds = whereHas!(Adhesion, Movable)(adhesionPool, movablePool);
        ComponentId[] movableIds = whereHas!(Movable, Adhesion)(movablePool, adhesionPool);

        foreach(i, id; adhesionIds)
        {
            ref Adhesion adhesion = adhesionPool.getComponentWithId(id);
            ref Movable movable = movablePool.getComponentWithId(movableIds[i]);
            updateComponent(adhesion, movable);
        }
    }

    private void updateComponent(ref Adhesion adhesion, ref Movable movable)
    {   
        import std.traits : EnumMembers;

        /*immutable int[2] belowPosition = [position.xy[0] + Gravity.direction[0], position.xy[1] + Gravity.direction[1]];
        immutable auto position = entity.getComponent!Position();

        // at some reason sometimes there are "holes", delete this if you know how to fix that holes other way.
        if(!globalMap.getAt(belowPosition).hasComponent!Particle)
        {
            return;
        }*/

        if(movable.isFalling) return;        

        /*
               -1 0 1
            -1 [][][]
             0 []xx[]
             1 [][][]
        */
        // should be int[2][2], but float[2][2] because of boilerplate

        float[2][2] resultBiases;

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

public class CombineSystem : System!Combine
{
    private IComponentPool!Combine combinePool;
    private IComponentPool!Particle particlePool;
    private IComponentPool!Position positionPool;

    public override void onCreated()
    {
        combinePool = Simulation.currentWorld.getPoolOf!Combine();
        particlePool = Simulation.currentWorld.getPoolOf!Particle();
        positionPool = Simulation.currentWorld.getPoolOf!Position();
    }

    protected override void onUpdated()
    {
        ComponentId[] combineIds = whereHas!(Combine, Particle)(combinePool, particlePool);
        ComponentId[] positionIds = whereHas!(Position, Combine)(positionPool, combinePool);
        ComponentId[] particleIds = whereHas!(Particle, Combine)(particlePool, combinePool);

        foreach(i, id; combineIds)
        {
            ref Combine combine = combinePool.getComponentWithId(id);
            ref Position position = positionPool.getComponentWithId(positionIds[i]);
            ref Particle particle = particlePool.getComponentWithId(particleIds[i]);

            updateComponent(combine, position, particle);
        }
    }

    pragma(inline, true)
    private void updateComponent(ref Combine combine, ref Position position, ref Particle particle)
    {
        import powders.particle.building;
        import powders.particle.register;
        import powders.particle.loading;

        auto self = globalMap.getAt(position.xy);
        auto neighbors = globalMap.getNeighborsAt(position.xy);

        foreach (row; neighbors)
        {
            foreach(entity; row)
            {
                if(!particlePool.hasComponent(entity.id)) continue;
                if(entity == self) continue;

                if(combine.otherId == particle.typeId)
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

