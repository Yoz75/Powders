//kernel is just a template for all future simulations with ECS. This is named kernel because core is used by d :(
module kernel.ecs;

import std.bitmanip : BitArray;
import kernel.optional;
import dlib.container.array;

/// List of all systems in the simulation
BaseSystem[] systems;

alias Id = size_t;
alias ComponentId = Id;
alias onRemoveAction(T) = void delegate(IEventComponentPool!T pool, Id entityId);
alias onAddAction(T) = void delegate(IEventComponentPool!T pool, Id entityId);

public interface IComponentPool(T)
{
    /// add component to entity or set it to a new value
    /// Params:
    /// entity = the entity
    /// value = the initial value
    void addComponent(Id entityId, T value);

    /// Remove component from entity. Does nothing, if there's no such component
    /// Params:
    /// entity = the entity
    void removeComponent(Id entityId);

    /// Check if entity has this component
    /// Params:
    /// entity = the entity (very informational tip haha)
    /// Returns: true if entity has component, false if not
    bool hasComponent(Id entityId);

    /// Get all active components. If an entity doesn't have this component, it won't be included.
    /// Returns: the array of currently active components
    T[] getComponents();

    ref T getComponent(Id entityId);

    /// Apply delegate `dg` for each component of component pool and include them into returned array, if dg returned true
    /// Params:
    ///   dataPool = the data pool
    ///   dg = the delegate that desides to include components into the result array
    /// Returns: Ids of components, selected by `dg` (may be empty)
    public ComponentId[] where(scope whereDelegate!T dg);

    /// Get component by it's unique ID
    /// Params:
    ///    id = the id of component
    /// Returns: reference to the component
    public ref T getComponentWithId(ComponentId id);
}

public interface IEventComponentPool(T) : IComponentPool!T
{
    /// Add event listener for adding component. This is needed for events, because they are added and removed in the same frame, so marker components can't be used
    /// Params:
    ///   action = the delegate, that will be called when component will be added. It takes an entity as parameter
    void addOnAddAction(scope onAddAction!T action);

    /// Add event listener for removing component. This is needed for events, because they are added and removed in the same frame, so marker components can't be used
    /// Params:
    ///   action = the delegate, that will be called when component will be removed. It takes an entity as parameter
    void addOnRemoveAction(scope onRemoveAction!T action);
}

/// Get array of components of type T, if their entities have components THas...
/// Usage:
/// ------------
/// mixin whereHasMany!(MainA, HasB, HasC, HasD);
/// mixin whereHasMany!(MainB, HasE, HasF);
/// 
/// MainA[] dataA = whereHas(mainAPool, hasAPool, hasBPool, hasCPool);
/// MainB[] dataB = whereHas(mainBPool, hasDPool, hasEPool);
/// ------------
/// Returns: array of components of type T, that satisfy condition. May be empty
public mixin template whereHasMany(T, THas...)
{
    string __variadic2Pools(T...)() 
    {
        import std.string;
        string result;

        static foreach(i, TType; T)
        {
            result ~= "IComponentPool!" ~ TType.stringof ~ " " ~ TType.stringof.toLower() ~ "Pool, ";
        }

        result = result[0..$-2]; // remove last ", "

        return result;
    }

    mixin("ComponentId[] whereHas(IComponentPool!T dataPool, " ~ __variadic2Pools!(THas)() ~ ")" ~
    q{{
        bool has(Id entityId, T data)
        {
            import std.string;
            static foreach(i, THasType; THas)
            {
                if(!mixin(THasType.stringof.toLower() ~ "Pool.hasComponent(entityId)")) return false;
            }

            return true;
        }

        return dataPool.where(&has);
    }});
}

public ComponentId[] whereHas(T, THas)(IComponentPool!T dataPool, IComponentPool!THas hasPool)
{
    bool has(Id entityId, T data)
    {   
        return hasPool.hasComponent(entityId);
    }

    return dataPool.where(&has);
}

public alias whereDelegate(T) = bool delegate(Id entityId, T data);

import kernel.todo;
mixin TODO!"Add kernel.exceptions module, create such classes like NullException, ArgumentException etc; and replace all `Exception`s with new ones.";
public class DenseComponentPool(T, size_t entityReserve = 1024, size_t componentReserve = 128) 
    : IEventComponentPool!T
{
    /// Index is an entity id, value is an index in denseData array, or -1 if entity doesn't have this component
    private Array!(ptrdiff_t, entityReserve) sparce;

    /// Index in dense data -> index in entity2ID data
    private Array!(Id, componentReserve) denseSparce;

    /// The real data array. Index is an index in entity2Id array, value is a component value
    private Array!(T, componentReserve) denseData;

    private onAddAction!T[] onAddDelegates;
    private onRemoveAction!T[] onRemoveDelegates;

public:

    this()
    {
        sparce.resize(entityReserve, -1);
    }

    ~this()
    {
        sparce.free();
        denseData.free();
        denseSparce.free();
    }

    /// add component to entity
    /// Params:
    /// entity = the entity
    /// value = the initial value
    void addComponent(Id entityId, T value)
    {
        ensureSparceBounds(entityId);

        immutable index = sparce[entityId];
        if(index >= 0) 
        {
            denseData[index] = value;
            
            foreach(dg; onAddDelegates)
                dg(this, entityId);
            return;
        }

        // current length is index of new element!
        immutable newIndex = denseData.length;
        denseData.insertBack(value);
        denseSparce.insertBack(entityId);
        
        sparce[entityId] = newIndex;

        foreach(dg; onAddDelegates)
            dg(this, entityId);
    }

    /// Remove component from entity. Does nothing, if there's no such component
    /// Params:
    /// entity = the entity
    void removeComponent(Id entityId)
    {
        if(entityId >= sparce.length)
        return;

        immutable index = sparce[entityId];
        if(index < 0) return;

        immutable lastIndex = denseData.length - 1;
        immutable lastEntity = denseSparce[lastIndex];

        // swap data
        denseData[index] = denseData[lastIndex];

        // update entity mapping
        sparce[lastEntity] = index;
        denseSparce[index] = lastEntity;

        denseData.removeBack(1);
        denseSparce.removeBack(1);

        sparce[entityId] = -1;

        foreach(dg; onRemoveDelegates)
            dg(this, entityId);
    }

    /// Check if entity has this component
    /// Params:
    /// entity = the entity (very informational tip haha)
    /// Returns: true if entity has component, false if not
    bool hasComponent(Id entityId)
    {   
        if(entityId >= sparce.length) return false;
        return sparce[entityId] >= 0;
    } 

    /// Get all active components. If an entity doesn't have this component, it won't be included.
    /// Returns: the array of currently active components

    T[] getComponents() 
    {
        return denseData.data();
    }

    ref T getComponent(Id entityId)
    {
        import std.conv : to;
        
        if(entityId >= sparce.length)
            throw new Exception("Entity " ~ entityId.to!string ~ "doesn`t have component of type" ~ T.stringof);

        immutable denseId = sparce[entityId];

        if(denseId < 0) 
        {
            throw new Exception("There is no a component of type " ~ T.stringof ~ 
             " attached to entity with id " ~ entityId.to!string);
        }

        /// We can't get adress of op index (cuz it's rvalue) so we just get slice and then index it
        return denseData.data[sparce[entityId]];
    }

    /// Add event listener for adding component. This is needed for events, because they are added and removed in the same frame, so marker components can't be used
    /// Params:
    ///   action = the delegate, that will be called when component will be added. It takes an entity as parameter
    void addOnAddAction(scope onAddAction!T action)
    {
        onAddDelegates ~= action;
    }

    /// Add event listener for removing component. This is needed for events, because they are added and removed in the same frame, so marker components can't be used
    /// Params:
    ///   action = the delegate, that will be called when component will be removed. It takes an entity as parameter
    void addOnRemoveAction(scope onRemoveAction!T action)
    {
        onRemoveDelegates ~= action;
    }

    /// Apply delegate `dg` for each component of component pool and include them into returned array, if dg returned true
    /// Params:
    ///   dataPool = the data pool
    ///   dg = the delegate that desides to include components into the result array
    /// Returns: Ids of components, selected by `dg` (may be empty)
    ComponentId[] where(scope whereDelegate!T dg)
    {
        Id[] result;
        result.reserve(denseData.length);

        auto data = denseData.data;

        foreach(denseId, ref value; data)
        {           
            Id index = denseSparce[denseId];
            if(dg(index, value))
            {
                result ~= denseId;
            }
        }

        return result;
    }

    private void ensureSparceBounds(Id entityId)
    {
        enum increaseCoefficient = 2;
        if(entityId >= sparce.length)
        {
            sparce.resize((entityId + 1) * increaseCoefficient, -1);
        }
    }

     /// Get component by it's unique ID
    /// Params:
    ///    id = the id of component
    /// Returns: reference to the component
    ref T getComponentWithId(ComponentId id)
    {
        debug
        {
            if(id < 0 || id > denseData.length)
            {
                import std.conv;
                throw new Exception("Index of component id " ~ id.to!string ~ " went out of length " ~ denseData.length.to!string ~ " of dense array!");
            }
        }

        return denseData.data[id];
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

    public @property Id id() inout 
    {
        return id_;
    }
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
    }

    /// Add pool, that notifies our system about such events, that would be diffcult to implement using marker-components
    /// Params:
    ///   pool = 
    protected final void addNotifierPool(IEventComponentPool!T pool)
    {
        pool.addOnAddAction(&onAdd);
        pool.addOnRemoveAction(&onAdd);
    }

    protected final void removeNotifierPool(IEventComponentPool!T pool)
    {
        import std.algorithm.mutation;
        
    }

    /// Calls when T component was added to entity
    /// Params:
    ///   entity = the entity
    protected void onAdd(IEventComponentPool!T pool, Id entity)
    {
        //nothing
    }

    /// Calls when T component was removed from entity
    /// Params:
    ///   entity = the entity
    protected void onRemove(IComponentPool!T pool, Id entity)
    {
        //nothing
    }
}

public class World
{
    // private, but everything is public within a single module
    private size_t totalEntities_;
    private Id id_;

    private Object[string] componentPools;

    public @property size_t totalEntities() => totalEntities_;
    public @property Id id() => id_;

    /// Get component pool of type T. If it doesn't exist, it will be created. 
    /// Tip for duraks: if you won't get pool of some type U within all lifetime of world, this pool won't be created.
    /// Returns: 
    public IEventComponentPool!T getPoolOf(T)()
    {
        const Object* pool = T.stringof in componentPools;

        if(pool is null)
        {
            auto newPool = new DenseComponentPool!T();
            componentPools[T.stringof] = newPool;
            return newPool;
        }

        return cast(IEventComponentPool!T)(*pool);
    }
}