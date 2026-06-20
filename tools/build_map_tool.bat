@echo off
REM 编译并运行 map_tool，导出 1001.map 的遮罩和障碍物
REM 需要安装 Visual Studio (cl.exe 在 PATH 里)

cd /d "%~dp0"

REM 编译
cl /nologo /EHsc /Fe:map_tool.exe map_tool.cpp
if errorlevel 1 (
    echo 编译失败，请确认 cl.exe 可用（需从 VS 开发命令提示符运行）
    pause
    exit /b 1
)

REM 运行（示例：导出 1001.map）
if not exist "export" mkdir "export"
map_tool.exe "..\MAP\1001.map" "export"
echo.
echo 导出完成！文件在 tools\export\ 下
pause
