@echo off
dub build --build=debug --parallel

copy raylib.dll raylibtemp.dll
move raylibtemp.dll ./bin/raylib.dll