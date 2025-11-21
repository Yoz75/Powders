module powders.particle.electricity;

import kernel.ecs;
import powders.map;
import powders.rendering;
import powders.particle.register;
import powders.io;

public enum ConductorState
{
    nothing,
    head,
    tail
}

/// Marker component for particles that conduct electricity.
@Component(OnDestroyAction.destroy) public struct Conductor
{
    mixin MakeJsonizable;
public:

    ConductorState state, nextState;
}

/// Just a kostyl for setting `Conductor.state` ConductorState.head
@Component(OnDestroyAction.destroy) public struct Sparkle
{
    mixin MakeJsonizable;
}

/// Wireworld electricity system
public class ConductorSystem : MapEntitySystem!Conductor
{
    /// Action, that calls when particle became charged or uncharged
    public void delegate(Entity entity)[] onUpdatedSparkle;

    protected override void update()
    {
        super.update();

        foreach(entity; globalMap)
        {
            if(entity.hasComponent!Conductor)
            {
                ref Conductor conductor = entity.getComponent!Conductor();
                conductor.state = conductor.nextState;
            }
        }
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Conductor conductor)
    {
        if(conductor.state == ConductorState.nothing)
        {
            auto neighbors = globalMap.getNeighborsAt(entity.getComponent!Position.xy);

            ubyte headsCount;
            foreach(row; neighbors)
            {
                foreach(neighbor; row)
                {
                    if(!neighbor.hasComponent!Conductor) continue;

                    ref Conductor neighborConductor = neighbor.getComponent!Conductor();

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

public class SparkleSystem : MapEntitySystem!Sparkle
{
    import powders.particle.basics : Particle;

    protected override void onAdd(Entity entity)
    {
        isPausable = false;
        if(!entity.hasComponent!Particle) return;
        if(!entity.hasComponent!Conductor) return;

        entity.getComponent!Conductor().state = ConductorState.head;
        entity.getComponent!Conductor().nextState = ConductorState.head;
    }

    protected override void updateComponent(Entity entity, ref Chunk chunk, ref Sparkle sparkle)
    {
        // nothing
    }
}