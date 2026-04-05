# Powders
<img width="1742" height="855" alt="изображение" src="https://github.com/user-attachments/assets/b4e2b4a2-bc1b-4d07-a6b4-18b8a8ed2c09" />

Powders is a simple [TPT](https://github.com/The-Powder-Toy/The-Powder-Toy)-like game. The key feature -- you can add your own types without any coding! 
This game uses Entity-Component-System, you have to modify game's code to add new components, but you can just add a directory and some .json files to build your own particle type from already 
existing components!

## Controls
* WASD or mouse -- move camera
* Mouse wheel -- zoom in\out
* LMB -- spawn a particle
* RMB -- remove a particle
* Currently you can change current spawn type by buttons on screen.
* 1 -- select basic render mode
* 2 -- select temperature render mode
* 3 -- select wire world render mode
* P -- profile the game. Could be buggy and made for non-fullscreen mode when debug

## Branches
* main -- the main branch. Contains last fully made mechanics and MUST be compilable.
* dev -- the development branch. Contains last changes, may be compilable or may not, maybe these features will be added to the release or maybe not.
* temperatureMultithreading -- my experiment of multithreaded temperature (this branch is pretty old, now a compute shader processes the temperature system)
* ecsRework -- an attempt to rework the ECS, some features from this one currently merged into main
* separatedRenderThread -- an experiment of separating rendering to another thread. This implementation doesn't boost fps but boosts problems and spagetty code (I removed separated render thread because it was easier to implement shaders without a separated thread)

## Building
* build.bat -- debug build (very laggy!)
* buildr.bat -- regular release buildr
* buildrsw.bat -- build game without annoying console (only Windows!)
* run.bat -- helper bat file to run game from console
