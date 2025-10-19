/// The module, in witch described all components and sistems
module powders.particle.basics;

import kernel.ecs;
import powders.map;
import powders.particle.register;
import powders.io;

alias ParticleId = char[Particle.idSize];

/// Component, that has every particle
@Component(Particle.stringof) public struct Particle
{
    mixin MakeJsonizable;

public:
    enum idSize = 16;
    /// The id of particle's type. Needed for creating/deleting etc.
    ParticleId typeId;
}

@Component(Temperature.stringof) public struct Temperature
{
    mixin MakeJsonizable;

public:
    /// Temperature of the particle (Celsius)
    @JsonizeField double value = 0;
}

public enum MoveDirection : byte
{
    none = 0,
    negative = -1,
    positive = 1
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
@Component(Gravity.stringof) public struct Gravity
{
    mixin MakeJsonizable;

public:
    static GravityDirection direction = GravityDirection.down;
    static float gravity = 9.81;
    /// Particle's mass
    @JsonizeField float mass = 1;
}

/// Component that says that this entity can move (and fall) like sand
@Component(Powder.stringof) public struct Powder
{
    mixin MakeJsonizable;

public:
    static float maxVelocity = 16;
    /// Current velocity of the particle [x, y] in cells per update
    float[2] velocity = [0, 0];
}

/// A component that indicates slip particles
@Component(Adhesion.stringof) public struct Adhesion
{
    mixin MakeJsonizable;

public:
    /// The slipperiness of particle in range 0..1
    @JsonizeField float adhesion = 1;
    /// Can the particle slip, or not?
    bool isActive;
}

/// A particle, that can turn into `result` when hits `other`
@Component(Combine.stringof) public struct Combine
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

public class PowderSystem : MapEntitySystem!Powder
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

public class GravitySystem : MapEntitySystem!Gravity
{
    protected override void updateComponent(Entity entity, ref Gravity gravity)
    {
        if(entity.hasComponent!Powder())
        {
            auto sand = entity.getComponent!Powder().value;
            sand.velocity[] += Gravity.direction[] * gravity.gravity * gravity.mass;
        }
    }
}

public class ChangeGravitySystem : BaseSystem
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
        else if (Input.isKeyDown(Keys.e))
        {
            Gravity.direction = GravityDirection.none;
        }
    }
}

public class AdhesionSystem : MapEntitySystem!Adhesion
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

        if(adhesion.adhesion == 0)
        {
            direction2Biases = direction2LeftRightBiases;
        }
        else if(adhesion.adhesion == 1)
        {
            direction2Biases = direction2DiagonalBiases;    
        }
        else if(uniform01() < adhesion.adhesion)
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

public class CombineSystem : MapEntitySystem!Combine
{
    protected override void updateComponent(Entity self, ref Combine combine)
    {
        import powders.particle.building;
        import powders.particle.register;
        import powders.particle.loading;

        auto position = self.getComponent!Position().value.xy;

        auto neighbors = globalMap.getNeighborsAt(position);

        foreach (row; neighbors)
        {
            foreach(entity; row)
            {
                if(!entity.hasComponent!Particle) continue;
                if(entity == self) continue;

                auto entityId = entity.getComponent!Particle().value.typeId;

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