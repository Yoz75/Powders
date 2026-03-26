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

        immutable shapeScale = shapes[selectedShapeId].getScale();

        immutable float wheelMove = gameWindow.getMouseWheelMove();
        if(wheelMove > 0 && gameWindow.isKeyDown(Keys.leftControl))
        {
            shapes[selectedShapeId].setScale(shapeScale + 1);
        }
        else if(wheelMove < 0 && gameWindow.isKeyDown(Keys.leftControl))
        {
            if(shapeScale <= 1) return;
            shapes[selectedShapeId].setScale(shapeScale - 1);
        }
    }

    private void selectNextShape()
    {
        selectedShapeId++;
        if(selectedShapeId >= shapes.length) selectedShapeId = 0;
        IShape shape = shapes[selectedShapeId];

        CreateParticleSystem.instance.selectShape(shape);
    }
}