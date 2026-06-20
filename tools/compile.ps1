# compile.ps1 - 编译 map2png
$vsPath = "C:\Program Files\Microsoft Visual Studio\2022\Community"
$projPath = "D:\Godot\传梦之路1.5\新建游戏项目"

# 导入 MSVC 环境
pushd $vsPath
cmd /c "VC\Auxiliary\Build\vcvars64.bat && set" | ForEach-Object {
    if ($_ -match '^(.+?)=(.*)$') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
    }
}
popd

# 编译
$cl = "cl.exe"
$src1 = Join-Path $projPath "tools\map2png.cpp"
$src2 = Join-Path $projPath "tools\ujpeg_orig.cpp"
$out = Join-Path $projPath "tools\map2png.exe"
Set-Location $projPath
& $cl /EHsc $src1 $src2 /Fe:$out
Write-Host "EXIT: $LASTEXITCODE"
