//kernel is just a template for all future simulations with ECS. This is named kernel because core is used by d :(
module kernel.ecs;

import std.bitmanip : BitArray;
import kernel.optional;

/// List of all systems in the simulation
BaseSystem[] systems;

alias Id = size_t;
alias onRemoveAction = void delegate(Entity entity);

/// Component pool for entities in the simulation
public struct ComponentPool(T)
{
    public static ComponentPool!T instance;

    private T[][] data;
    // is entity [worldId][i] has this component or not?
    private BitArray[] entitiesHasTable;

    private onRemoveAction[] onRemoveDelegates;

    /// Add component to entity
    /// Params:
    ///   entity = the entity
    ///   value = the value of added component
    public void addComponent(Entity entity, T value)
    {
        tryExtendData(entity);

        data[entity.world.id][entity.id] = value;
        entitiesHasTable[entity.world.id][entity.id] = true;
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

    /// Get component for entity
    /// Params:
    ///   entity = the entity
    /// Returns: optional with TResult as T* and TError as bool. Entity doens't have this component,
    // when error is true
    public Optional!(T*, bool) getComponent(Entity entity)
    {
        tryExtendData(entity);

        bool isValid = entitiesHasTable[entity.world.id][entity.id];

        return Optional!(T*, bool)(&data[entity.world.id][entity.id], !isValid, isValid);
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

        ref BitArray worldHasTable = entitiesHasTable[entity.world.id];
        ref T[] worldDataTable = data[entity.world.id];

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
    public void addComponent(T)(T value)
    {
        ComponentPool!T.instance.addComponent(this, value);
    }    

    /// Add a bundle of components. This method adds all fields of T as separated components with default init value
    public void addBundle(T)()
    {
        import std.traits: Fields;

        static foreach(TField; Fields!T)
        {
            addComponent!TField(TField.init);
        }
    }

    /// Remove a bundle of components. This method removes all fields of T as separated components
    public void removeBundle(T)()
    {
        import std.traits: Fields;

        static foreach(TField; Fields!T)
        {
            removeComponent!TField();
        }
    }

    /// Shortcut for ComponentPool!T.instance.getComponent. See ComponentPool.getComponent
    public Optional!(T*, bool) getComponent(T)()
    {
        return ComponentPool!T.instance.getComponent(this);
    }

    /// Shortcut for ComponentPool!T.instance.hasComponent. See ComponentPool.hasComponent
    public bool hasComponent(T)()
    {
        return ComponentPool!T.instance.hasComponent(this);
    }

    /// Shortcut for ComponentPool!T.instance.removeComponent. See ComponentPool.removeComponent
    public void removeComponent(T)()
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
    public void update()
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

    public void beforeUpdate()
    {
        //nothing here
    }

    public void afterUpdate()
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
    }

    /// Calls when T component was removed from entity
    /// Params:
    ///   entity = the entity
    public void onRemove(Entity entity)
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