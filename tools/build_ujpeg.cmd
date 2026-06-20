@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cd /d "D:\Godot\传梦之路1.5\新建游戏项目"
cl /I. /EHsc tools\map2png.cpp tools\ujpeg_orig.cpp /Fe:tools\map2png.exe
echo Exit code: %ERRORLEVEL%
