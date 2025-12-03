module powders.memory;

import kernel.ecs;

public class GC_CleanupSystem : BaseSystem
{
    import core.memory : GC;

    protected override void update()
    {
        GC.collect();
    }
} 