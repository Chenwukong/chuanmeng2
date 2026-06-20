@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cl /EHsc D:\Godot\Project\tools\map2png.cpp D:\Godot\Project\tools\ujpeg_orig.cpp /Fe:D:\Godot\Project\tools\map2png.exe
echo EXIT=%ERRORLEVEL%
