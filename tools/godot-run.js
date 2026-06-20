#!/usr/bin/env node
// 通过 godot-mcp 运行项目并抓取输出
const { spawn } = require('child_process');

const GODOT = 'C:\\Users\\qingc\\Desktop\\Godot_v4.6-stable_win64.exe';
const PROJECT = 'D:\\Godot\\传梦之路1.5\\新建游戏项目';
const MCP = ['npx.cmd', '@coding-solo/godot-mcp'];

function rpc(method, params = {}) {
  return new Promise((resolve, reject) => {
    const s = spawn(...MCP, {
      env: { ...process.env, GODOT_PATH: GODOT },
      stdio: ['pipe', 'pipe', 'pipe'],
      shell: true
    });
    let buf = '';
    s.stdout.on('data', d => buf += d.toString());
    s.on('close', () => {
      for (const line of buf.split('\n')) {
        try {
          const r = JSON.parse(line);
          if (r.result) return resolve(r.result);
          if (r.error) return reject(r.error);
        } catch(_) {}
      }
      resolve({ raw: buf.trim() });
    });
    s.stdin.write(JSON.stringify({jsonrpc:'2.0',id:1,method:'tools/call',params:{name:method,arguments:params}}) + '\n');
    s.stdin.end();
  });
}

async function main() {
  const action = process.argv[2] || 'check';

  if (action === 'check') {
    // 只检查语法（单次调用）
    const res = await rpc('get_project_info', { projectPath: PROJECT });
    console.log(JSON.stringify(res, null, 2));
    process.exit(0);
  }

  if (action === 'run') {
    // 保持服务器进程，先 run 再抓输出
    const s = spawn(...MCP, {
      env: { ...process.env, GODOT_PATH: GODOT },
      stdio: ['pipe', 'pipe', 'pipe'],
      shell: true
    });
    let buf = '';
    s.stdout.on('data', d => buf += d.toString());

    function send(method, params = {}) {
      return new Promise(r => {
        const id = Date.now();
        const listener = (data) => {
          try {
            const res = JSON.parse(data);
            if (res.id === id) r(res);
          } catch(_) {}
        };
        s.stdout.on('data', listener);
        s.stdin.write(JSON.stringify({jsonrpc:'2.0',id,method:'tools/call',params:{name:method,arguments:params}}) + '\n');
        setTimeout(() => { s.stdout.removeListener('data', listener); r(null); }, 3000);
      });
    }

    console.log('▶ 启动项目...');
    await send('run_project', { projectPath: PROJECT, flags: [] });

    await new Promise(r => setTimeout(r, 8000));

    console.log('\n▶ 抓取输出...');
    const out = await send('get_debug_output', {});
    console.log(JSON.stringify(out, null, 2));

    console.log('\n▶ 停止...');
    await send('stop_project', {});
    s.kill();
    process.exit(0);
  }
}

main().catch(e => { console.error(e); process.exit(1); });
