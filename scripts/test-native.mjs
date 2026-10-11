import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const godot = path.join(root, 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const game = path.join(root, 'game');
const out = path.join(root, 'artifacts');
await mkdir(out, { recursive: true });
function run(name, args, timeout = 30000) {
  const child = spawn(godot, ['--path', game, ...args], { windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'] });
  let log = '';
  child.stdout.on('data', data => log += data);
  child.stderr.on('data', data => log += data);
  const result = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { child.kill(); reject(new Error(name + ' timed out')); }, timeout);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', async code => {
      clearTimeout(timer);
      await writeFile(path.join(out, name + '.log'), log);
      if (code !== 0 || /SCRIPT ERROR|Parse Error|ERROR:/.test(log)) reject(new Error(name + ' failed:\n' + log));
      else resolve(log);
    });
  });
  result.catch(() => {});
  return { child, result };
}
await run('battle-check', ['--headless', '--script', 'res://tests/test_battle.gd']).result;
await run('wire-check', ['--headless', '--script', 'res://tests/test_wire.gd']).result;
await run('training-check', ['--headless', '--script', 'res://tests/test_training.gd']).result;
await run('combat-v06-check', ['--headless', '--script', 'res://tests/test_combat_v06.gd']).result;
await run('combat-v07-check', ['--headless', '--script', 'res://tests/test_combat_v07.gd']).result;
await run('combat-v09-check', ['--headless', '--script', 'res://tests/test_combat_v09.gd']).result;
await run('combat-v10-check', ['--headless', '--script', 'res://tests/test_combat_v10.gd']).result;
await run('training-input-check', ['--headless', '--script', 'res://tests/test_training_integration.gd']).result;
await run('input-v09-check', ['--headless', '--script', 'res://tests/test_input_v09.gd']).result;
await run('combat-audio-check', ['--headless', '--script', 'res://tests/test_combat_audio.gd']).result;
await run('input-v10-check', ['--headless', '--script', 'res://tests/test_input_v10.gd'], 90000).result;
await run('audio-v10-check', ['--headless', '--script', 'res://tests/test_audio_v10.gd'], 90000).result;
for (const terminal of [false, true]) {
  const label = terminal ? 'terminal' : 'network';
  const extra = terminal ? ['--smoke-terminal'] : [];
  const host = run(label + '-host', ['--headless', '--', '--smoke-host', ...extra, '--report=' + path.join(out, label + '-host.json')]);
  try {
    await new Promise(resolve => setTimeout(resolve, 800));
    const client = run(label + '-client', ['--headless', '--', '--smoke-client', ...extra, '--report=' + path.join(out, label + '-client.json')]);
    try { await Promise.all([host.result, client.result]); }
    finally { if (client.child.exitCode === null) client.child.kill(); }
  } finally { if (host.child.exitCode === null) host.child.kill(); }
  const hostResult = JSON.parse(await readFile(path.join(out, label + '-host.json'), 'utf8'));
  const clientResult = JSON.parse(await readFile(path.join(out, label + '-client.json'), 'utf8'));
  assert.equal(hostResult.ok, true); assert.equal(clientResult.ok, true);
  assert.ok(hostResult.remote_sequence > 0);
  assert.ok(clientResult.snapshots > (terminal ? 0 : 10));
  assert.equal(clientResult.players, 2);
  // Defeated matches still advance existing airborne motion until the actors land.
  if (terminal) { assert.equal(clientResult.phase, 'lost'); assert.ok(clientResult.tick >= 65); }
  console.log(label + ': PASS ' + JSON.stringify({ host: hostResult, client: clientResult }));
}
const introHost = run('intro-network-host', ['--headless', '--script', 'res://tests/test_intro_network_v10.gd', '--', '--intro-host'], 40000);
try {
  await new Promise(resolve => setTimeout(resolve, 800));
  const introClient = run('intro-network-client', ['--headless', '--script', 'res://tests/test_intro_network_v10.gd', '--', '--intro-client'], 40000);
  try { await Promise.all([introHost.result, introClient.result]); }
  finally { if (introClient.child.exitCode === null) introClient.child.kill(); }
} finally { if (introHost.child.exitCode === null) introHost.child.kill(); }
console.log('Reliable boss introduction survives a lost event snapshot: PASS');
if (process.argv.includes('--capture')) {
  await run('native-render', ['--', '--autoplay', '--capture=' + path.join(out, 'm1-prototype.png'), '--report=' + path.join(out, 'native-render.json')]).result;
  const report = JSON.parse(await readFile(path.join(out, 'native-render.json'), 'utf8'));
  assert.equal(report.ok, true);
  console.log('Native rendering: PASS (visual inspection still required).');
}
console.log('PASS: core checks, snapshot validation, two loopback ENet peers and final-state delivery.');

