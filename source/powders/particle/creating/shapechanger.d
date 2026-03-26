module powders.particle.creating.shapechanger;

import kernel.ecs;
import powders.rendering;
import powders.particle.creating.shapes;
import powders.particle.creating.spawning;

public class ShapeChangerSystem : BaseSystem
{
    private IShape[] shapes;
    private size_t selectedShapeId;

    public override void onCreated()
    {
        assert(CreateParticleSystem.instance !is null, "ShapeChangerSystem was created, but shape wasn't set!");
        shapes = [new Rectangle()];
        selectNextShape();
    }

    protected override void onUpdated()
    {
        if(gameWindow.isKeyPressed(Keys.tab))
        {
            selectNextShape();
        }
    }

    private void selectNextShape()
    {
        if(selectedShapeId >= shapes.length) selectedShapeId = 0;

        IShape shape = shapes[selectedShapeId];
        selectedShapeId++;

        CreateParticleSystem.instance.selectShape(shape);
    }
}