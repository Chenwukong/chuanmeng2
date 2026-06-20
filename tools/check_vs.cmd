@echo off
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat" 2>&1
echo VCVARS_DONE=%ERRORLEVEL%
cl 2>&1 | find "Microsoft"
echo CL_FOUND=%ERRORLEVEL%
