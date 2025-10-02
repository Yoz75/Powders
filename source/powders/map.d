module powders.map;

import kernel.ecs;
import kernel.simulation;
import dlib.container.array;

/// Global map instance. 
public Map globalMap;

/// Position on map component
public struct Position
{
public:
    int[2] xy;
}

/// System that Processes entities on the global map
public abstract class MapEntitySystem(T) : System!T
{
    public override void update()
    {
        foreach(ref entity; globalMap)
        {
            auto component = entity.getComponent!T();
            if(component.hasValue)
            updateComponent(entity, *component.value);
        } 
    }

    protected abstract void updateComponent(Entity entity, ref T component);
}

public struct Map
{
    // In this case 32 elements of static storage would be useless because nobody plays
    // on 32x32 maps. But big values would be too huge for stack or executable size 
    private Array!(Array!(Entity, 1), 1) map;
    private Array!(Array!(Entity, 1), 1) tempMap; 

    public @property int[2] resolution()
    {
        int[2] resolution;
        resolution = [cast(int) map.length, cast(int) map[0].length];
        return resolution;
    }

    /// Create new map instancee
    /// Params:
    ///   mapSize = map size. [0] is x and [1] is y
    public this(int[2] mapSize)
    {
        map.resize(mapSize[1], Array!(Entity, 1).init);
        tempMap.resize(mapSize[1], Array!(Entity, 1).init);

        foreach(y, ref row; map)
        {
            row.resize(mapSize[0], Entity.init);

            foreach(x, ref entity; row)
            {
                entity = Entity.create(Simulation.currentWorld);
                entity.addComponent!Position(Position([cast(int) x, cast(int) y]));
            }
        }

        foreach(y, ref row; tempMap)
        {
            row.resize(mapSize[0], Entity.init);

            foreach(x, ref entity; row)
            {
                entity = map[y][x];
            }
        }
    }

    import std.traits : ParameterTypeTuple;

    public int opApply(scope int delegate(ref Entity) dg)
    {
        foreach(ref row; map)
        {
            foreach (ref entity; row)
            {
                int result = dg(entity);
                if(result) return result;
            }
        }

        return 0;
    }

    public int opApply(scope int delegate(int x, int y, ref Entity) dg)
    {
        foreach(y, ref row; map)
        {
            foreach (x, ref entity; row)
            {
                int result = dg(cast(int) x, cast(int) y, entity);
                if(result) return result;
            }
        }

        return 0;
    }

    /// Get entity at position (position is automatically bounded to map size)
    /// Returns: entity at position
    pragma(inline, true) public Entity getAt(int[2] position)
    {
        boundPosition(position);
        return map[position[1]][position[0]];
    }

    /// Swap two entities on the map and update their Position components
    public void swap(Entity first, Entity second)
    {
        Position* firstPos = first.getComponent!Position().value;
        Position* secondPos = second.getComponent!Position().value;
        Position temp = *firstPos;     

        tempMap[firstPos.xy[1]][firstPos.xy[0]] = second;
        tempMap[secondPos.xy[1]][secondPos.xy[0]] = first;

        firstPos.xy[] = secondPos.xy[];
        secondPos.xy[] = temp.xy[];
    }
    
    /// Finalize the tick, apply all changes made to the map
    public void finalizeTick()
    {
        auto temp = map;
        map = tempMap;
        tempMap = temp;

        foreach(y, ref row; tempMap)
        {

            foreach(x, ref entity; row)
            {
                entity = map[y][x];
            }
        }
    }

    /// Free all resources
    public void free()
    {
        foreach(y, ref row; map)
        {
            row.free();
        }

        map.free();
    }    

    /// Bound position to map coordinates
    /// Params:
    ///   position = the position, this parameter is ref and WILL BE bounded.
    pragma(inline, true) public void boundPosition(ref int[2] position)
    {
        if(position[0] < 0) position[0] = resolution[0] - 1;
        if(position[1] < 0) position[1] = resolution[1] - 1;

        position[] %= resolution[];
    }
}