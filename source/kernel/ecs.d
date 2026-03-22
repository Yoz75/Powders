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

    // dense storage per world
    private T[][] dense;
    private Id[][] entities;        // dense index -> entity id
    private Id[][] sparse;          // entity id -> dense index

    private onAddAction[] onAddDelegates;
    private onRemoveAction[] onRemoveDelegates;

    public Entity dense2Entity(World world, size_t denseId)
    {
        return Entity(world, entities[world.id][denseId]);
    }

    /// Reserve space for components in the world
    /// Params:
    ///   world = the world
    ///   componentsCount = count of reserved components 
    public void reserve(World world, size_t componentsCount)
    {
        ensureWorld(world);

        dense[world.id].reserve(componentsCount);
        entities[world.id].reserve(componentsCount);
    }

    /// Add component to entity
    /// Params:
    ///   entity = the entity
    ///   value = the value of added component
    public void addComponent(Entity entity, T value)
    {
        ensureWorld(entity.world);

        auto wid = entity.world.id;
        auto eid = entity.id;

        ensureSparse(wid, eid);

        if (hasComponent(entity))
        {
            dense[wid][sparse[wid][eid]] = value;
            return;
        }

        auto index = dense[wid].length;

        dense[wid] ~= value;
        entities[wid] ~= eid;
        sparse[wid][eid] = index;

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

        auto wid = entity.world.id;
        auto eid = entity.id;

        auto index = sparse[wid][eid];
        auto lastIndex = dense[wid].length - 1;
        auto lastEntity = entities[wid][lastIndex];

        // swap-remove
        dense[wid][index] = dense[wid][lastIndex];
        entities[wid][index] = lastEntity;
        sparse[wid][lastEntity] = index;

        dense[wid].length--;
        entities[wid].length--;

        // mark as removed
        sparse[wid][eid] = Id.max;

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

    public T[] getComponents(World world)
    {
        ensureWorld(world);

        return dense[world.id];
    }

    /// Get component for entity
    /// Params:
    ///   entity = the entity
    /// Returns: the component value. Check if this value valid with `hasComponent`` method
    // when error is true
    public ref T getComponent(Entity entity)
    {
        ensureWorld(entity.world);
        auto wid = entity.world.id;
        auto eid = entity.id;

        auto idx = sparse[wid][eid];

        if(idx == Id.max)
        {
            throw new Exception("Component does not exists!");
        }

        return dense[wid][idx];
    }

    public bool hasComponent(Entity entity)
    {
        auto wid = entity.world.id;
        auto eid = entity.id;

        if (wid >= sparse.length) return false;
        if (eid >= sparse[wid].length) return false;

        auto idx = sparse[wid][eid];

        if (idx == Id.max) return false;

        return idx < entities[wid].length &&
            entities[wid][idx] == eid;
    }

    private void ensureWorld(World world)
    {
        auto wid = world.id;

        if (wid >= dense.length)
        {
            dense.length = wid + 1;
            entities.length = wid + 1;
            sparse.length = wid + 1;
        }
    }

    private void ensureSparse(Id wid, Id eid)
    {
        if (eid >= sparse[wid].length)
        {
            auto oldLen = sparse[wid].length;
            sparse[wid].length = eid + 1;

            foreach (i; oldLen .. sparse[wid].length)
            {
                sparse[wid][i] = Id.max;
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

pragma(inline, true):

    /// Shortcut for ComponentPool!T.instance.addComponent. See ComponentPool.addComponent
    public void addComponent(T)(T value = T.init) inout
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