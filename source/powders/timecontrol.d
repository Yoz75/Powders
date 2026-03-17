module powders.timecontrol;

import kernel.ecs;
import powders.input;
import powders.rendering;

GameState globalGameState;

/// Pauses system (this mixin just returns from method so use carefully) if `globalGameState` is `GameState.pause`. Should be placed before section, that should be paused.
public enum string PauseIfNeeded = "
{  
    if(globalGameState == GameState.pause)
    {
        return;
    }    
}";

public enum GameState
{
    play,
    pause
}

public class TimeControlSystem : BaseSystem
{
    /// Should we process 1 frame of the game or not?
    private bool shouldUpdate1Frame;
    public override void onUpdated()
    {
        if(shouldUpdate1Frame && globalGameState == globalGameState.play)
        {
            globalGameState = GameState.pause;
        }

        if(gameWindow.isKeyPressed(Keys.space))
        {
            globalGameState = globalGameState == GameState.play ? GameState.pause : GameState.play;
            shouldUpdate1Frame = false;
        }

        if(gameWindow.isKeyPressed(Keys.f))
        {
            shouldUpdate1Frame = true;
            globalGameState = globalGameState.play;
        }
    }
}