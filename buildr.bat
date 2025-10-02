@echo off
dub build --build=release

copy raylib.dll raylibtemp.dll
move raylibtemp.dll ./bin/raylib.dll