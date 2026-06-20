// write_bat.js
const fs = require('fs');
const path = 'D:/Godot/传梦之路1.5/新建游戏项目/tools/build_map2png.cmd';
const lines = [
  '@echo off',
  'call "C:\\Program Files\\Microsoft Visual Studio\\2022\\Community\\VC\\Auxiliary\\Build\\vcvars64.bat"',
  'D:',
  'cd "D:\\Godot\\传梦之路1.5\\新建游戏项目"',
  'cl /EHsc tools\\map2png.cpp tools\\ujpeg_orig.cpp /Fe:tools\\map2png.exe',
  'echo EXIT=%ERRORLEVEL%',
];
fs.writeFileSync(path, lines.join('\r\n') + '\r\n');
console.log('Written to', path);
