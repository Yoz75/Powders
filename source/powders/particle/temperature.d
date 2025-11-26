module powders.particle.temperature;

import kernel.ecs;
import powders.io;
import powders.particle.register;
import powders.particle.basics;
import powders.map;

@Component(OnDestroyAction.setInit) public struct Temperature
{
    mixin MakeJsonizable;

public:
    /// The least fractional part of temperature
    enum double threshold = 0.01;

    enum double min = -273.15;
    enum double max = 100_000;

    enum double maxCondictivity = 2200;
    enum double minConductivity = 0;
    enum double defaultConductivity = 1500;

    /// Scale of conductivity normalisation
    enum conductivityScale = 250;

    enum double airHeatCapacity = 1005;
    enum double defaultTemperature = 25;

    /// The heat capacity. 
    /// Indicates how much a substance will "pull the resulting temperature onto itself" during heat exchange
    double heatCapacity = airHeatCapacity;

    /// How fast particle changes it's temperature.
    double transferCoefficient = 1;

    /// Temperature of a particle in degrees Celsius
    double value = defaultTemperature; 

    @JsonizeField this(double value, double heatCapacity, double thermalConductivity = defaultConductivity)
    {
        import std.math;
        this.value = value;
        this.heatCapacity = heatCapacity;

        // Logarithmic compression because we want both water (0.603) and diamonds (2200) would had
        // at least a little similar transfer coefficients
        transferCoefficient = (log(1 + conductivityScale * thermalConductivity)) / 
         (log(conductivityScale * maxCondictivity));
    }
}

/// A Kostyl, that's needed to increase or decrease temperature
public @Component(OnDestroyAction.destroy) struct DeltaTemperature
{
    mixin MakeJsonizable;
public:

    @JsonizeField double delta;
}


import kernel.todo;
mixin TODO!("Currently TemperatureSystem is broken when process ambient heat, fix later!");
public class TemperatureSystem : MapEntitySystem!Temperature
{
    public void delegate(Entity entity)[] onTemperatureChanged;

    /// Cache for temperature components because getComponent is slow
    private Temperature*[] temperatureCache;
    private Position*[] positionCache;

    private int[2] mapResolution;

    /// Mark that entity was updated and it's chunk must be recomputed

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
        markDirty(entity);
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Temperature temperature)
    {
        import std.math;
        import std.algorithm.comparison : clamp;
        import std.traits : EnumMembers;

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
        
        int[2] selfPosition = positionCache[entity.id].xy;
        int[2] neighborPosition;
        int[2] neighborChunkIndex;
        Entity neighborEntity;

        bool isValidNeighbor, wasAnyTransfer;
        Temperature* neighborTemperature;
        double resultTemperature = 0, selfDelta = 0, neighborDelta = 0;

        immutable bool isValidParticle = entity.hasComponent!Particle;
        
        static foreach(bias; EnumMembers!NeighborBiases)
        {
            neighborPosition[] = selfPosition[] + bias[];
            neighborEntity = globalMap.getAt(neighborPosition);
            neighborTemperature = &neighborEntity.getComponent!Temperature();
    
            isValidNeighbor = neighborEntity.hasComponent!Particle();

            wasAnyTransfer |= isValidNeighbor & (temperature.value != neighborTemperature.value);

            resultTemperature = (temperature.heatCapacity * temperature.value + 
            neighborTemperature.heatCapacity * neighborTemperature.value) / 
            (temperature.heatCapacity + neighborTemperature.heatCapacity);

            selfDelta = (resultTemperature - temperature.value) * temperature.transferCoefficient;
            neighborDelta = (resultTemperature - neighborTemperature.value) * neighborTemperature.transferCoefficient;

            selfDelta = selfDelta.quantize(Temperature.threshold);
            neighborDelta = neighborDelta.quantize(Temperature.threshold);

            temperature.value += isValidNeighbor & isValidParticle ? selfDelta : 0;
            neighborTemperature.value += isValidNeighbor & isValidParticle ? neighborDelta : 0;
        }

        if(!wasAnyTransfer)
        {
            chunk.state = ChunkState.clean;
            return;
        }
        else
        {            
            chunk.state = ChunkState.dirty;

            // We return here, but not at start because now program can mark unchanged chunks as clean
            if(!entity.hasComponent!Particle) return; 

            static foreach(bias; EnumMembers!NeighborBiases)
            {
                neighborPosition[] = selfPosition[] + bias[];

                neighborPosition[0] = neighborPosition[0] - cast(int)(neighborPosition[0] >= mapResolution[0]);
                neighborPosition[1] = neighborPosition[1] - cast(int)(neighborPosition[1] >= mapResolution[1]);

                neighborChunkIndex = Chunk.world2ChunkIndex(neighborPosition);
                chunks[neighborChunkIndex[1]][neighborChunkIndex[0]].state = ChunkState.dirty;
            }            

            foreach(action; onTemperatureChanged)
            {
                action(entity);
            }
        }
        
        temperature.value = temperature.value.quantize(Temperature.threshold);
        temperature.value = temperature.value.clamp(Temperature.min, Temperature.max);
    }
}

public class DeltaTemperatureSystem : MapEntitySystem!DeltaTemperature
{
    protected override void onAdd(Entity entity)
    {
        if(!entity.hasComponent!Particle) return;
        ref DeltaTemperature delta = entity.getComponent!DeltaTemperature();
        ref Temperature temperature = entity.getComponent!Temperature();

        temperature.value += delta.delta;

        (cast(TemperatureSystem) TemperatureSystem.instance).markDirty(entity);
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref DeltaTemperature)
    {
        //nothing;
    }
}