module powders.particle.wireworld;

import kernel.ecs;
import kernel.simulation;
import powders.map;
import powders.rendering;
import powders.particle.register;
import powders.io;
import powders.timecontrol;
import std.parallelism;

package WWConductor2ColorConverter ww2ColorConverter;

/// State of wireworld conductor particle
public enum ConductorState
{
    /// There's no current in conductor
    nothing,
    /// Head of the current
    head,
    /// Tail of the current
    tail
}

/// Marker component for particles that conduct electricity.
@Component(OnDestroyAction.destroy) public struct WWorldConductor
{
    mixin MakeJsonizable;
public:
    /// Current state of conductor
    ConductorState state;
    /// Conductor's state at next frame
    ConductorState nextState;
}

/// Just a kostyl for setting `Conductor.state` ConductorState.head
@Component(OnDestroyAction.destroy) public struct WWorldSparkle
{
    mixin MakeJsonizable;
}

/// Wireworld electricity system
public class WWorldConductorSystem : System!WWorldConductor
{
    /// Action, that calls when particle became charged or uncharged
    public void delegate(Entity entity)[] onUpdatedSparkle;

    private ComponentPool!WWorldConductor conductors;
    private ComponentPool!UpdateRenderableMarker markers;
    private ComponentPool!Position positions;
    
    public override void onCreated()
    {
        conductors = currentWorld.getPoolOf!WWorldConductor;
        markers = currentWorld.getPoolOf!UpdateRenderableMarker;
        positions = currentWorld.getPoolOf!Position;

        onUpdatedSparkle ~= (Entity self) 
        {
            markers.addComponent(self);
        };

        assert(RenderModeSystem.instance !is null, "Render mode system is not initialized but we add render mode!!!");
        RenderModeSystem.instance.addRenderMode(&ww2ColorConverter.wwConductor2Color, Keys.three);
    }

    protected override void onAfterUpdate()
    {
        if(globalGameState != GameState.play) return;

        auto data = conductors.getComponents();
        foreach(i, ref conductor; data)
        {
            Entity entity = conductors.dense2Entity(Simulation.currentWorld, i);
            if(!conductors.hasComponent(entity)) continue;  

            conductor.state = conductor.nextState;
        }
    }

    protected override void onUpdated()
    {
        if(globalGameState != GameState.play) return;

        auto data = conductors.getComponents();
        foreach(i, ref conductor; data)
        {
            Entity entity = conductors.dense2Entity(Simulation.currentWorld, i);
            if(!conductors.hasComponent(entity)) continue;

            conductor.state = conductor.nextState;
            if(conductor.state == ConductorState.nothing)
            {
                auto neighbors = globalMap.getNeighborsAt(positions.getComponent(entity).xy);

                ubyte headsCount;
                foreach(row; neighbors)
                {
                    foreach(neighbor; row)
                    {
                        if(!conductors.hasComponent(neighbor)) continue;

                        ref WWorldConductor neighborConductor = conductors.getComponent(neighbor);

                        if(neighborConductor.state == ConductorState.head)
                        {
                            headsCount++;
                        }
                    }   
                }

                conductor.nextState = headsCount == 1 || headsCount == 2 ? ConductorState.head : ConductorState.nothing;
            }
            else if(conductor.state == ConductorState.head)
            {
                conductor.nextState = ConductorState.tail;
            }
            else if(conductor.state == ConductorState.tail)
            {
                conductor.nextState = ConductorState.nothing;
            }

            if(conductor.nextState != conductor.state)
            {
                foreach(action; onUpdatedSparkle)
                {
                    action(entity);
                }
            }
        }
    }
}

public class WWorldSparkleSystem : MapEntitySystem!WWorldSparkle
{
    import powders.particle.basics : Particle;

    private ComponentPool!WWorldConductor conductors;
    private ComponentPool!WWorldSparkle sparkles;

    public override void onCreated()
    {
        conductors = currentWorld.getPoolOf!WWorldConductor;
        sparkles = currentWorld.getPoolOf!WWorldSparkle;
    } 

    protected override void onAdd(Entity entity)
    {
        isPausable = false;
        if(!conductors.hasComponent(entity)) return;

        conductors.getComponent(entity).state = ConductorState.head;
        conductors.getComponent(entity).nextState = ConductorState.head;

        sparkles.removeComponent(entity);
    }
}

package final class  WWConductor2ColorConverter
{
    private ComponentPool!WWorldConductor conductors;
    private ComponentPool!MapRenderable renderables;

    public this(World world)
    {
        conductors = world.getPoolOf!WWorldConductor;
        renderables = world.getPoolOf!MapRenderable;
    }

    public Color wwConductor2Color(Entity entity)
    {
        import davincilib.color;

        if(!conductors.hasComponent(entity)) return renderables.getComponent(entity).color;
        immutable auto conductor = conductors.getComponent(entity);

        final switch(conductor.state)
        {
            case ConductorState.head:
                return blue;

            case ConductorState.tail:
                return red;

            case ConductorState.nothing:
                return renderables.getComponent(entity).color;
        }

        return black; // should never happen
    }
}