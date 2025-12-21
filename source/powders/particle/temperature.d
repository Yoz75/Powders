module powders.particle.temperature;

import kernel.ecs;
import powders.io;
import powders.particle.register;
import powders.particle.basics;
import powders.map;

// Number type used for heat and temperature
alias TemperatureScalar = double;

@Component(OnDestroyAction.setInit) public struct Temperature
{
    mixin MakeJsonizable;

public:
    /// The least fractional part of temperature
    enum TemperatureScalar threshold = 0.01;

    enum TemperatureScalar min = -273.15;
    enum TemperatureScalar max = 100_000;

    enum TemperatureScalar maxCondictivity = 2200;
    enum TemperatureScalar minConductivity = 0;
    enum TemperatureScalar defaultConductivity = 1500;

    /// Scale of conductivity normalisation
    enum conductivityScale = 250;

    enum TemperatureScalar airHeatCapacity = 1005;
    enum TemperatureScalar defaultTemperature = 25;

    /// The heat capacity. 
    /// Indicates how much a substance will "pull the resulting temperature onto itself" during heat exchange
    TemperatureScalar heatCapacity = airHeatCapacity;

    /// How fast particle changes it's temperature.
    TemperatureScalar transferCoefficient = 1;

    /// Temperature of a particle in degrees Celsius
    TemperatureScalar value = defaultTemperature; 

    @JsonizeField this(TemperatureScalar value, TemperatureScalar heatCapacity, 
    TemperatureScalar thermalConductivity = defaultConductivity)
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

    @JsonizeField TemperatureScalar delta;
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

        import powders.rendering;
        onTemperatureChanged ~= (Entity self) 
        {
            if(RenderModeSystem.instance.getCurrentRenderModeConverter() == &temperature2Color)
                (cast(RenderableSystem) RenderableSystem.instance).markDirty(self);
        };

        assert(RenderModeSystem.instance !is null, "Render mode system is not initialized but we add render mode!!!");
        RenderModeSystem.instance.addRenderMode(&temperature2Color, Keys.two);
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
        TemperatureScalar resultTemperature = 0, selfDelta = 0, neighborDelta = 0;

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

import davincilib.color;
public Color temperature2Color(Entity entity)
{
    import kernel.math;

    /// Maximal temperature, that rendered as a red color. Temperatures above this value are rendered as hot.
    enum minColdTemperature = Temperature.min;
    enum maxWarmTemperature = 100;
    enum maxVeryWarmTemperature = 1000;
    enum maxLittleHotTemperature = 2000;
    enum maxHotTemperature = 3000;
    enum maxVeryHotTemperature = 4000;
    enum maxTemperature = Temperature.max;

    enum coldColor = blue;
    enum zeroColor = black;
    enum warmColor = green;
    enum veryWarmColor = red;
    enum littleHotColor = Color(230, 200, 0);
    enum hotColor = Color(255, 255, 0);
    enum veryHotColor = white;
    enum maxColor = white;

    immutable auto temperature = entity.getComponent!Temperature().value;
    Color color;
    
    if(temperature < 0)
    {
        immutable float normalized = remap!TemperatureScalar(temperature, 0, minColdTemperature, 0, 1);
        color = lerp(zeroColor, coldColor, normalized);
    }
    if(temperature >= 0)
    {
        if(temperature < maxWarmTemperature)
        {
            immutable float normalized = remap!TemperatureScalar(temperature, 0, maxWarmTemperature, 0, 1);
            color = lerp(zeroColor, warmColor, normalized);
        }
        else if(temperature < maxVeryWarmTemperature)
        {
            immutable float normalized =
                remap!TemperatureScalar(temperature, maxWarmTemperature, maxVeryWarmTemperature, 0, 1);

            color = lerp(warmColor, veryWarmColor, normalized);
        }
        else if(temperature < maxLittleHotTemperature)
        {
            immutable float normalized =
                remap!TemperatureScalar(temperature, maxVeryWarmTemperature, maxLittleHotTemperature, 0, 1);

            color = lerp(veryWarmColor, littleHotColor, normalized);
        }
        else if(temperature < maxHotTemperature)
        {
            immutable float normalized =
                remap!TemperatureScalar(temperature, maxLittleHotTemperature, maxHotTemperature, 0, 1);

            color = lerp(littleHotColor, hotColor, normalized);
        }
        else if(temperature < maxVeryHotTemperature)
        {
            immutable float normalized = 
                remap!TemperatureScalar(temperature, maxHotTemperature, maxVeryHotTemperature, 0, 1);

            color = lerp(hotColor, veryHotColor, normalized);
        }
        else color = maxColor;
    }

    return color;
}

import std.traits : isNumeric;

public pure Color lerp(T)(immutable Color from, immutable Color to, immutable T lerpFactor) if (isNumeric!T)
{
    Color result;

    result.r = cast(ubyte)(from.r + (to.r - from.r) * lerpFactor);
    result.g = cast(ubyte)(from.g + (to.g - from.g) * lerpFactor);
    result.b = cast(ubyte)(from.b + (to.b - from.b) * lerpFactor);
    result.a = cast(ubyte)(from.a + (to.a - from.a) * lerpFactor);

    return result;
}