module powders.particle.creating.ui;

import powders.ui;
import powders.particle.loading;

package class CategoryButton
{
public:
    UIButton self;
    UIButton[] typeButtons;

    this(string name, float[2] position, float[2] size)
    {
        self = new UIButton();
        self.position = position;
        self.size = size;
        self.text = name;
    }

    void addOnPressedHandler(void delegate() handler)
    {
        self.onPressed ~= handler;
    }

    void addTypeButton(string name, float[2] position,
        float[2] size, SerializedParticleType type, void delegate() onPressed)
    {
        UIButton typeButton = new UIButton();

        typeButton.text = name ~ '\0';
        typeButton.position = position;
        typeButton.size = size;
        typeButton.onPressed ~= onPressed;

        typeButtons ~= typeButton;
    }

    void enable()
    {
        foreach (typeButton; typeButtons)
        {
            typeButton.enabled = true;
        }
    }

    void disable()
    {
        foreach (typeButton; typeButtons)
        {
            typeButton.enabled = false;
        }
    }
}