@echo off
dub build --build=debug

copy raylib.dll raylibtemp.dll
move raylibtemp.dll ./bin/raylib.dll