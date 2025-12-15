@echo off
dub build --build=release-lto --parallel

copy raylib.dll raylibtemp.dll
move raylibtemp.dll ./bin/raylib.dll