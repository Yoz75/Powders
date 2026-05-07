module powders.particle.temperature;

import kernel.ecs;
import powders.io;
import powders.particle.register;
import powders.particle.basics;
import powders.map;
import powders.rendering;

// Number type used for heat and temperature
alias TemperatureScalar = float;

package Temperature2ColorConverter temperature2ColorConverter;

public pure TemperatureScalar conductivity2coefficient(TemperatureScalar conductivity, 
    TemperatureScalar scale, TemperatureScalar maxConductivity)
{
    import std.math;

    return(log(1 + scale * conductivity)) / (log(scale * maxConductivity));
}

@Component(OnDestroyAction.setInit, OnAddAction.recreate) public struct Temperature
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
    @JsonizeField TemperatureScalar boostMultiplier = 1;
}

/// Something that turns into something other when temperature more than critical point
public @Component(OnDestroyAction.destroy) struct Meltable
{
    mixin MakeJsonizable;
public:
    @JsonizeField string resultId;
    @JsonizeField TemperatureScalar criticalTemperature;
}

/// Something that turns into something other when temperature less than critical point
public @Component(OnDestroyAction.destroy) struct Solidable
{
    mixin MakeJsonizable;
public:
    @JsonizeField string resultId;
    @JsonizeField TemperatureScalar criticalTemperature;
}

public @Component(OnDestroyAction.destroy) struct Convection
{
    mixin MakeJsonizable;
public:
}

import kernel.todo;
mixin TODO!("Currently TemperatureSystem is broken when process ambient heat, fix later!");
public class TemperatureSystem : System!Temperature
{
    public void delegate(Entity entity)[] onTemperatureChanged;

    private int[2] mapResolution;

    private IComputeShader temperatureShader;
    private IShaderBuffer valueInSSBO, valueOutSSBO;

    private Temperature[] valueInBuffer;
    private Temperature[] valueOutBuffer;

    private ComponentPool!UpdateRenderableMarker markers;
    private ComponentPool!Position positions;
    private ComponentPool!Temperature temperatures;

    public override void onCreated()
    {
        mapResolution = globalMap.resolution();

        markers = currentWorld.getPoolOf!UpdateRenderableMarker;
        positions = currentWorld.getPoolOf!Position;
        temperatures = currentWorld.getPoolOf!Temperature;

        onTemperatureChanged ~= (Entity self) 
        {
            if(RenderModeSystem.instance.getCurrentRenderModeConverter() == 
             &temperature2ColorConverter.temperature2Color)
            {
                markers.addComponent(self);
            }
        };

        assert(RenderModeSystem.instance !is null, "Render mode system is not initialized but we add render mode!!!");
        RenderModeSystem.instance.addRenderMode(&temperature2ColorConverter.temperature2Color, Keys.two);

        temperatureShader = gameWindow.getNewUninitedComputeShader();
        temperatureShader.initMe(import("computeShaders/temperature.comp"));

        initSSBOs();

        auto resolutionUniform = temperatureShader.getUniform("resolution", UniformType.vector2i);
        
        resolutionUniform.setValue(mapResolution.ptr);
    }

    public void updateTemperatureOf(Entity entity)
    {
        immutable auto mapPos = positions.getComponent(entity).xy;

        Temperature[1] resultBuffer;
        resultBuffer[0] = temperatures.getComponent(entity);

        valueInSSBO.update(resultBuffer, cast(uint)((mapPos[0] + mapResolution[0] * mapPos[1]) * Temperature.sizeof));
    }

    protected override void onDestroyed()
    {
        valueInSSBO.free();
        valueOutSSBO.free();

        temperatureShader.free();
    }

    protected override void onAdd(Entity entity)
    {
        updateTemperatureOf(entity);
        foreach(action; onTemperatureChanged)
        {
            action(entity);
        }
    }

    protected override void onUpdated()
    {
        import powders.timecontrol;

        if(globalGameState != GameState.play)
        {
            foreach(entity; globalMap)
            {
                foreach(action; onTemperatureChanged)
                {
                    action(entity);
                }
            }

            return;
        }

        import kernel.simulation;
        import std.math;
        import std.algorithm.comparison : clamp;
        import std.traits : EnumMembers;

        temperatureShader.execute([mapResolution[0] / Map.chunkSize, mapResolution[1] / Map.chunkSize, 1]);
        valueOutSSBO.read(valueOutBuffer);

        foreach(x, y, entity; globalMap)
        {
            auto ref temperature = temperatures.getComponent(entity);

            immutable bufferIndex = x + mapResolution[0] * y;
            valueOutBuffer[bufferIndex].value =
             clamp(valueOutBuffer[bufferIndex].value, Temperature.min, Temperature.max);

            temperature = valueOutBuffer[bufferIndex];
            foreach(action; onTemperatureChanged)
            {
                action(entity);
            }
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
        valueInBuffer = new Temperature[mapResolution[0] * mapResolution[1]];
        valueInBuffer[] = Temperature.init; // bruh at some reasone default values in the array are not Temperature.init

        valueOutBuffer = new Temperature[mapResolution[0] * mapResolution[1]];
        
        valueInSSBO.initMe(mapByteSize, valueInBuffer.ptr, BufferUsageHint.StreamCPU2GPU);
        valueOutSSBO.initMe(mapByteSize, null, BufferUsageHint.StreamGPU2CPU);

        temperatureShader.attachBuffer(valueInSSBO, 1);
        temperatureShader.attachBuffer(valueOutSSBO, 2);
    }
}

public class DeltaTemperatureSystem : MapEntitySystem!DeltaTemperature
{
    private ComponentPool!DeltaTemperature deltaTemperatures;
    private ComponentPool!Temperature temperatures;

    public override void onCreated()
    {
        deltaTemperatures = currentWorld.getPoolOf!DeltaTemperature;
        temperatures = currentWorld.getPoolOf!Temperature;
    }

    protected override void onAdd(Entity entity)
    {
        immutable deltaTime = gameWindow.getDeltaTime();
        ref DeltaTemperature delta = deltaTemperatures.getComponent(entity);
        ref Temperature temperature = temperatures.getComponent(entity);

        auto resultDelta = gameWindow.isKeyDown(Keys.leftShift) ? delta.delta * delta.boostMultiplier : delta.delta;

        temperature.value += resultDelta * deltaTime;
        (cast(TemperatureSystem) TemperatureSystem.instance).updateTemperatureOf(entity);

        deltaTemperatures.removeComponent(entity);
    }
}

public class MeltableSystem : System!Meltable
{
    import powders.particle.building;
    import powders.particle.register;
    import powders.particle.loading;

    private ComponentPool!Meltable meltables;
    private ComponentPool!Temperature temperatures;

    public override void onCreated()
    {
        meltables = currentWorld.getPoolOf!Meltable;
        temperatures = currentWorld.getPoolOf!Temperature;
    }

    protected override void onUpdated()
    {
        auto data = meltables.getComponents();

        foreach(i, meltable; data)
        {
            Entity entity = meltables.dense2Entity(currentWorld, i);
            Temperature temperature = temperatures.getComponent(entity);

            if(temperature.value > meltable.criticalTemperature)
            {
                auto serializedResult = globalTypesDictionary[meltable.resultId];
                destroyParticle(entity);
                buildParticle(entity, serializedResult);
                temperatures.addComponent(entity, temperature);
            }
        }
    }
}

public class SolidableSystem : MapEntitySystem!Solidable
{
    import powders.particle.building;
    import powders.particle.register;
    import powders.particle.loading;

    private ComponentPool!Solidable solidables;
    private ComponentPool!Temperature temperatures;

    public override void onCreated()
    {
        solidables = currentWorld.getPoolOf!Solidable;
        temperatures = currentWorld.getPoolOf!Temperature;
    }

    protected override void onUpdated()
    {
        auto data = solidables.getComponents();

        foreach(i, meltable; data)
        {
            Entity entity = solidables.dense2Entity(currentWorld, i);
            Temperature temperature = temperatures.getComponent(entity);

            if(temperature.value > meltable.criticalTemperature)
            {
                auto serializedResult = globalTypesDictionary[meltable.resultId];
                destroyParticle(entity);
                buildParticle(entity, serializedResult);
                temperatures.addComponent(entity, temperature);
            }
        }
    }
}

public class ConvectionSystem : System!Convection
{        
    int[2] mapResolution;

    private TemperatureSystem temperatureSystemInstance;

    private ComponentPool!Convection convectionsPool;
    private ComponentPool!Position positionsPool;
    private ComponentPool!Temperature temperaturesPool;
    private ComponentPool!Particle particlesPool;
    private ComponentPool!UpdateRenderableMarker markersPool;

    public override void onCreated()
    {
        mapResolution = globalMap.resolution();

        temperatureSystemInstance = cast(TemperatureSystem) TemperatureSystem.instance;
        convectionsPool = currentWorld.getPoolOf!Convection;
        positionsPool = currentWorld.getPoolOf!Position;
        temperaturesPool = currentWorld.getPoolOf!Temperature;
        particlesPool = currentWorld.getPoolOf!Particle;
        markersPool = currentWorld.getPoolOf!UpdateRenderableMarker;
    }

    immutable(int[2][GravityDirection]) gravity2convection = 
    [
        GravityDirection.down: [0, -1],
        GravityDirection.up: [0, 1],
        GravityDirection.left: [-1, 0],
        GravityDirection.right: [1, 0],
        GravityDirection.none: [0, 0]
    ];

    protected override void onUpdated()
    {
        import powders.timecontrol;
        static ubyte rawMoveOffset;

        if(globalGameState != GameState.play) return;
        if(Gravity.direction == GravityDirection.none) return;

        Convection[] convections = convectionsPool.getComponents();

        foreach(i, convection; convections)
        {
            Entity entity = convectionsPool.dense2Entity(currentWorld, i);
            immutable Position position = positionsPool.getComponent(entity);

            immutable int[2] gravityDirection = gravity2convection[Gravity.direction];

            // `-1` part converts ofsset from [0..2] to [-1.1]
            immutable int moveOffset = (rawMoveOffset % 3) - 1;
            immutable int[2] gravityPerpendicular = [gravityDirection[1], -gravityDirection[0]];
            immutable int[2] upperPos = position.xy[] + gravityDirection[] + gravityPerpendicular[] * moveOffset;
            
            if(!globalMap.isInBounds(upperPos)) continue;
            Entity upper = globalMap.getAt!false(upperPos);
            if(!convectionsPool.hasComponent(upper)) continue;

            immutable areSameType =
                particlesPool.getComponent(entity).typeId == particlesPool.getComponent(entity).typeId;
            
            immutable Temperature selfTemperature = temperaturesPool.getComponent(entity);
            immutable Temperature upperTemperature = temperaturesPool.getComponent(upper);

            immutable bool isThermalConvectionSuitable = 
                selfTemperature.value > upperTemperature.value && areSameType;

            if(isThermalConvectionSuitable)
            {
                globalMap.swap(entity, upper);
            }
            else continue;

            temperatureSystemInstance.updateTemperatureOf(entity);
            temperatureSystemInstance.updateTemperatureOf(upper);

            markersPool.addComponent(entity);
            markersPool.addComponent(upper);
        }

        rawMoveOffset++;
    }
}

package final class Temperature2ColorConverter
{
    import davincilib.color;
    private ComponentPool!Temperature temperatures;

    public this(World world)
    {
        import kernel.simulation;
        temperatures = world.getPoolOf!Temperature;
    }

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

        immutable auto temperature = temperatures.getComponent(entity).value;
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