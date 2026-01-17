module powders.particle.wireworld;

import kernel.ecs;
import kernel.simulation;
import powders.map;
import powders.rendering;
import powders.particle.register;
import powders.io;
import powders.timecontrol;
import std.parallelism;

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
    
    public override void onCreated()
    {
        ComponentPool!WWorldConductor.instance.reserve(Simulation.currentWorld, globalMap.resolution[0] * globalMap.resolution[1]);
        onUpdatedSparkle ~= (Entity self) 
        {
            (cast(RenderableSystem) RenderableSystem.instance).markDirty(self);
        };

        assert(RenderModeSystem.instance !is null, "Render mode system is not initialized but we add render mode!!!");
        RenderModeSystem.instance.addRenderMode(&wwConductor2Color, Keys.three);
    }

    protected override void onAfterUpdate()
    {
        if(globalGameState != GameState.play) return;

        ref data = ComponentPool!WWorldConductor.instance.data[Simulation.currentWorld.id];
        foreach(i, ref conductor; data)
        {
            Entity entity = Entity(Simulation.currentWorld, i);
            if(!entity.hasComponent!WWorldConductor) continue;  

            conductor.state = conductor.nextState;
        }
    }

    protected override void onUpdated()
    {
        if(globalGameState != GameState.play) return;

        ref data = ComponentPool!WWorldConductor.instance.data[Simulation.currentWorld.id];
        foreach(i, ref conductor; data)
        {
            Entity entity = Entity(Simulation.currentWorld, i);
            if(!entity.hasComponent!WWorldConductor) continue;

            conductor.state = conductor.nextState;
            if(conductor.state == ConductorState.nothing)
            {
                auto neighbors = globalMap.getNeighborsAt(entity.getComponent!Position.xy);

                ubyte headsCount;
                foreach(row; neighbors)
                {
                    foreach(neighbor; row)
                    {
                        if(!neighbor.hasComponent!WWorldConductor) continue;

                        ref WWorldConductor neighborConductor = neighbor.getComponent!WWorldConductor();

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

    protected override void onAdd(Entity entity)
    {
        isPausable = false;
        if(!entity.hasComponent!WWorldConductor) return;

        entity.getComponent!WWorldConductor().state = ConductorState.head;
        entity.getComponent!WWorldConductor().nextState = ConductorState.head;
    }
}

public Color wwConductor2Color(Entity entity)
{
    import davincilib.color;

    if(!entity.hasComponent!WWorldConductor) return entity.getComponent!MapRenderable().color;
    immutable auto conductor = entity.getComponent!WWorldConductor();

    final switch(conductor.state)
    {
        case ConductorState.head:
            return blue;

        case ConductorState.tail:
            return red;

        case ConductorState.nothing:
            return entity.getComponent!MapRenderable().color;
    }

    return black; // should never happen
}