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

/// System that Processes entities on the global map
public abstract class MapEntitySystem(T) : System!T
{
    public enum ChunkState
    {
        dirty,
        clean
    }

    public struct Chunk
    {
    public:
        ChunkState state = ChunkState.dirty;
        Entity[][] data;

        /// Convert world position to chunk index in table
        /// Params:
        ///   worldPosition = world position
        /// Returns: index of chunk containing the world position
        pure static int[2] world2ChunkIndex(int[2] worldPosition)
        {
            return [worldPosition[0] / Map.chunkSize, worldPosition[1] / Map.chunkSize];
        }

        /// Convert chunk index and position in chunk to world position
        /// Params:
        ///   chunkIndex = index of chunk in table
        ///   chunkPosition = chunk-related position
        /// Returns: 
        pure static int[2] chunk2WorldPosition(int[2] chunkIndex, int[2] chunkPosition)
        {
            return [chunkIndex[0] * Map.chunkSize + chunkPosition[0],
                    chunkIndex[1] * Map.chunkSize + chunkPosition[1]];
        }
    }

    protected Chunk[][] chunks;
    private Chunk[][] tempChunks;
    protected bool isPausable = true;

    public this()
    {
        super();

        assert(globalMap != Map.init, "MapEntitySystem is being initialized before globalMap is initialized!");

        initChunks(chunks, globalMap.map);
        initChunks(tempChunks, globalMap.tempMap);

        globalMap.onFinalizeTick ~= &swapChunks;
    }

    /// Make the chunk containing the `position` dirty
    /// Params:
    ///   position = the position of entity, that made the chunk dirty
    public void makeChunkDirty(int[2] position)
    {
        immutable int[2] chunkIndex = Chunk.world2ChunkIndex(position);
        chunks[chunkIndex[1]][chunkIndex[0]].state = ChunkState.dirty;
    }

    public override void update()
    {
        if(globalGameState == GameState.pause && isPausable)
        {
            return;
        }

        foreach(j, row; chunks)
        {
            foreach(i, ref chunk; row)
            {
                if(chunk.state == ChunkState.clean) continue;

                foreach(y, chunkRow; chunk.data)
                {
                    foreach(x, entity; chunkRow)
                    {
                        if(!entity.hasComponent!T()) continue;

                        ref T component = entity.getComponent!T();
                        updateComponent(entity, chunk, component);
                    }
                }
            }
        } 
    }

    /// Mark the chunk of `entity` as dirty
    /// Params:
    ///   entity = the entity, made chunk dirty
    public void markDirty(Entity entity)
    {
        immutable int[2] position = entity.getComponent!Position().xy;
        immutable int[2] chunkIndex = Chunk.world2ChunkIndex(position);

        chunks[chunkIndex[1]][chunkIndex[0]].state = ChunkState.dirty;
    }


    protected abstract void updateComponent(Entity entity, ref Chunk chunk, ref T component);

    private void swapChunks()
    {
        auto temp = chunks;
        chunks = tempChunks;
        tempChunks = temp;
    }

    private void initChunks(ref Chunk[][] chunks, Entity[][] map)
    {
        immutable int[2] resolution = globalMap.resolution;

        chunks = new Chunk[][resolution[1] / Map.chunkSize];
        foreach(j, ref row; chunks)
        {
            row = new Chunk[resolution[0] / Map.chunkSize];

            foreach(i, ref chunk; row)
            {
                chunk.data = new Entity[][Map.chunkSize];

                foreach(y, ref chunkRow; chunk.data)
                {
                    chunkRow = new Entity[Map.chunkSize];
                    chunkRow = map[j * Map.chunkSize + y]
                     [i * Map.chunkSize .. i * Map.chunkSize + Map.chunkSize];
                }
            }
        }
    }
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

    /// The resolution of map, [x, y]
    public @property int[2] resolution() pure const
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
        if(mapSize[0] % chunkSize != 0 || mapSize[1] % chunkSize != 0)
        {
            throw new Exception("Map must be made of chunks with size " ~ chunkSize);
        }

        map.length = mapSize[1];

        foreach(y, ref row; map)
        {
            row.length = mapSize[0];

            foreach(x, ref entity; row)
            {
                entity = Entity.create(Simulation.currentWorld);
                entity.addComponent!Position(Position([cast(int) x, cast(int) y]));
            }
        }

        tempMap.length = mapSize[1];
        foreach(y, ref row; tempMap)
        {
            row.length = mapSize[1];

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
        ref Position firstPos = first.getComponent!Position();
        ref Position secondPos = second.getComponent!Position();
        Position temp = firstPos;     

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