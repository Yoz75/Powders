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
    /// Should we process 1 frame of the game or not?
    private bool shouldUpdate1Frame;
    public override void update()
    {
        if(shouldUpdate1Frame && globalGameState == globalGameState.play)
        {
            globalGameState = GameState.pause;
        }

        if(Input.isKeyPressed(Keys.space))
        {
            globalGameState = globalGameState == GameState.play ? GameState.pause : GameState.play;
            shouldUpdate1Frame = false;
        }

        if(Input.isKeyPressed(Keys.f))
        {
            shouldUpdate1Frame = true;
            globalGameState = globalGameState.play;
        }
    }
}