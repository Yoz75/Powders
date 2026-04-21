/// The module, in witch user make particles with their mouse
module powders.particle.creating.spawning;

import kernel.ecs;
import kernel.todo;
import kernel.optional;
import powders.rendering;
import powders.map;
import powders.particle.register;
import powders.particle.loading;
import powders.particle.building;
import powders.ui;
import powders.rendering;
import powders.particle.creating.ui;
import powders.particle.creating.shapes;

mixin TODO!("OK, NOW THAT'S DYNAMIC UI, BUT NOW WE HAVE TO ADD SCROLLING OF BUTTONS");

public class CreateParticleSystem : BaseSystem
{
    enum float[2] categoryButtonSize = [0.05, 0.05];
    enum float[2] categoryButtonsAnchor = [0.93, 0.2];
    enum float[2] categoryButtonsMargin = [0, 0.075];

    enum float[2] typeButtonSize = categoryButtonSize;
    enum float[2] typeButtonsAnchor = [0.93, 0.93];
    enum float[2] typeButtonsMargin = [-0.075, 0];

    package static CreateParticleSystem instance;

    private CategoryButton[] categoryButtons;
    private CategoryButton selectedCategoryButton;
    private SerializedParticleType selectedType;

    private static SerializedParticleType airType;

    private IShape shape;

    public void selectShape(IShape shape)
    {
        this.shape = shape;
    }

    public override void onCreated()
    {
        instance = this;
        airType = getAirType();

        assert(globalLoadedCategories.length > 0, "CreateParticleSystem is being initialized, 
         but loadCategories() still wasn't called!");

        float[2] categoryButtonPosition = categoryButtonsAnchor;

        foreach(i, category; globalLoadedCategories)
        {
            auto categoryButton = new CategoryButton(category.name ~ '\0', categoryButtonPosition, categoryButtonSize);

            // Why so strange? See https://forum.dlang.org/thread/pjrdlgtahzfppoxojxls@forum.dlang.org
            auto categoryHandler = (ctg) 
            { 
                return () 
                {
                    selectedCategoryButton.disable();
                    selectedCategoryButton = ctg;
                    selectedCategoryButton.enable();
                };
            }(categoryButton);

            categoryButton.addOnPressedHandler(categoryHandler);

            float[2] typeButtonPosition = typeButtonsAnchor;
            foreach(type; category.types)
            {
                immutable string name = type.typeID;

                auto typeHandler = (tp)
                {
                    return () 
                    {
                        selectedType = tp;
                    };
                }(type);
                categoryButton.addTypeButton(name, typeButtonPosition, typeButtonSize, type, typeHandler);

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

    protected override void onUpdated()
    {
        mixin TODO!("ADD MOUSE FUNCTIONS TO INPUT AND USE ENUM!");

        auto pos = getPosUnderMouseWithUICheck();
        if(!pos.hasValue) return;

        shape.markBorders(pos.value);
        if(gameWindow.isMouseButtonDown(MouseButtons.left))
        {
            shape.fillAtPosition(pos.value, selectedType);
        }
        else if(gameWindow.isMouseButtonDown(MouseButtons.right))
        {
            shape.deleteAtPos(pos.value);
            shape.fillAtPosition(pos.value, airType);
        }
    }
}

/// Get position of entity on the map under the mouse cursor. This function checks if there is UI under cursor
/// Returns: position of entity under the mouse
private Optional!(int[2]) getPosUnderMouseWithUICheck()
{
    Optional!(int[2]) result;

    int[2] pos = mouse2MapSpritePosition();

    if(pos[0] < 0 || pos[1] < 0)
    {
        result = None();
        return result;
    }

    float[2] mousePos = gameWindow.getMousePosition();
    int[2] intMousePos;
    intMousePos[0] = cast(int) mousePos[0];
    intMousePos[1]= cast(int) mousePos[1];

    if(isUnderUI(intMousePos.screenPos2RelativeScreenPos)) 
    {
        result = None();
        return result;
    }

    result = pos;
    return result;
}