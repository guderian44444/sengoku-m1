import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const godot = path.join(root, 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const v15 = process.argv.includes('--v15');
const out = path.join(root, 'artifacts', v15 ? 'native-v15' : 'native-v14');
const results = [];
await mkdir(out, { recursive: true });

function testErrors(log) {
  // This sandbox can deny the Windows CA store; loopback ENet and local assets do not use TLS.
  return log.replace(/^ERROR: Failed to read the root certificate store\.\r?\n\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:\d+\)\r?\n/gm, '');
}
assert(!/ERROR:/.test(testErrors('ERROR: Failed to read the root certificate store.\n   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)\n')));
assert(/ERROR:/.test(testErrors('ERROR: Some other certificate or application failure.\n')));

function run(name, args, timeout = 120000) {
  const started = Date.now();
  const child = spawn(godot, ['--path', path.join(root, 'game'), '--log-file', path.join(out, name + '-engine.log'), ...args], {
    windowsHide: true, stdio: ['ignore', 'pipe', 'pipe'],
  });
  let log = '';
  let timedOut = false;
  child.stdout.on('data', data => log += data);
  child.stderr.on('data', data => log += data);
  const result = new Promise((resolve, reject) => {
    const timer = setTimeout(() => { timedOut = true; child.kill(); }, timeout);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', async code => {
      clearTimeout(timer);
      try {
        await writeFile(path.join(out, name + '.log'), log);
        const environmentWarning = testErrors(log) !== log;
        const ok = !timedOut && code === 0 && !/SCRIPT ERROR|Parse Error|ERROR:|Assertion failed/.test(testErrors(log));
        results.push({ name, ok, exitCode: code, timedOut, environmentWarning, seconds: (Date.now() - started) / 1000 });
        await writeFile(path.join(out, 'results.json'), JSON.stringify(results, null, 2) + '\n');
        if (!ok) reject(new Error(`${name} failed${timedOut ? ' (timeout)' : ''}; see ${path.join(out, name + '.log')}\n${log}`));
        else { console.log(name + ': PASS' + (environmentWarning ? ' (Windows certificate-store diagnostic retained in log)' : '')); resolve(log); }
      } catch (error) { reject(error); }
    });
  });
  result.catch(() => {});
  return { child, result };
}

for (const name of [
  'battle', 'wire', 'training', 'combat_v06', 'combat_v07', 'combat_v09', 'combat_v10', 'combat_v11', 'combat_v13', 'combo_movement_v12',
  'training_integration', 'input_v09', 'input_v10', 'input_v11', 'combat_audio', 'audio_v10',
  'art_demo', 'frame_animation', 'animation_timing_v11', 'special_animation_v11', 'art_assets', 'art_integration', 'render_v06', 'render_v07', 'render_v09', 'art_v10', 'render_v10',
]) {
  const flags = ['art_v10', 'render_v10'].includes(name) ? ['--', '--require-v10', '--require-factions']
    : name === 'render_v09' ? ['--', '--require-v09'] : [];
  await run(name, ['--headless', '--script', `res://tests/test_${name}.gd`, ...flags]).result;
}
await run('local_coop_startup', ['--headless', '--script', 'res://tests/test_local_coop_startup.gd', '--', '--local-coop']).result;

async function peers(label, hostArgs, clientArgs) {
  const host = run(label + '-host', hostArgs, v15 ? 120000 : 45000);
  let client;
  try {
    await new Promise(resolve => setTimeout(resolve, 800));
    client = run(label + '-client', clientArgs, v15 ? 120000 : 45000);
    await Promise.all([host.result, client.result]);
  } finally {
    for (const peer of [host, client]) {
      if (peer && peer.child.exitCode === null) peer.child.kill();
    }
    await Promise.allSettled([host.result, ...(client ? [client.result] : [])]);
  }
}

for (const terminal of [false, true]) {
  const label = terminal ? 'terminal' : 'network';
  const extra = terminal ? ['--smoke-terminal'] : [];
  await peers(label,
    ['--headless', '--', '--smoke-host', ...extra, '--report=' + path.join(out, label + '-host.json')],
    ['--headless', '--', '--smoke-client', ...extra, '--report=' + path.join(out, label + '-client.json')]);
  const host = JSON.parse(await readFile(path.join(out, label + '-host.json'), 'utf8'));
  const client = JSON.parse(await readFile(path.join(out, label + '-client.json'), 'utf8'));
  assert.equal(host.ok, true);
  assert.equal(client.ok, true);
  assert.ok(host.remote_sequence > 0);
  assert.ok(client.snapshots > (terminal ? 0 : 10));
  assert.equal(client.players, 2);
  if (terminal) { assert.equal(client.phase, 'lost'); assert.ok(client.tick >= 65); }
}
await peers('intro-network',
  ['--headless', '--script', 'res://tests/test_intro_network_v10.gd', '--', '--intro-host'],
  ['--headless', '--script', 'res://tests/test_intro_network_v10.gd', '--', '--intro-client']);
for (const name of ['audio_v14', 'music_integration_v14', 'combat_v14', 'render_v14']) {
  await run(name, ['--headless', '--script', `res://tests/test_${name}.gd`, ...(name === 'render_v14' ? ['--', '--require-v14'] : [])]).result;
}
await run('audio_v11', ['--headless', '--script', 'res://tests/test_audio_v11.gd']).result;
await run('render_v11', ['--headless', '--script', 'res://tests/test_render_v11.gd']).result;

await run('walk_v13', ['--headless', '--script', 'res://tests/test_walk_v13.gd'], 240000).result;
await run('render_v13', ['--headless', '--script', 'res://tests/test_render_v13.gd']).result;
await run('render_v12', ['--headless', '--script', 'res://tests/test_render_v12.gd']).result;
await run('strike_v12', ['--headless', '--script', 'res://tests/test_strike_v12.gd']).result;
await run('projectile_v12', ['--headless', '--script', 'res://tests/test_projectile_v12.gd']).result;
await run('landing_animation_v12', ['--headless', '--script', 'res://tests/test_landing_animation_v12.gd']).result;
await run('parallax_v11', ['--headless', '--script', 'res://tests/test_parallax_v11.gd']).result;

if (v15) {
  for (const name of ['victory_v15', 'victory_integration_v15', 'audio_v15']) {
    await run(name, ['--headless', '--script', `res://tests/test_${name}.gd`, ...(name === 'audio_v15' ? ['--', '--require-v15'] : [])]).result;
  }
  await peers('victory-network',
    ['--headless', '--script', 'res://tests/test_victory_network_v15.gd', '--', '--victory-host'],
    ['--headless', '--script', 'res://tests/test_victory_network_v15.gd', '--', '--victory-client']);
}

if (process.argv.includes('--render')) {
  await run('capture-board', ['--audio-driver', 'Dummy', '--script', `res://tests/capture_board_${v15 ? 'v15' : 'v14'}.gd`, '--', '--require-v14', '--output=' + path.join(out, 'boards')], 180000).result;
  await run('capture-motion', ['--audio-driver', 'Dummy', '--write-movie', path.join(out, 'motion.avi'), '--fixed-fps', '60', '--disable-vsync', '--script', `res://tests/${v15 ? 'capture_victory_v15' : 'capture_motion_v14'}.gd`, '--', '--require-v14'], 180000).result;
  await run('capture-battle', ['--audio-driver', 'Dummy', '--', '--autoplay', '--capture=' + path.join(out, 'battle.png'), '--report=' + path.join(out, 'battle.json')]).result;
  assert.equal(JSON.parse(await readFile(path.join(out, 'battle.json'), 'utf8')).ok, true);
}
console.log(`PASS: ${results.length} Godot checks; logs and results at ${out}`);
console.log('Synthetic input and loopback ENet only. Physical controller rumble, two-computer networking, visual motion and voice delivery still require review.');

