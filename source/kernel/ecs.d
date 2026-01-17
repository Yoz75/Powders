//kernel is just a template for all future simulations with ECS. This is named kernel because core is used by d :(
module kernel.ecs;

import std.bitmanip : BitArray;
import kernel.optional;

/// List of all systems in the simulation
BaseSystem[] systems;

alias Id = size_t;
alias onRemoveAction = void delegate(Entity entity);
alias onAddAction = void delegate(Entity entity);

/// Component pool for entities in the simulation
public struct ComponentPool(T)
{
    public static ComponentPool!T instance;

    T[][] data;
    // is entity [worldId][i] has this component or not?
    private BitArray[] entitiesHasTable;

    private onAddAction[] onAddDelegates;
    private onRemoveAction[] onRemoveDelegates;

    /// Reserve space for components in the world
    /// Params:
    ///   world = the world
    ///   componentsCount = count of reserved components 
    public void reserve(World world, size_t componentsCount)
    {
        // tryExtendData works with entitirs, so we make a kostyl
        if(world.id >= data.length)
        {
            data.length = world.id + 1;
        }

        if(world.id >= entitiesHasTable.length)
        {
            entitiesHasTable.length = world.id + 1;
        }

        data[world.id].reserve(componentsCount);

        entitiesHasTable[world.id].length = data[world.id].length;         
    }

    /// Add component to entity
    /// Params:
    ///   entity = the entity
    ///   value = the value of added component
    public void addComponent(Entity entity, T value)
    {
        tryExtendData(entity);

        data[entity.world.id][entity.id] = value;
        entitiesHasTable[entity.world.id][entity.id] = true;

        foreach(onAddDelegate; onAddDelegates)
        {
            onAddDelegate(entity);
        }
    }

    /// Remove component from entity. If entity already doesn't have this component, nothing will happen
    /// Params:
    ///   entity = the entity
    public void removeComponent(Entity entity)
    {
        tryExtendData(entity);
        data[entity.world.id][entity.id] = T.init;
        entitiesHasTable[entity.world.id][entity.id] = false;

        foreach (onRemove; onRemoveDelegates)
        {
            onRemove(entity);
        }
    }
    
    public void addOnRemoveAction(scope onRemoveAction action)
    {
        onRemoveDelegates ~= action;
    }

    public void addOnAddAction(scope onAddAction action)
    {
        onAddDelegates ~= action;
    }

    /// Get component for entity
    /// Params:
    ///   entity = the entity
    /// Returns: the component value. Check if this value valid with `hasComponent`` method
    // when error is true
    public ref T getComponent(Entity entity)
    {
        tryExtendData(entity);
        return data[entity.world.id][entity.id];
    }

    public bool hasComponent(Entity entity)
    {
        tryExtendData(entity);

        return entitiesHasTable[entity.world.id][entity.id];
    }

    /// Try to extend data and has table if they are too short
    /// (this name is bad, it it neetds to be renamed)
    /// Params:
    ///   entity = the entity
    pragma(inline, true)
    private void tryExtendData(Entity entity)
    {
        if (entity.world.id >= entitiesHasTable.length)
        {
            entitiesHasTable.length = entity.world.id + 1;
        }
        if (entity.world.id >= data.length)
        {
            data.length = entity.world.id + 1;
        }

        const ref BitArray worldHasTable = entitiesHasTable[entity.world.id];
        const ref T[] worldDataTable = data[entity.world.id];

        if (entity.id >= worldHasTable.length)
        {
            entitiesHasTable[entity.world.id].length = entity.id + 1;
        }
        if (entity.id >= worldDataTable.length)
        {
            data[entity.world.id].length = entity.id + 1;
        }
    }
}

/// Entity in the simulation (ECS)
public struct Entity
{
    /// Entity's world
    public World world;

    /// Identificator, used for components
    private Id id_;

    public static Entity create(ref World world)
    {
        return Entity(world, world.totalEntities_++);
    }

    public @property Id id() => id_;

pragma(inline, true):

    /// Shortcut for ComponentPool!T.instance.addComponent. See ComponentPool.addComponent
    public void addComponent(T)(T value) inout
    {
        ComponentPool!T.instance.addComponent(this, value);
    }    

    /// Add a bundle of components. This method adds all fields of T as separated components with default init value
    public void addBundle(T)() inout
    {
        import std.traits: Fields;

        static foreach(TField; Fields!T)
        {
            addComponent!TField(TField.init);
        }
    }

    /// Remove a bundle of components. This method removes all fields of T as separated components
    public void removeBundle(T)() inout
    {
        import std.traits: Fields;

        static foreach(TField; Fields!T)
        {
            removeComponent!TField();
        }
    }

    /// Shortcut for ComponentPool!T.instance.getComponent. See ComponentPool.getComponent
    public ref T getComponent(T)() inout
    {
        return ComponentPool!T.instance.getComponent(this);
    }

    /// Shortcut for ComponentPool!T.instance.hasComponent. See ComponentPool.hasComponent
    public bool hasComponent(T)() inout
    {
        return ComponentPool!T.instance.hasComponent(this);
    }

    /// Shortcut for ComponentPool!T.instance.removeComponent. See ComponentPool.removeComponent
    public void removeComponent(T)() inout
    {
        return ComponentPool!T.instance.removeComponent(this);
    }

pragma(inline):
}

/// Factory class for all systems. Create new systems using this factory
public final abstract class SystemFactory(T) 
{
    public static T create()
    {
        import kernel.simulation : Simulation;
        
        auto system = new T();
        system.currentWorld = Simulation.currentWorld;
        systems ~= system;

        system.onCreated();

        return system;
    }
}

/// Base class for systems. Needed only beause System(T) is tenplate class
public abstract class BaseSystem
{
    protected World currentWorld;

    /// Update system for each component
    public final void update()
    {
        onUpdated();
    }

    protected void onUpdated()
    {
        //nothing here
    }

    public final void destroy()
    {
        onDestroyed();
    }

    protected void onDestroyed()
    {
        //nothing here
    }

    public void onCreated()
    {
        //nothing here
    }

    /// Method, that called before any update in this frame
    public final void beforeUpdate()
    {
        onBeforeUpdate();
    }

    protected void onBeforeUpdate()
    {
        //nothing here
    }

    /// Method, that called after all updates in this frame
    public final void afterUpdate()
    {
        onAfterUpdate();
    }

    protected void onAfterUpdate()
    {
        //nothing here
    }
}

/// Real base class for all systems. T is component type that this system works with
public abstract class System(T) : BaseSystem
{    
    public static System!T instance;

    public this()
    {
        instance = this;
        ComponentPool!T.instance.addOnRemoveAction(&onRemove);
        ComponentPool!T.instance.addOnAddAction(&onAdd);
    }

    /// Calls when T component was added to entity
    /// Params:
    ///   entity = the entity
    protected void onAdd(Entity entity)
    {
        //nothing
    }

    /// Calls when T component was removed from entity
    /// Params:
    ///   entity = the entity
    protected void onRemove(Entity entity)
    {
        //nothing
    }
}

public struct World
{
    public static World create()
    {
        static Id lastId;

        return World(lastId++);
    }

    // private, but everything is public within a single module
    private size_t totalEntities_;
    private Id id_;

    public @property size_t totalEntities() => totalEntities_;
    public @property Id id() => id_;
}