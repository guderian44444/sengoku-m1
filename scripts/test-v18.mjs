import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = path.join(root, 'artifacts/native-v18');
const engine = process.env.GODOT_BIN || path.join(root, 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const results = [];
await mkdir(out, { recursive: true });
const filter = log => log.replace(/ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:\d+\)\s*/g, '');
assert(/ERROR:/.test(filter('ERROR: Missing stage data')));

async function run(name, args, timeout = 240000) {
  const started = Date.now();
  let log = '', timedOut = false;
  const child = spawn(engine, ['--path', path.join(root, 'game'), '--log-file', path.join(out, name + '-engine.log'), ...args], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  child.stdout.on('data', data => log += data);
  child.stderr.on('data', data => log += data);
  const code = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { timedOut = true; child.kill(); }, timeout);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', code => { clearTimeout(timer); resolve(code); });
  });
  await writeFile(path.join(out, name + '.log'), log);
  const ok = !timedOut && code === 0 && !/SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|FAILED/.test(filter(log)) && /PASS|\d+ checks, 0 failures/.test(log);
  results.push({ name, ok, exitCode: code, timedOut, seconds: (Date.now() - started) / 1000 });
  await writeFile(path.join(out, 'results-v18.json'), JSON.stringify(results, null, 2) + '\n');
  assert(ok, `${name} failed: ${path.join(out, name + '.log')}\n${filter(log).split(/\r?\n/).filter(line => /ERROR|failed|failures/.test(line)).slice(-12).join('\n')}`);
  console.log(`${name}: PASS`);
}

for (const name of ['stage_v18', 'knockdown_v18', 'stage_playthrough_v18', 'battle', 'wire', 'combat_v10', 'combat_v13', 'combat_v14', 'combo_movement_v12', 'tadakatsu_combat_v17', 'stage_music_v18', 'stage_art_v18', 'stage_integration_v18', 'render_v13', 'parallax_v11', 'tadakatsu_render_v17', 'victory_integration_v15', 'local_coop_startup']) {
  const flags = name === 'tadakatsu_render_v17' ? ['--', '--require-v17'] : name === 'local_coop_startup' ? ['--', '--local-coop'] : [];
  await run(name, ['--headless', '--script', `res://tests/test_${name}.gd`, ...flags]);
}
if (process.argv.includes('--render')) await run('capture-stage-v18', ['--audio-driver', 'Dummy', '--script', 'res://tests/capture_stage_v18.gd'], 360000);
console.log(`PASS: ${results.length} native checks. Endurance playthrough uses synthetic inputs and enlarged health; human difficulty, timing, controllers and listening remain separate.`);
