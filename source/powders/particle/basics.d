/// The module, in witch described all components and sistems
module powders.particle.basics;

import kernel.ecs;
import powders.map;
import powders.particle.register;
import powders.io;

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

@Component(OnDestroyAction.setInit) public struct Temperature
{
    mixin MakeJsonizable;

public:
    /// The least fractional part of temperature
    enum double threshold = 0.01;
    enum double min = -273.15;
    enum double max = 100_000;

    /// Temperature of the particle (Celsius)
    @JsonizeField double value = 25;
    /// Coefficient of heat transfer's speed. Calculated as heat capacity of air / heat capacity of material.
    @JsonizeField double heatTransfer = 1;
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
@Component(OnDestroyAction.destroy) public struct Gravity
{
    mixin MakeJsonizable;

public:
    static GravityDirection direction = GravityDirection.down;
    static float gravity = 9.81;
    /// Particle's mass
    @JsonizeField float mass = 1;
}

/// Component that says that this entity can move (and fall) like sand
@Component(OnDestroyAction.destroy) public struct Powder
{
    mixin MakeJsonizable;

public:
    static float maxVelocity = 512;
    /// Current velocity of the particle [x, y] in cells per update
    float[2] velocity = [0, 0];
}

/// A component that indicates slip particles
@Component(OnDestroyAction.destroy) public struct Adhesion
{
    mixin MakeJsonizable;

public:
    /// The slipperiness of particle in range 0..1
    @JsonizeField float adhesion = 1;
    /// Can the particle slip, or not?
    bool isActive;
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

public class PowderSystem : MapEntitySystem!Powder
{
    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Powder powder)
    {
        import std.math : round;
        import std.algorithm : clamp;

        bool hasAdhesion = entity.hasComponent!Adhesion();
        ref Adhesion adhesion = entity.getComponent!Adhesion();

        if(hasAdhesion) adhesion.isActive = false;

        auto currentPosition = entity.getComponent!Position().xy;

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
            if(hasAdhesion) adhesion.isActive = true;
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
    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Gravity gravity)
    {
        if(entity.hasComponent!Powder())
        {
            ref Powder powder = entity.getComponent!Powder();
            powder.velocity[] += Gravity.direction[] * gravity.gravity * gravity.mass;
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
    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Adhesion adhesion)
    {
        import std.random;

        assert(entity.hasComponent!Powder(), "Adhesion component can be only on Powder particles!");
            
        if(!adhesion.isActive) return;
        
        auto position = entity.getComponent!Position();

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

        entity.getComponent!Powder().velocity[] = 
        direction2Biases[Gravity.direction][uniform(0, 2)][];
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

                auto entityId = entity.getComponent!Particle().typeId;

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

import kernel.todo;
mixin TODO!("Currently TemperatureSystem is broken when process ambient heat, fix later!");
public class TemperatureSystem : MapEntitySystem!Temperature
{
    /// Cache for temperature components because getComponent is slow
    private Temperature*[] temperatureCache;
    private Position*[] positionCache;
    private int[2] mapResolution;

    public override void onCreated()
    {
        mapResolution = globalMap.resolution();

        ComponentPool!Temperature.instance.reserve(currentWorld, mapResolution[0] * mapResolution[1]);
        temperatureCache.reserve(mapResolution[0] * mapResolution[1]);
        positionCache.reserve(mapResolution[0] * mapResolution[1]);

        foreach(entity; globalMap)
        {
            temperatureCache ~= &entity.getComponent!Temperature();
            positionCache ~= &entity.getComponent!Position();
        }
    }

    protected override void onAdd(Entity entity)
    {
        immutable int[2] position = entity.getComponent!Position().xy;
        immutable int[2] chunkIndex = Chunk.world2ChunkIndex(position);

        chunks[chunkIndex[1]][chunkIndex[0]].state = ChunkState.dirty;
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Temperature temperature)
    {
        import std.math;
        import std.algorithm.comparison : clamp;
        import std.traits : EnumMembers;

        enum cellsCount = 9;

        enum NeighborBiases : int[2]
        {
            topLeft = [-1, 1],
            top = [0, 1],
            topRight = [1, 1],
            left = [-1, 0],
            right = [1, 0],
            bottomLeft = [-1, -1],
            bottom = [0, -1],
            bottomRight = [1, -1],
            self = [0, 0]
        }
        
        double totalTemperature = 0;
        
        int[2] selfPosition = positionCache[entity.id].xy;
        int[2] neighborPosition;
        int[2] neighborChunkIndex;
        Entity neighborEntity;

        static foreach(bias; EnumMembers!NeighborBiases)
        {
            neighborPosition[] = selfPosition[] + bias[];

            neighborPosition[0] = neighborPosition[0] - cast(int)(1 * neighborPosition[0] >= mapResolution[0]);
            neighborPosition[1] = neighborPosition[1] - cast(int)(1 * neighborPosition[1] >= mapResolution[1]);            
            
            neighborEntity = globalMap.getAt(neighborPosition);

            totalTemperature += temperatureCache[neighborEntity.id].value;
        }

        double delta = totalTemperature / cellsCount;

        double resultDelta = (delta - temperature.value) * temperature.heatTransfer;
        resultDelta = resultDelta.quantize(Temperature.threshold);

        if(resultDelta == 0)
        {
            chunk.state = ChunkState.clean;
            return;
        }
        else
        {
            chunk.state = ChunkState.dirty;

            static foreach(bias; EnumMembers!NeighborBiases)
            {
                neighborPosition[] = selfPosition[] + bias[];

                neighborPosition[0] = neighborPosition[0] - cast(int)(1 * neighborPosition[0] >= mapResolution[0]);
                neighborPosition[1] = neighborPosition[1] - cast(int)(1 * neighborPosition[1] >= mapResolution[1]);

                neighborChunkIndex = Chunk.world2ChunkIndex(neighborPosition);
                chunks[neighborChunkIndex[1]][neighborChunkIndex[0]].state = ChunkState.dirty;
            }            
        }

        temperature.value += resultDelta;

        temperature.value = temperature.value.clamp(Temperature.min, Temperature.max);
        temperature.value = temperature.value.quantize(Temperature.threshold);
    }

    private void updateAirHeat()
    {

    }
}