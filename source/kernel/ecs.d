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
public class ComponentPool(T)
{
    // dense storage per world
    private T[] dense;
    private Id[] entities;        // dense index -> entity id
    private Id[] sparse;          // entity id -> dense index

    private onAddAction[] onAddDelegates;
    private onRemoveAction[] onRemoveDelegates;

    public Entity dense2Entity(World world, size_t denseId)
    {
        return Entity(world, entities[denseId]);
    }

    /// Reserve space for components in the world
    /// Params:
    ///   world = the world
    ///   componentsCount = count of reserved components 
    public void reserve(size_t componentsCount)
    {
        dense.reserve(componentsCount);
        entities.reserve(componentsCount);
    }

    /// Add component to entity
    /// Params:
    ///   entity = the entity
    ///   value = the value of added component
    public void addComponent(Entity entity, T value = T.init)
    {
        auto eid = entity.id;

        ensureSparse(eid);

        if (hasComponent(entity))
        {
            dense[sparse[eid]] = value;
            return;
        }

        auto index = dense.length;

        dense ~= value;
        entities ~= eid;
        sparse[eid] = index;

        foreach (onAddDelegate; onAddDelegates)
        {
            onAddDelegate(entity);
        }
    }

    /// Remove component from entity. If entity already doesn't have this component, nothing will happen
    public void removeComponent(Entity entity)
    { 
        if (!hasComponent(entity))
            return;

        auto eid = entity.id;

        auto index = sparse[eid];
        auto lastIndex = dense.length - 1;
        auto lastEntity = entities[lastIndex];

        // swap-remove
        dense[index] = dense[lastIndex];
        entities[index] = lastEntity;
        sparse[lastEntity] = index;

        dense.length--;
        entities.length--;

        // mark as removed
        sparse[eid] = Id.max;

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

    public T[] getComponents()
    {
        return dense;
    }

    /// Get component for entity
    /// Params:
    ///   entity = the entity
    /// Returns: the component value. Check if this value valid with `hasComponent`` method
    // when error is true
    public ref T getComponent(Entity entity)
    {
        auto eid = entity.id;

        auto idx = sparse[eid];

        if(idx == Id.max)
        {
            throw new Exception("Component does not exists!");
        }

        return dense[idx];
    }

    public bool hasComponent(Entity entity)
    {
        auto eid = entity.id;

        if (eid >= sparse.length) return false;

        auto idx = sparse[eid];

        if (idx == Id.max) return false;

        return idx < entities.length &&
            entities[idx] == eid;
    }

    private void ensureSparse(Id eid)
    {
        if (eid >= sparse.length)
        {
            auto oldLen = sparse.length;
            sparse.length = eid + 1;

            foreach (i; oldLen .. sparse.length)
            {
                sparse [i] = Id.max;
            }
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
        import kernel.simulation;
        instance = this;
        auto world = Simulation.currentWorld;
        auto pool = world.getPoolOf!T();
        pool.addOnRemoveAction(&onRemove);
        pool.addOnAddAction(&onAdd);
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

public class World
{
    private this(Id id)
    {
        id_ = id;
    }

    public static World create()
    {
        static Id lastId;

        return new World(lastId++);
    }

    // private, but everything is public within a single module
    private size_t totalEntities_;
    private Id id_;

    private Object[string] name2pool;

    public @property size_t totalEntities() nothrow pure inout => totalEntities_;
    public @property Id id() nothrow pure inout => id_;

    public ComponentPool!T getPoolOf(T)() nothrow pure
    {
        enum name = ComponentPool!T.stringof;
        auto pool = name in name2pool;

        if(pool is null)
        {
            auto newPool = new ComponentPool!T;
            name2pool[name] = newPool;
            return newPool;
        }

        return cast(ComponentPool!T) *pool;
    }
}