module powders.timecontrol;

import kernel.ecs;
import powders.input;

GameState globalGameState;

public enum GameState
{
    play,
    pause
}

public class TimeControlSystem : BaseSystem
{
    public override void update()
    {
        if(Input.isKeyPressed(Keys.space))
        {
            globalGameState = globalGameState == GameState.play ? GameState.pause : GameState.play;
        }
    }
}