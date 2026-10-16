import { spawn } from 'node:child_process';
import { mkdir, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const out = process.env.TEST_ARTIFACT_DIR || path.join(root, 'artifacts/native-v19');
const engine = process.env.GODOT_BIN || path.join(root, 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const results = [];
await mkdir(out, { recursive: true });
const testAppData = path.join(out, 'appdata');
await mkdir(testAppData, { recursive: true });
const xdgData = path.join(testAppData, 'xdg-data');
const xdgCache = path.join(testAppData, 'xdg-cache');
const xdgConfig = path.join(testAppData, 'xdg-config');
await Promise.all([xdgData,xdgCache,xdgConfig].map(dir => mkdir(dir,{recursive:true})));
// Only the known Windows sandbox CA-store diagnostic is environmental; all other errors fail.
const filter = log => log.replace(/ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:\d+\)\s*/g, '');
assert(!/ERROR:/.test(filter('ERROR: Failed to read the root certificate store.\n   at: get_system_ca_certificates (platform/windows/os_windows.cpp:2582)\n')));
assert(/ERROR:/.test(filter('ERROR: Missing stage data')));
const tests = [
  'stage03_alarm', 'stage03_alarm_view', 'stage03_objectives', 'stage03_tent', 'stage03_tent_view',
  'stage2_repair_v32',
  'departure_v31', 'boss_reactions_v31',
  'talismans_v30', 'heroes_v30', 'voice_v30', 'shared_vfx_v30',
  'oichi_pipeline_v27', 'oichi_layers_v27',
  'stage2_route_v29', 'stage2_combat_v29', 'shadows_v29',
  'inventory_v28', 'menu_inventory_v28', 'balance_v28', 'menu_pad_v27', 'exit_save_v27', 'prone_and_boss_death_v27',
  'collection_progress_v26',
  'weapon_expansion_v24', 'weapons_save_v22', 'loadout_menu_v22', 'weapon_render_v22', 'hero_layers_v22', 'weapon_encyclopedia_v23', 'projectile_v22',
  'progression_v21', 'music_v21', 'engineering_menu_v21', 'render_items_v21',
  'combat_v20', 'audio_v20', 'typography_v20', 'menu_v20',
  'stage_v19', 'stage_movement_v19', 'stage_occlusion_v19', 'knockdown_v18', 'stage_playthrough_v18', 'battle', 'wire', 'training',
  'combat_v06', 'combat_v07', 'combat_v09', 'combat_v10', 'combat_v11', 'combat_v13', 'combat_v14',
  'combo_movement_v12', 'tadakatsu_combat_v17', 'projectile_v12',
  'hud_v19', 'main_ui_v19', 'stage_integration_v19', 'input_v09', 'input_v10', 'input_v11', 'training_integration', 'local_coop_startup',
  'audio_v11', 'audio_v14', 'audio_v15', 'stage_music_v18', 'music_integration_v14',
  'stage_art_v18', 'stage_art_v19', 'enemy_art_v19', 'enemy_walk_v19', 'frame_animation', 'animation_timing_v11', 'special_animation_v11',
  'render_v11', 'render_v12', 'render_v13', 'render_v14', 'tadakatsu_atlas_v17', 'tadakatsu_render_v17',
  'walk_v13', 'strike_v12', 'landing_animation_v12', 'parallax_v11', 'victory_v15', 'victory_integration_v15',
];
const only = process.argv.find(arg => arg.startsWith('--only='))?.slice(7).split(',');
if (only) for (const name of only) assert(tests.includes(name), 'Unknown test: ' + name);
const skipPlaythrough = process.argv.includes('--skip-playthrough');
const selected = tests.filter(name => (!only || only.includes(name)) && !(skipPlaythrough && name === 'stage_playthrough_v18'));
assert(selected.length > 0, 'No tests selected');
const skipped = tests.filter(name => !selected.includes(name));
const reportName = only ? 'results-v19-rerun.json' : 'results-v19.json';
const startedAt = new Date().toISOString();
const historyName = 'results-v19-' + startedAt.replace(/[-:.]/g, '') + '.json';

async function run(name, args, timeout = 240000) {
  const started = Date.now();
  let log = '', timedOut = false, stoppedOnScriptError = false;
  const child = spawn(engine, ['--path', path.join(root, 'game'), '--log-file', path.join(out, name + '-engine.log'), ...args], { windowsHide: true, env: { ...process.env, APPDATA: testAppData, XDG_DATA_HOME:xdgData, XDG_CACHE_HOME:xdgCache, XDG_CONFIG_HOME:xdgConfig }, stdio: ['ignore', 'pipe', 'pipe'] });
  const collect = data => {
    const text = data.toString();
    log += text;
    // An assert in a SceneTree test can leave Godot running forever instead of returning a failing exit code.
    if (/SCRIPT ERROR|Parse Error|Assertion failed/.test(text)) {
      stoppedOnScriptError = true;
      child.kill();
    }
  };
  child.stdout.on('data', collect);
  child.stderr.on('data', collect);
  const code = await new Promise((resolve, reject) => {
    const timer = setTimeout(() => { timedOut = true; child.kill(); }, timeout);
    child.once('error', error => { clearTimeout(timer); reject(error); });
    child.once('close', code => { clearTimeout(timer); resolve(code); });
  });
  await writeFile(path.join(out, name + '.log'), log);
  const clean = filter(log);
  const ok = !timedOut && !stoppedOnScriptError && code === 0 && !/SCRIPT ERROR|Parse Error|ERROR:|Assertion failed|FAILED/.test(clean) && /PASS|\d+ checks, 0 failures/.test(clean);
  results.push({ name, ok, exitCode: code, timedOut, stoppedOnScriptError, seconds: (Date.now() - started) / 1000 });
  const report = JSON.stringify({ startedAt, selected, skipped, results }, null, 2) + '\n';
  await Promise.all([writeFile(path.join(out, reportName), report), writeFile(path.join(out, historyName), report)]);
  console.log(`${name}: ${ok ? 'PASS' : 'FAIL'} (${results.at(-1).seconds.toFixed(1)}s)`);
  if (!ok) {
    const diagnostic = clean.split(/\r?\n/).filter(line => /ERROR|failed|failures|FAILED/.test(line)).slice(-12);
    console.error(diagnostic.map(line => line.length > 600 ? line.slice(0, 600) + '…' : line).join('\n'));
    console.error(`Full diagnostic: ${path.join(out, name + '.log')}`);
  }
}

for (const name of selected) {
  const flags = name === 'weapon_encyclopedia_v23' ? ['--', '--integration']
    : name === 'tadakatsu_render_v17' ? ['--', '--require-v17']
    : name === 'render_v14' ? ['--', '--require-v14']
    : name === 'audio_v15' ? ['--', '--require-v15']
    : name === 'local_coop_startup' ? ['--', '--local-coop'] : [];
  await run(name, ['--headless', '--script', `res://tests/test_${name}.gd`, ...flags]);
}
if (process.argv.includes('--render')) {
  for (const name of ['capture_hud_v19', 'capture_stage_scenery_v19', 'capture_stage_v19', 'capture_enemy_walk_v19']) {
    await run(name, ['--windowed', '--audio-driver', 'Dummy', '--script', `res://tests/${name}.gd`], 360000);
  }
  await run('capture_enemy_walk_movie_v19', ['--windowed', '--audio-driver', 'Dummy', '--write-movie', path.join(out, 'enemy-walk-v19.avi'), '--fixed-fps', '60', '--script', 'res://tests/capture_enemy_walk_v19.gd', '--', '--movie-only'], 360000);
}
if (process.argv.includes('--render-shared-vfx')) {
  await run('shared_vfx_v30_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_shared_vfx_v30.gd', '--', '--capture']);
}
if (process.argv.includes('--render-v20')) {
  await run('menu_v20_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_menu_v20.gd', '--', '--capture-v20']);
  await run('capture_death_v20', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/capture_death_v20.gd']);
}
if (process.argv.includes('--render-v21')) {
  await run('engineering_v21_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_engineering_menu_v21.gd', '--', '--capture-v21']);
  await run('items_v21_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_render_items_v21.gd', '--', '--capture']);
}
if (process.argv.includes('--render-v22')) {
  await run('weapon_render_v22_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_weapon_render_v22.gd']);
  await run('loadout_menu_v22_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_loadout_menu_v22.gd']);
}
if (process.argv.includes('--render-collection-v26')) {
  await run('collection_v26_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_collection_progress_v26.gd', '--', '--capture']);
}
if (process.argv.includes('--render-v28')) {
  await run('menu_inventory_v28_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_menu_inventory_v28.gd', '--', '--capture-v28']);
}
if (process.argv.includes('--render-v29')) {
  await run('capture_stage2_v29', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/capture_stage2_v29.gd']);
}
if (process.argv.includes('--render-stage2-v32')) {
  await run('stage2_repair_v32_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_stage2_repair_v32.gd', '--', '--capture']);
}
if (process.argv.includes('--render-v31')) {
  await run('departure_v31_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_departure_v31.gd', '--', '--capture']);
}
if (process.argv.includes('--render-boss-reactions-v31')) {
  await run('boss_reactions_v31_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_boss_reactions_v31.gd', '--', '--capture']);
}
if (process.argv.includes('--render-heroes-v30')) {
  await run('heroes_v30_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_heroes_v30.gd', '--', '--capture-all', '--output=' + path.join(out, 'hideyoshi-poses')], 360000);
}
if (process.argv.includes('--playthrough-v29')) {
  await run('stage2_playthrough_v29', ['--headless', '--script', 'res://tests/test_stage_playthrough_v18.gd', '--', '--stage2'], 360000);
}
if (process.argv.includes('--render-heroes-v22')) {
  await run('hero_layers_v22_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_hero_layers_v22.gd'], 360000);
}
const failed = results.filter(result => !result.ok);
console.log(`${failed.length ? 'FAIL' : 'PASS'}: ${results.length} selected native groups; ${failed.length} failed. ${skipped.length} groups excluded by the supplied selection flags.`);
console.log(`Report: ${path.join(out, historyName)}`);
console.log('Synthetic inputs and native renderer checks only; physical controllers, display-mode feel, remote networking and real listening remain separate acceptance.');
if (failed.length) process.exitCode = 1;
