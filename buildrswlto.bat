@echo off
dub build --build=release-subsystem-windows-lto

copy raylib.dll raylibtemp.dll
move raylibtemp.dll ./bin/raylib.dll