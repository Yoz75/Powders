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
    private IComponentPool!WWorldConductor wWorldPool;
    private IComponentPool!Position positionPool;
    
    public override void onCreated()
    {
        wWorldPool = Simulation.currentWorld.getPoolOf!WWorldConductor();
        positionPool = Simulation.currentWorld.getPoolOf!Position();

        assert(RenderModeSystem.instance !is null, "Render mode system is not initialized but we add render mode!!!");
        RenderModeSystem.instance.addRenderMode(&wwConductor2Color, Keys.three);
    }

    protected override void onAfterUpdate()
    {
        if(globalGameState != GameState.play) return;

        WWorldConductor[] data = wWorldPool.getComponents();
        foreach(i, ref conductor; data)
        {
            conductor.state = conductor.nextState;
        }
    }

    protected override void onUpdated()
    {
        mixin(PauseIfNeeded);

        /// Every particle has Position component so we can just get all components instead of filtering
        WWorldConductor[] data = wWorldPool.getComponents();
        ComponentId[] positionIds = whereHas!(Position, WWorldConductor)(positionPool, wWorldPool);

        foreach(i, ref conductor; data)
        {
            ref Position position = positionPool.getComponentWithId(positionIds[i]);

            conductor.state = conductor.nextState;
            if(conductor.state == ConductorState.nothing)
            {
                auto neighbors = globalMap.getNeighborsAt(position.xy);

                ubyte headsCount;
                foreach(row; neighbors)
                {
                    foreach(neighbor; row)
                    {
                        if(!wWorldPool.hasComponent(neighbor.id)) continue;
                        ref WWorldConductor neighborConductor = wWorldPool.getComponent(neighbor.id);

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
                import kernel.todo;
                mixin TODO!"Do a marker component that tells render system to update color";
            }
        }
    }
}

public class WWorldSparkleSystem : System!WWorldSparkle
{
    import powders.particle.basics : Particle;

    protected override void onAdd(IEventComponentPool!WWorldSparkle pool, Id entityId)
    {
        IComponentPool!WWorldConductor conductorPool = Simulation.currentWorld.getPoolOf!WWorldConductor();
        if(!conductorPool.hasComponent(entityId)) return;

        ref WWorldConductor sparkle = conductorPool.getComponent(entityId);
        sparkle.state = ConductorState.head;
        sparkle.nextState = ConductorState.head;
    }
}

public Color wwConductor2Color(Entity entity)
{
    import davincilib.color;

    IComponentPool!WWorldConductor conductorPool = Simulation.currentWorld.getPoolOf!WWorldConductor();
    IComponentPool!MapRenderable renderablePool = Simulation.currentWorld.getPoolOf!MapRenderable();

    if(!conductorPool.hasComponent(entity.id)) return renderablePool.getComponent(entity.id).color;
    immutable auto conductor = conductorPool.getComponent(entity.id);

    final switch(conductor.state)
    {
        case ConductorState.head:
            return blue;

        case ConductorState.tail:
            return red;

        case ConductorState.nothing:
            return renderablePool.getComponent(entity.id).color;
    }

    return black; // should never happen
}