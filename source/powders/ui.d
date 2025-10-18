module powders.ui;

import kernel.ecs;
import powders.rendering;
import raygui;
import raylib;

private UIElement[] allElements;

/// Is providen point under an UI element or not?
/// Params:
///   point = the point in range [0, 0]..[1, 1]
/// Returns: 
public bool isUnderUI(float[2] point)
{
    bool isPointInsideRect(float[2] position, float[2] size)
    {
        float[2] upperBound;
        upperBound[] = position[] + size[];

        if(point[0] >= position[0] && point[0] <= upperBound[0])
        {
            if(point[1] >= position[1] && point[1] <= upperBound[1])
            {
                return true;
            }
        }

        return false;
    }

    foreach (UIElement element; allElements)
    {
        if(isPointInsideRect(element.position, element.size))
        {
            return true;
        }
    }

    return false;
}
    
public class InitialUISystem : BaseSystem
{
    public override void onCreated()
    {
        SystemFactory!UpdateUISystem.create();
    }
}

/// Every thing, that can be renderer on the screen in 0..1 space.
public abstract class UIElement
{
public:
    ///Position in range [0, 0]..[1, 1], where [0, 0] is top-left corner, [1, 1] is bottom-right corner
    float[2] position = [0, 0];
    /// Size in range [0, 0]..[1, 1], where [1, 1] is size of the screen
    float[2] size = [0.1, 0.1];

    this()
    {
        allElements ~= this;
    }

    /// Render element on the screen
    void render()
    {
        import kernel.math;

        immutable uint[2] resolution = globalRenderer.getResolution();

        uint[2] absolutePosition;
        absolutePosition[0] = cast(uint) remap!float(position[0], 0, 1, 0, resolution[0]);
        absolutePosition[1] = cast(uint) remap!float(position[1], 0, 1, 0, resolution[1]);

        uint[2] absoluteSize;
        absoluteSize[0] = cast(uint) remap!float(size[0], 0, 1, 0, resolution[0]);
        absoluteSize[1] = cast(uint) remap!float(size[1], 0, 1, 0, resolution[1]);

        render(absolutePosition, absoluteSize);
    }

    /// Dispose this UI element
    void dispose()
    {
        if(allElements.length == 1)
        {
            allElements = [];
            return;
        }

       for(size_t i = 0; i < allElements.length; i++)
       {
            if(allElements[i] == this)
            {
                if(i == 0)
                {
                    allElements = allElements[1..$];
                    return;
                }
                
                if(i == allElements.length - 1)
                {
                    allElements = allElements[0..i];
                    return;
                }
                
                allElements = allElements[0..i];
                allElements ~= allElements[i + 1..$];
            }
       }
    }

    protected abstract void render(uint[2] absolutePosition, uint[2] absoluteSize);
}

public class UIButton : UIElement
{
    public void delegate()[] onPressed;
    public string text;

    protected override void render(uint[2] absolutePosition, uint[2] absoluteScale)
    {
        immutable Rectangle rect = Rectangle(absolutePosition[0], absolutePosition[1], 
            absoluteScale[0], absoluteScale[1]);

        if(GuiButton(rect, text.ptr))
        {
            foreach (action; onPressed)
            {
                action();
            }
        }
    }
}

public class UpdateUISystem : BaseSystem
{
    protected override void update()
    {
        foreach (element; allElements)
        {
            element.render();
        }
    }
}