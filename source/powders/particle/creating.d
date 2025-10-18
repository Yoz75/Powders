/// The module, in witch user make particles with their mouse
module powders.particle.creating;

import kernel.ecs;
import kernel.todo;
import powders.input;
import powders.rendering;
import powders.map;
import powders.particle.register;
import powders.particle.loading;
import powders.particle.building;
import powders.ui;

mixin TODO!("STILL REMOVE THIS SHIT AND MAKE GENERIC GUI LIKE IN TPT");

public class CreateParticleSystem : BaseSystem
{
    private SerializedParticleType[] types;
    private size_t selectedTypeIndex;
    
    public override void onCreated()
    {
        types = tryLoadTypes();

        if(types.length <= 0)
        {
            throw new Exception("There is no types in settings!");
        }

        auto nextButton = new UIButton();
        nextButton.text = "next";
        nextButton.size = [0.1, 0.1];
        nextButton.position = [0.89, 0.89];
        nextButton.onPressed ~= &nextType;

        auto prevButton = new UIButton();
        prevButton.text = "prev";
        prevButton.size = [0.1, 0.1];
        prevButton.position = [0.01, 0.89];
        prevButton.onPressed ~= &prevType;
    }

    private void nextType()
    {
        selectedTypeIndex++;
        selectedTypeIndex %= types.length;
    }

    private void prevType()
    {
        selectedTypeIndex--;
        selectedTypeIndex %= types.length;
    }

    protected override void update()
    {
        mixin TODO!("ADD MOUSE FUNCTIONS TO INPUT AND USE ENUM!");
        import raylib;

        if(IsMouseButtonDown(0))
        {
            int[2] pos = mouse2MapSpritePosition();

            if(pos[0] < 0 || pos[1] < 0) return; // So shit, but works

            float[2] mousePos = Input.getMousePosition();
            uint[2] uintPos;
            uintPos[0] = cast(uint) mousePos[0];
            uintPos[1]= cast(uint) mousePos[1];

            if(isUnderUI(uintPos.screenPos2RelativeScreenPos)) return;

            buildParticle(globalMap.getAt(pos), types[selectedTypeIndex]);
        }
        else if(IsMouseButtonDown(1))
        {
            int[2] pos = mouse2MapSpritePosition();

            if(pos[0] < 0 || pos[1] < 0) return; // ditto

            float[2] mousePos = Input.getMousePosition();
            uint[2] uintPos;
            uintPos[0] = cast(uint) mousePos[0];
            uintPos[1]= cast(uint) mousePos[1];

            if(isUnderUI(uintPos.screenPos2RelativeScreenPos)) return;

            destroyParticle(globalMap.getAt(pos));
        }
    }
}