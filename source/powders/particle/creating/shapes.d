module powders.particle.creating.shapes;

import kernel.ecs;
import powders.particle.loading;
import powders.particle.building;
import powders.rendering;
import powders.map;

public interface IShape
{
    /// Set the size of the shape
    public void setScale(in int scale);
    
    /// Place shape at `position` and fill all it's cells with `type`
    public void fillAtPosition(in int[2] position, in SerializedParticleType type);

    /// Delete all particles situated under shape placed at `position`
    public void deleteAtPos(in int[2] position);

    /// Mark borders of the shape at `position`
    public void markBorders(in int[2] position);
}

package class Rectangle : IShape
{
    private int scale = 5;

    /// Contains the sprite to be rendered
    private Sprite shapeSprite;

    private enum Color shapeColor = Color(180, 180, 180);

    public this()
    {
        shapeSprite = Sprite.create([scale, scale], shapeColor);
    }

    /// Set the size of the shape
    public void setScale(in int scale)
    {
        this.scale = scale;
        shapeSprite.free();
        shapeSprite = Sprite.create([scale, scale], shapeColor);
    }
    
    /// Place shape at `position` and fill all it's cells with `type`
    public void fillAtPosition(in int[2] position, in SerializedParticleType type)
    {
        int[2] leftCorner;
        leftCorner[] = position[] - (scale / 2);
        
        for(int y = leftCorner[1]; y < leftCorner[1] + scale; y++)
        {
            for(int x = leftCorner[0]; x < leftCorner[0] + scale; x++)
            {
                Entity entity = globalMap.getAt([x, y]);
                buildParticle(entity, type);
            }
        }
    }

    /// Delete all particles situated under shape placed at `position`
    public void deleteAtPos(in int[2] position)
    {
        int[2] leftCorner;
        leftCorner[] = position[] - (scale / 2);
        
        for(int y = leftCorner[1]; y < leftCorner[1] + scale; y++)
        {
            for(int x = leftCorner[0]; x < leftCorner[0] + scale; x++)
            {
                Entity entity = globalMap.getAt([x, y]);
                destroyParticle(entity);
            }
        }
    }

    /// Mark borders of the shape at `position`
    public void markBorders(in int[2] position)
    {
        import std.math : round;
        shapeSprite.position = map2WorldPosition(position);
        immutable int[2] halfSize =[shapeSprite.texture.width, shapeSprite.texture.height] / 2;
        shapeSprite.position[0] -= round(halfSize[0]);
        shapeSprite.position[1] -= round(halfSize[1]);

        gameWindow.renderAtWorldPos(shapeSprite);
    }
}