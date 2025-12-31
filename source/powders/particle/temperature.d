module powders.particle.temperature;

import kernel.ecs;
import powders.io;
import powders.particle.register;
import powders.particle.basics;
import powders.map;
import std.concurrency;

// Number type used for heat and temperature
alias TemperatureScalar = double;

@Component(OnDestroyAction.setInit) public struct Temperature
{
    mixin MakeJsonizable;

public:
    /// The least fractional part of temperature
    enum TemperatureScalar threshold = 0.001;

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
    TemperatureScalar transferCoefficient = 0.1;

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

private enum TemperatureThreadMessageType
{
    pause,
    unpause,
    setTemperature
}

private struct TemperatureThreadMessage
{
    TemperatureThreadMessageType type;

    Temperature cell;
    int[2] position;
}

private struct TemperatureThreadContext
{
public:
    /// Input buffer with temperatures to read from
    Temperature[][] inputBuffer;

    /// Output buffer with temperatures to write to
    Temperature[][] outputBuffer;

    /// Should pause temperature thread or not?
    bool isPaused;
}

private void temperatureThread(shared TemperatureThreadContext* context)
{
    void processMessage(TemperatureThreadMessage msg)
    {
        import std.stdio;
        final switch(msg.type)
        {
            case TemperatureThreadMessageType.pause:
                context.isPaused = true;
                break;

            case TemperatureThreadMessageType.unpause:
                context.isPaused = false;
                break;

            // We are outside of computing loop so can safely change input buffer
            case TemperatureThreadMessageType.setTemperature:
                context.inputBuffer[msg.position[0]][msg.position[1]] = msg.cell;
                context.outputBuffer[msg.position[0]][msg.position[1]] = msg.cell;
                break;
        }
    }

    try
    {
        while(true)
        {
            import std.datetime : msecs;

            receiveTimeout(0.msecs, &processMessage);
            if(context.isPaused) continue;
            processHeat(context);


            shared Temperature[][] temp;

            temp = context.inputBuffer;
            context.inputBuffer = context.outputBuffer;
            context.outputBuffer = temp;          
        }
    }
    catch(Throwable ex)
    {
        import std.stdio;
        import core.stdc.stdlib;
        
        writeln("FATAL TEMPERATURE THREAD ERROR!", ex.msg);
        exit(-3);
    }
}

private void processHeat(shared TemperatureThreadContext* context)
{
    assert(context.inputBuffer.length == context.outputBuffer.length && context.outputBuffer.length,
        "Input, temp, and output temperature buffers must have the same resolution!");
    import std.math;
    import std.algorithm;
    import core.atomic;

    foreach(y, ref row; context.inputBuffer)
    {
        foreach(x, ref temperature; row)
        {        
            for(int neighborY = -1; neighborY <= 1;  neighborY++)
            {
                for(int neighborX = -1; neighborX <= 1; neighborX++)
                {
                    if(neighborX == 0 && neighborY == 0) continue;
                    
                    auto neighborPosition = [x + neighborX, y + neighborY];
                    if(neighborPosition[0] < 0)
                    {
                        neighborPosition[0] = context.outputBuffer[0].length - 1;
                    }
                    if(neighborPosition[1] < 0)
                    {
                        neighborPosition[1] = context.outputBuffer.length - 1;
                    }

                    neighborPosition[0] %= context.outputBuffer[0].length;
                    neighborPosition[1] %= context.outputBuffer.length;

                    ref shared Temperature neighborTemperature =
                     context.inputBuffer[neighborPosition[1]][neighborPosition[0]];

                    if(neighborTemperature.value == temperature.value) continue;
                    //if((cast(double)neighborTemperature.value).isClose(cast(double)temperature.value)) continue;

                    immutable auto resultTemperature = (temperature.heatCapacity * temperature.value + 
                    neighborTemperature.heatCapacity * neighborTemperature.value) / 
                    (temperature.heatCapacity + neighborTemperature.heatCapacity);

                    immutable auto selfDelta = ((resultTemperature - temperature.value) *
                        temperature.transferCoefficient).quantize(Temperature.threshold);

                    immutable auto neighborDelta = ((resultTemperature - neighborTemperature.value) *
                        neighborTemperature.transferCoefficient).quantize(Temperature.threshold);

                    temperature.value.atomicOp!"+="(selfDelta);
                    neighborTemperature.value.atomicOp!"+="(neighborDelta);

                    temperature.value.clamp(Temperature.min, Temperature.max);

                    neighborTemperature.value = neighborTemperature.value.clamp(Temperature.min, Temperature.max);
                }
            }
        }
    }
}

import kernel.todo;
mixin TODO!("Currently TemperatureSystem is broken when process ambient heat, fix later!");
public class TemperatureSystem : System!Temperature
{
    import core.thread;

    private Tid threadId;
    private shared TemperatureThreadContext* context;

    public void delegate(Entity entity)[] onTemperatureChanged;
    private int[2] mapResolution;

    public void setTemperature(int[2] position, TemperatureScalar newTemperature)
    {
        TemperatureThreadMessage message;
        message.type = TemperatureThreadMessageType.setTemperature;

        Temperature temp = context.inputBuffer[position[1]][position[0]];
        temp.value = newTemperature;
        
        message.cell = temp;
        message.position = position;
        threadId.send(message);
    }
    
    public override void onCreated()
    {
        mapResolution = globalMap.resolution();

        import powders.rendering;
        onTemperatureChanged ~= (Entity self) 
        {
            if(RenderModeSystem.instance.getCurrentRenderModeConverter() == &temperature2Color)
                (cast(RenderableSystem) RenderableSystem.instance).markDirty(self);
        };

        assert(RenderModeSystem.instance !is null, "Render mode system is not initialized but we add render mode!!!");
        RenderModeSystem.instance.addRenderMode(&temperature2Color, Keys.two);

        context = new shared TemperatureThreadContext;

        context.inputBuffer = new shared Temperature[][](mapResolution[1], mapResolution[0]);
        context.outputBuffer = new shared Temperature[][](mapResolution[1], mapResolution[0]);

        for(int y = 0; y < mapResolution[1]; y++)
        {
            for(int x = 0; x < mapResolution[0]; x++)
            {
                context.inputBuffer[y][x] = globalMap.getAt([x, y]).getComponent!Temperature();
            }
        }

        threadId = spawn(&temperatureThread, context);
    }

    protected override void onUpdated()
    {    
        import powders.timecontrol;
        if(globalGameState != GameState.play)
        {
            context.isPaused = true;
            return;
        }
        else context.isPaused = false;
        
        foreach(x, y, entity; globalMap)
        {
            ref Temperature temperature = entity.getComponent!Temperature();
            immutable auto newValue = context.outputBuffer[y][x].value;

            if(temperature.value != newValue)
            {
                temperature.value = newValue;

                foreach(action; onTemperatureChanged)
                {
                    action(entity);
                }            
            }
        }
    }
}
public class DeltaTemperatureSystem : MapEntitySystem!DeltaTemperature
{
    protected override void onAdd(Entity entity)
    {
        immutable DeltaTemperature delta = entity.getComponent!DeltaTemperature();
        immutable Temperature temperature = entity.getComponent!Temperature();
        
        // Idk why, but I have to swap coords
        int[2] position = entity.getComponent!Position().xy;
        int temp = position[0];
        position[0] = position[1];
        position[1] = temp;

        (cast(TemperatureSystem) TemperatureSystem.instance).setTemperature(position, delta.delta + temperature.value);
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