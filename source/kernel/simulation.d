//kernel is just a template for all future simulations with ECS. This is named kernel because core is used by d :(
module kernel.simulation;

import kernel.ecs;
import std.datetime : Duration;

public alias onProfile = void delegate(BaseSystem system, Duration time);

public final abstract class Simulation
{
    private enum State
    {
        none,
        running,
        stop,
        restart
    }

    public static World currentWorld;

    /// Is game being profiled right now?
    public static bool isProfiling;
    
    private static State state = State.none;
    private static onProfile[] onBeforeUpdateProfile, onUpdateProfile, onAfterUpdateProfile;

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

        currentWorld = startWorld;

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

    public void addOnBeforeUpdateProfile(onProfile profile)
    {
        onBeforeUpdateProfile ~= profile;
    }

    public static void addOnUpdateProfile(onProfile profile)
    {
        onUpdateProfile ~= profile;
    }

    public static void addOnAfterUpdateProfile(onProfile profile)
    {
        onAfterUpdateProfile ~= profile;
    }

    public static void restart()
    {
        state = State.restart;
    }

    public static void stop()
    {
        state = State.stop;
    }

    private static void update()
    {
        import std.datetime.stopwatch;

        if(isProfiling)
        {
            StopWatch sw = StopWatch(AutoStart.no);

            foreach(system; systems)
            {
                sw.start();
                system.beforeUpdate();
                sw.stop();

                foreach(action; onBeforeUpdateProfile)
                {
                    action(system, sw.peek());
                }

                sw.reset();
            }


            foreach(system; systems)
            {
                sw.start();
                system.update();
                sw.stop();

                foreach(action; onUpdateProfile)
                {
                    action(system, sw.peek());
                }

                sw.reset();
            }

            
            foreach(system; systems)
            {
                sw.start();
                system.afterUpdate();
                sw.stop();

                foreach(action; onAfterUpdateProfile)
                {
                    action(system, sw.peek());
                }

                sw.reset();
            }
        }
        else
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
}

