/// The module, in witch described all components and sistems
module powders.particle.basics;

import kernel.ecs;
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

public class MovableSystem : MapEntitySystem!Movable
{
    /// Calls when `self` moved and swapped with `other`
    public void delegate(Entity self, Entity other)[] onMoved;

    public override void onCreated()
    {
        onMoved ~= (Entity self, Entity other) 
        {
            (cast(RenderableSystem) RenderableSystem.instance).markDirty(self);
            (cast(RenderableSystem) RenderableSystem.instance).markDirty(other);
        };
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Movable movable)
    {
        import std.math : round;
        import std.algorithm : clamp;

        movable.isFalling = true;
        auto currentPosition = entity.getComponent!Position().xy;

        if (movable.velocity[0] == 0 && movable.velocity[1] == 0)
            return;

        movable.velocity[0] = movable.velocity[0].clamp(-Movable.maxVelocity, Movable.maxVelocity);
        movable.velocity[1] = movable.velocity[1].clamp(-Movable.maxVelocity, Movable.maxVelocity);

        (cast(PowderSystem) PowderSystem.instance).markUpdated(entity);
        (cast(AdhesionSystem) AdhesionSystem.instance).markUpdated(entity);
        

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

        immutable Entity other = globalMap.getAt(finalPosition);

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

            if (globalMap.getAt(checkPos).hasComponent!Particle())
                break;

            lastFree = checkPos;
        }

        return lastFree;
    }
}

public class GravitySystem : System!Gravity
{
    import kernel.simulation;

    protected override void onUpdated()
    {
        auto ref data = ComponentPool!Movable.instance.data[Simulation.currentWorld.id];

        foreach(i, ref movable; data)
        {
            Entity entity = Entity(Simulation.currentWorld, i);

            if(entity.hasComponent!Gravity())
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

public class PowderSystem : MapEntitySystem!Powder
{
    private void markUpdated(Entity entity)
    {
        immutable int[2] position = entity.getComponent!Position().xy;
        immutable int[2] chunkIndex = Chunk.world2ChunkIndex(position);

        chunks[chunkIndex[1]][chunkIndex[0]].makeDirty();
    }

    protected override void onAdd(Entity entity)
    {
        markUpdated(entity);
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Powder powder)
    {
        static uint fallDirection;
        fallDirection++;

        chunk.makeClean();
        if(!entity.hasComponent!Movable())
        {
            throw new Exception("Powder component can be only on Movable particles!");
        }

        immutable auto position = entity.getComponent!Position();
        immutable int[2] belowPosition = [position.xy[0] + Gravity.direction[0], position.xy[1] + Gravity.direction[1]];

        // at some reason sometimes there are "holes", delete this if you know how to fix that holes other way.
        if(!globalMap.getAt(belowPosition).hasComponent!Particle)
        {
            return;
        }

        if(entity.getComponent!Movable().isFalling) return;

        chunk.makeDirty();

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
        entity.getComponent!Movable.velocity = biases[Gravity.direction][fallDirection & 1];
    }
}

public class AdhesionSystem : MapEntitySystem!Adhesion
{
    import std.random;

    private void markUpdated(Entity entity)
    {
        immutable int[2] position = entity.getComponent!Position().xy;
        immutable int[2] chunkIndex = Chunk.world2ChunkIndex(position);

        chunks[chunkIndex[1]][chunkIndex[0]].makeDirty();
    }


    protected override void onAdd(Entity entity)
    {
        markUpdated(entity);
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Adhesion adhesion)
    {
        chunk.makeClean();
        if(!entity.hasComponent!Movable())
        {
            throw new Exception("Adhesion component can be only on Movable particles!");
        }
            
        immutable auto position = entity.getComponent!Position();
        immutable int[2] belowPosition = [position.xy[0] + Gravity.direction[0], position.xy[1] + Gravity.direction[1]];

        // at some reason sometimes there are "holes", delete this if you know how to fix that holes other way.
        if(!globalMap.getAt(belowPosition).hasComponent!Particle)
        {
            return;
        }

        if(entity.getComponent!Movable().isFalling) return;        

        chunk.makeDirty();
        /*
               -1 0 1
            -1 [][][]
             0 []xx[]
             1 [][][]
        */
        // should be int[2][2], but float[2][2] because of boilerplate
        enum float[2][2][GravityDirection] direction2Biases = 
        [
            GravityDirection.none: [[0, 0], [0, 0]],
            GravityDirection.down: [[-1, 0], [1, 0]],
            GravityDirection.left: [[0, -1], [0, 1]],
            GravityDirection.right: [[-1, 0], [1, 0]],
            GravityDirection.up: [[-1, 0], [1, 0]]
        ];


        float[2][2] resultBiases;

        if(uniform01() >= adhesion.adhesion)
        {
            resultBiases = direction2Biases[Gravity.direction];
        }
        else
        {
            resultBiases = [0, 0];
        }

        entity.getComponent!Movable().velocity = resultBiases[uniform(0, 2)];
    }
}

public class CombineSystem : MapEntitySystem!Combine
{
    protected override void updateComponent(Entity self, ref Chunk chunk, ref Combine combine)
    {
        import powders.particle.building;
        import powders.particle.register;
        import powders.particle.loading;

        auto position = self.getComponent!Position().xy;

        auto neighbors = globalMap.getNeighborsAt(position);

        foreach (row; neighbors)
        {
            foreach(entity; row)
            {
                if(!entity.hasComponent!Particle) continue;
                if(entity == self) continue;

                immutable auto entityId = entity.getComponent!Particle().typeId;

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

