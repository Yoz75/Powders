//kernel is just a template for all future simulations with ECS. This is named kernel because core is used by d :(
module kernel.simulation;

import kernel.ecs;
import dlib.container.array;

public final abstract class Simulation
{
    private enum State
    {
        none,
        running,
        stop,
        restart
    }

    public static World* currentWorld;
    private static State state = State.none;

    /// Run the simulation with T... as start systems
    /// Params:
    ///   startWorld = start currentWorld, this reference will be available outside of the method scope.
    ///   beforeUpdate = delegate, that executes before apdete of systems (don't use it for systems, just for internal stuff)
    ///   afterUpdate = delegate, that executes after apdete of systems (don't use it for systems, just for internal stuff)
    public static void run(TSystems...)(
        ref World startWorld, 
        scope void delegate() beforeUpdate, 
        scope void delegate() afterUpdate)
    {
    LStart:

        currentWorld = &startWorld;

        {
            state = State.running;

            static foreach(TSystem; TSystems)
            {
                static assert(__traits(compiles, "BaseSystem base = new TSystem()"),
                "not all types in TSystems are inherited from BaseSystem" ~
                "OR TSystem doesn't have parameterless constructor!");
                SystemFactory!TSystem.create();
            }

            while(state == State.running)
            {
                beforeUpdate();

                update();
                
                afterUpdate();
            }
        }

        if(state == State.restart) goto LStart;
        // Maybe I'll add more states, so this shit is done to avoid potential bugs
        else if(state == State.stop) return;
    }

    public void restart()
    {
        state = State.restart;
    }

    public void stop()
    {
        state = State.stop;
    }

    private static void update()
    {
        foreach(system; systems)
        {
            system.beforeUpdate();
        }

        foreach(system; systems)
        {
            system.update();
        }
        
        foreach(system; systems)
        {
            system.afterUpdate();
        }
    }
}

