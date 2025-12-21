/// The module, in witch user make particles with their mouse
module powders.particle.creating;

import kernel.ecs;
import kernel.todo;
import powders.rendering;
import powders.map;
import powders.particle.register;
import powders.particle.loading;
import powders.particle.building;
import powders.ui;
import powders.rendering;

mixin TODO!("OK, NOW THAT'S DYNAMIC UI, BUT NOW WE HAVE TO ADD SCROLLING OF BUTTONS");

private CategoryButton selectedCategoryButton;
private SerializedParticleType selectedType;

private class CategoryButton
{
public:
    UIButton self;
    UIButton[] typeButtons;

    this(string name, float[2] position, float[2] size)
    {
        self = new UIButton();
        self.position = position;
        self.size = size;
        self.text = name ~ '\0';

        self.onPressed ~= ()
        {
            selectedCategoryButton.disable();
            selectedCategoryButton = this;
            selectedCategoryButton.enable();
        };
    }

    void addTypeButton(string name, float[2] position, float[2] size, SerializedParticleType type)
    {
        UIButton typeButton = new UIButton();

        typeButton.text = name;
        typeButton.position = position;
        typeButton.size = size;
        typeButton.onPressed ~= ()
        {
            selectedType = type;
        };

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

public class CreateParticleSystem : BaseSystem
{
    enum float[2] categoryButtonSize = [0.05, 0.05];
    enum float[2] categoryButtonsAnchor = [0.93, 0.2];
    enum float[2] categoryButtonsMargin = [0, 0.075];

    enum float[2] typeButtonSize = categoryButtonSize;
    enum float[2] typeButtonsAnchor = [0.93, 0.93];
    enum float[2] typeButtonsMargin = [-0.075, 0];

    private CategoryButton[] categoryButtons;

    public override void onCreated()
    {
        assert(globalLoadedCategories.length > 0, "CreateParticleSystem is being initialized, 
         but loadCategories(0 still wasn't called!)");

        float[2] categoryButtonPosition = categoryButtonsAnchor;

        foreach(i, category; globalLoadedCategories)
        {
            auto categoryButton = new CategoryButton(category.name, categoryButtonPosition, categoryButtonSize);

            float[2] typeButtonPosition = typeButtonsAnchor;
            foreach(type; category.types)
            {
                immutable size_t terminatorIndex = indexOfTerminator(type.typeID);
                immutable size_t lastIndex = terminatorIndex == -1 ? type.typeID.length - 1 : terminatorIndex;

                string name = cast(string) type.typeID[0..lastIndex].dup;
                categoryButton.addTypeButton(name, typeButtonPosition, typeButtonSize, type);

                typeButtonPosition[] += typeButtonsMargin;
            }

            categoryButton.disable();
            categoryButtons ~= categoryButton;
            categoryButtonPosition[] += categoryButtonsMargin[];
        }

        selectedCategoryButton = categoryButtons[0];
        selectedType = globalLoadedCategories[0].types[0];

        selectedCategoryButton.enable;
    }

    protected override void update()
    {
        mixin TODO!("ADD MOUSE FUNCTIONS TO INPUT AND USE ENUM!");

        if(gameWindow.isMouseButtonDown(MouseButtons.left))
        {
            int[2] pos = mouse2MapSpritePosition();

            if(pos[0] < 0 || pos[1] < 0) return; // So shit, but works

            float[2] mousePos = gameWindow.getMousePosition();
            int[2] intPos;
            intPos[0] = cast(int) mousePos[0];
            intPos[1]= cast(int) mousePos[1];

            if(isUnderUI(intPos.screenPos2RelativeScreenPos)) return;

            buildParticle(globalMap.getAt(pos), selectedType);
        }
        else if(gameWindow.isMouseButtonDown(MouseButtons.right))
        {
            int[2] pos = mouse2MapSpritePosition();

            if(pos[0] < 0 || pos[1] < 0) return; // ditto

            float[2] mousePos = gameWindow.getMousePosition();
            int[2] intPos;
            intPos[0] = cast(int) mousePos[0];
            intPos[1]= cast(int) mousePos[1];

            if(isUnderUI(intPos.screenPos2RelativeScreenPos)) return;

            destroyParticle(globalMap.getAt(pos));
        }
    }
}

import powders.particle.basics : ParticleId;
private size_t indexOfTerminator(ParticleId id)
{
    foreach(i, ch; id)
    {
        if(ch == char.init)
        {
            return i;
        }
    }

    return -1;
}