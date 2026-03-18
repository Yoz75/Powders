module powders.map;

import kernel.ecs;
import kernel.simulation;
import powders.timecontrol;

/// Global map instance. 
public Map globalMap;

/// Position on map component
public struct Position
{
public:
    int[2] xy;
}

alias FinaizeTickAction = void delegate();

public struct Map
{
    /// Map must be made of blocks with this size!
    public enum chunkSize = 16;

    /// Actiond, that invoked when map finalized tick
    public FinaizeTickAction[] onFinalizeTick;

    private Entity[][] map;
    private Entity[][] tempMap; 

    private ComponentPool!Position positionPool;

    /// The resolution of map, [x, y]
    public @property int[2] resolution() pure const
    {
        int[2] resolution;
        resolution = [cast(int) map[0].length, cast(int) map.length];
        return resolution;
    }

    /// Create new map instancee
    /// Params:
    ///   mapSize = map size. [0] is x and [1] is y
    public this(int[2] mapSize)
    {
        if(mapSize[0] % chunkSize != 0 || mapSize[1] % chunkSize != 0)
        {
            throw new Exception("Map must be made of chunks with size " ~ chunkSize);
        }

        map.length = mapSize[1];
        positionPool = Simulation.currentWorld.getPoolOf!Position();
        foreach(y, ref row; map)
        {
            row.length = mapSize[0];

            foreach(x, ref entity; row)
            {
                entity = Entity.create(Simulation.currentWorld);
                
                positionPool.addComponent(entity.id, Position([cast(int) x, cast(int) y]));
            }
        }

        tempMap.length = mapSize[1];
        foreach(y, ref row; tempMap)
        {
            row.length = mapSize[0];

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
                immutable int result = dg(entity);
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

    /// Get neighbors of entity at `position`. The cell at [2][2] is the entity itself.
    /// Params:
    ///   position = the position
    /// Returns: array of neighbors. [2][2] is the entity itself
    public Entity[3][3] getNeighborsAt(int[2] position)
    {
        boundPosition(position);
        Entity[3][3] result;

        int relativeY;
        for(int y = position[1] - 1; y <= position[1] + 1; y++)
        {
            int relativeX;
            for(int x = position[0] - 1; x <= position[0] + 1; x++)
            {
                int[2] neighborPosition = [x, y];
                boundPosition(neighborPosition);

                result[relativeY][relativeX] = getAt(neighborPosition);

                relativeX++;
            }

            relativeY++;
        }

        return result;
    }

    /// Swap two entities on the map and update their Position components
    public void swap(Entity first, Entity second)
    {
        Position firstPos = positionPool.getComponent(first.id);
        Position secondPos = positionPool.getComponent(second.id);
        Position temp = firstPos;

        tempMap[firstPos.xy[1]][firstPos.xy[0]] = second;
        tempMap[secondPos.xy[1]][secondPos.xy[0]] = first;

        firstPos.xy[] = secondPos.xy[];
        secondPos.xy[] = temp.xy[];

        positionPool.addComponent(first.id, firstPos);
        positionPool.addComponent(second.id, secondPos);
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

        foreach(action; onFinalizeTick)
        {
            action();
        }
    }

    /// Bound position to map coordinates
    /// Params:
    ///   position = the position, this parameter is ref and WILL BE bounded.
    pragma(inline, true) public void boundPosition(ref int[2] position)
    {
        immutable int[2] mapResolution = this.resolution;

        if(position[0] < 0) position[0] = mapResolution[0] - 1;
        if(position[1] < 0) position[1] = mapResolution[1] - 1;

        position[] %= mapResolution[];
    }
}