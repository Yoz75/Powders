@echo off
dub build --build=release --parallel

copy raylib.dll raylibtemp.dll
move raylibtemp.dll ./bin/raylib.dll