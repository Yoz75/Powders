module powders.particle.temperature;

import kernel.ecs;
import kernel.simulation;
import powders.io;
import powders.particle.register;
import powders.particle.basics;
import powders.map;
import powders.rendering;

// Number type used for heat and temperature
alias TemperatureScalar = float;

public pure TemperatureScalar conductivity2coefficient(TemperatureScalar conductivity, 
    TemperatureScalar scale, TemperatureScalar maxConductivity)
{
    import std.math;

    return(log(1 + scale * conductivity)) / (log(scale * maxConductivity));
}

@Component(OnDestroyAction.setInit) public struct Temperature
{
    mixin MakeJsonizable;

public:
    enum TemperatureScalar min = -273.15;
    enum TemperatureScalar max = 100_000;

    enum TemperatureScalar maxCondictivity = 2200;
    enum TemperatureScalar minConductivity = 0;
    enum TemperatureScalar defaultConductivity = conductivity2coefficient(0.024, conductivityScale, maxCondictivity);

    /// Scale of conductivity normalisation
    enum conductivityScale = 250;

    enum TemperatureScalar airHeatCapacity = 1005;
    enum TemperatureScalar defaultTemperature = 25;

    /// The heat capacity. 
    /// Indicates how much a substance will "pull the resulting temperature onto itself" during heat exchange
    TemperatureScalar heatCapacity = airHeatCapacity;

    /// How fast particle changes it's temperature.
    TemperatureScalar transferCoefficient = defaultConductivity;

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

public enum AgregateStates : ubyte
{
    solid,
    liquid,
    gas
}

public @Component(OnDestroyAction.destroy) struct AgregateState
{
    mixin MakeJsonizable;
public:
    ParticleId solid, melt, gas;
    TemperatureScalar meltingPoint = 0, boilingPoint = 0;
    AgregateStates state;

    @JsonizeField this(string solid, string melt, string gas, TemperatureScalar meltingPoint, TemperatureScalar boilingPoint)
    {
        this.solid = solid;
        this.melt = melt;
        this.gas = gas;

        this.meltingPoint = meltingPoint;
        this.boilingPoint = boilingPoint;
    }
}

import kernel.todo;
mixin TODO!("Currently TemperatureSystem is broken when process ambient heat, fix later!");
public class TemperatureSystem : System!Temperature
{
    private int[2] mapResolution;

    private IComputeShader temperatureShader;
    private IShaderBuffer valueInSSBO, valueOutSSBO;

    private Temperature[] valueInBuffer;
    private Temperature[] valueOutBuffer;

    private IEventComponentPool!Temperature temperaturePool;

    /// Mark that entity was updated and it's chunk must be recomputed

    public override void onCreated()
    {
        temperaturePool = Simulation.currentWorld.getPoolOf!Temperature;
        mapResolution = globalMap.resolution();

        assert(RenderModeSystem.instance !is null, "Render mode system is not initialized but we add render mode!!!");
        RenderModeSystem.instance.addRenderMode(&temperature2Color, Keys.two);

        temperatureShader = gameWindow.getNewUninitedComputeShader();
        temperatureShader.initMe(import("computeShaders/temperature.comp"));

        initSSBOs();

        auto resolutionUniform = temperatureShader.getUniform("resolution", UniformType.vector2i);
        
        resolutionUniform.setValue(mapResolution.ptr);
    }

    public void updateTemperatureOf(Id entityId)
    {
        immutable auto mapPos = Simulation.currentWorld.getPoolOf!Position().getComponent(entityId).xy;

        Temperature[1] resultBuffer;
        resultBuffer[0] = Simulation.currentWorld.getPoolOf!Temperature().getComponent(entityId);

        valueInSSBO.update(resultBuffer, cast(uint)((mapPos[0] + mapResolution[0] * mapPos[1]) * Temperature.sizeof));
    }

    protected override void onDestroyed()
    {
        valueInSSBO.free();
        valueOutSSBO.free();

        temperatureShader.free();
    }

    protected override void onAdd(IEventComponentPool!Temperature pool, Id entityId)
    {
        updateTemperatureOf(entityId);
    }

    protected override void onUpdated()
    {
        import powders.timecontrol;

        if(globalGameState != GameState.play)
        {
            foreach(entity; globalMap)
            {
                mixin TODO!"Add some mark component for updating map state";
            }

            return;
        }

        import kernel.simulation;
        import std.math;
        import std.algorithm.comparison : clamp;
        import std.traits : EnumMembers;

        temperatureShader.execute([mapResolution[0] / Map.chunkSize, mapResolution[1] / Map.chunkSize, 1]);
        valueOutSSBO.read(valueOutBuffer);

        Temperature[] temperatureData = temperaturePool.getComponents();

        foreach(i, ref temperature; temperatureData)
        {
            temperature = valueOutBuffer[i];
        }

        auto temp = valueInSSBO;
        valueInSSBO = valueOutSSBO;
        valueOutSSBO = temp;

        temperatureShader.detachBuffer(1);
        temperatureShader.detachBuffer(2);

        temperatureShader.attachBuffer(valueInSSBO, 1);
        temperatureShader.attachBuffer(valueOutSSBO, 2);
    }

    pragma(inline, true)
    private void initSSBOs()
    {
        valueInSSBO = gameWindow.getNewUninitedBuffer();
        valueOutSSBO = gameWindow.getNewUninitedBuffer();

        immutable auto mapByteSize = uint(Temperature.sizeof) * mapResolution[0] * mapResolution[1];
        immutable auto chunkOutSize = 
            uint(uint.sizeof) * mapResolution[0] * mapResolution[1] / (Map.chunkSize * Map.chunkSize);

        valueInBuffer = new Temperature[mapResolution[0] * mapResolution[1]];
        valueInBuffer[] = Temperature.init; // bruh at some reasone default values in the array are not Temperature.init

        valueOutBuffer = new Temperature[mapResolution[0] * mapResolution[1]];
        
        valueInSSBO.initMe(mapByteSize, valueInBuffer.ptr, BufferUsageHint.StreamCPU2GPU);
        valueOutSSBO.initMe(mapByteSize, null, BufferUsageHint.StreamGPU2CPU);

        temperatureShader.attachBuffer(valueInSSBO, 1);
        temperatureShader.attachBuffer(valueOutSSBO, 2);
    }
}

public class DeltaTemperatureSystem : System!DeltaTemperature
{
    private IComponentPool!DeltaTemperature deltaPool;
    private IComponentPool!Temperature temperaturePool;

    public override void onCreated()
    {
        deltaPool = Simulation.currentWorld.getPoolOf!DeltaTemperature();
        temperaturePool = Simulation.currentWorld.getPoolOf!Temperature();
    }

    protected override void onAdd(IEventComponentPool!DeltaTemperature pool, Id entityId)
    {
        DeltaTemperature delta = deltaPool.getComponent(entityId);
        ref Temperature temperature = temperaturePool.getComponent(entityId);

        temperature.value += delta.delta;

        (cast(TemperatureSystem) TemperatureSystem.instance).updateTemperatureOf(entityId);
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

    enum coldColor = blue;
    enum zeroColor = black;
    enum warmColor = green;
    enum veryWarmColor = red;
    enum littleHotColor = Color(230, 200, 0);
    enum hotColor = Color(255, 255, 0);
    enum veryHotColor = white;
    enum maxColor = white;

    immutable auto temperature = Simulation.currentWorld.getPoolOf!Temperature().getComponent(entity.id).value;
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

mixin TODO!("Uncomment this and fix after reworking kernel ecs system!");
/*
private class AgregateStateSystem : System!AgregateState
{
    protected override void onUpdated()
    {
        auto data = ComponentPool!AgregateState.instance.data[Simulation.currentWorld.id];
        auto temperatureData = ComponentPool!Temperature.instance.data[Simulation.currentWorld.id];

        foreach(i, ref agregateState; data)
        {
            Entity self = Entity(Simulation.currentWorld, i);
            if(!self.hasComponent!AgregateState)

            if(temperatureData[i].value > agregateState.meltingPoint && agregateState.state == AgregateStates.solid)
            {
            }
        }
    }
}*/