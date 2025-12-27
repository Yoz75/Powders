module powders.ui;

import kernel.ecs;
import powders.rendering;

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

    bool enabled = true;

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

        immutable int[2] resolution = gameWindow.getWindowResolution();

        int[2] absolutePosition;
        absolutePosition[0] = cast(uint) remap!float(position[0], 0, 1, 0, resolution[0]);
        absolutePosition[1] = cast(uint) remap!float(position[1], 0, 1, 0, resolution[1]);

        int[2] absoluteSize;
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

    protected abstract void render(int[2] absolutePosition, int[2] absoluteSize);
}

public class UIText : UIElement
{
public:
    /// The displayed text
    string text;

    /// Relative font size according to width
    float relativeFontSize = 0.005;
    /// The text's color
    Color color = white;

    protected override void render(int[2] absolutePosition, int[2] absoluteSize)
    {
        import kernel.math;

        immutable auto resolution = gameWindow.getWindowResolution();
        immutable int fontSize = cast(int) remap(relativeFontSize, 0, 1, 0, resolution[0]);
        gameWindow.drawText(text, absolutePosition, fontSize, color);
    }
}

public class UIButton : UIElement
{
    public void delegate()[] onPressed;
    /// Text of the button. That MUST be a NULL TERMINATED string (ray-gui needs that). 
    /// I'll don't fix that because it's an asshole pain
    public string text;

    protected override void render(int[2] absolutePosition, int[2] absoluteScale)
    {        
        if(gameWindow.drawGUIButton(cast(immutable int[2]) absoluteScale, 
            cast(immutable int[2]) absolutePosition, text))
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
            if(element.enabled)
                element.render();
        }
    }
}