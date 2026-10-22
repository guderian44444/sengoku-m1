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
  'stage07_10', 'stage07_10_art', 'stage07_10_playthrough', 'stage07_10_flow', 'expedition_music',
  'drop_rates', 'oichi_sidekick',
  'stage05_art', 'stage05_combat', 'stage05_reinforcements', 'stage05_natsume', 'stage05_farmers', 'stage05_streaming', 'stage05_audio', 'stage05_playthrough', 'stage05_campaign_flow', 'officer_weapon_fx',
	'charged_invulnerability', 'stage04_rebuild', 'combat_feedback_v42', 'stage04_density', 'stage04_shields', 'campaign_food', 'food_inventory', 'knockback_distance', 'oichi_air_multihit', 'guard_restore', 'light_finisher', 'light_finisher_cadence', 'hideyoshi_blink',
	'stage03_balance_v41',
	'audio_v40',
	'heavy_wave_v39',
	'weapon_audio_v38',
	'combat_tuning_v37',
	'stage03_integration', 'stage03_playthrough',
	'title_music', 'campaign_music', 'music_integration_v14', 'stage03_alarm', 'stage03_alarm_view', 'stage03_objectives', 'stage03_tent', 'stage03_tent_view', 'stage03_yoshimoto', 'stage03_yoshimoto_view',
	'delivery_v36', 'variable_frames_v36',
  'music_v35', 'stage_music_v18', 'stick_sprint_v35', 'victory_integration_v15',
  'runtime_v34', 'balance_v34', 'grounding_v34', 'enemy_smooth_v34',
  'ui_scroll02', 'ui_input_v34', 'ui_theme_v34', 'ui_panels_v34', 'ui_flow_v34', 'ui_language_v34', 'objective_scroll_v34', 'enemy_health_ui_v34', 'menu_pad_v27',
  'current_runtime_v33', 'combat_v33', 'inventory_v28', 'exit_save_v27', 'wire', 'local_coop_startup',
  'stage2_repair_v32', 'boss_reactions_v31', 'shadows_v29', 'menu_inventory_v28',
  'stage_art_v19', 'stage_movement_v19',
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
  await run(name, ['--headless', '--script', `res://tests/test_${name}.gd`, ...flags], name==='stage07_10_playthrough'?420000:240000);
}
if (process.argv.includes('--render-drop-rates')) {
  await run('drop_rates_native', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_drop_rates.gd', '--', '--capture']);
}
if (process.argv.includes('--render-stage3')) {
  await run('stage03_native_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_stage03_integration.gd', '--', '--output=' + path.join(out, 'stage03-captures')], 360000);
}
if (process.argv.includes('--render-barriers-v41')) {
  await run('barriers_v41_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/capture_barriers_v41.gd']);
}
if (process.argv.includes('--render-combat-v37')) {
  await run('combat_tuning_v37_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_combat_tuning_v37.gd']);
}
if (process.argv.includes('--render-heavy-v39')) {
  await run('heavy_wave_v39_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_heavy_wave_v39.gd']);
}
if (process.argv.includes('--render')) {
  for (const name of ['capture_hud_v19', 'capture_stage_scenery_v19', 'capture_stage_v19', 'capture_enemy_walk_v19']) {
    await run(name, ['--windowed', '--audio-driver', 'Dummy', '--script', `res://tests/${name}.gd`], 360000);
  }
  await run('capture_enemy_walk_movie_v19', ['--windowed', '--audio-driver', 'Dummy', '--write-movie', path.join(out, 'enemy-walk-v19.avi'), '--fixed-fps', '60', '--script', 'res://tests/capture_enemy_walk_v19.gd', '--', '--movie-only'], 360000);
}
if (process.argv.includes('--render-ui-v34')) {
  await run('ui_flow_v34_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_ui_flow_v34.gd', '--', '--capture']);
  await run('objective_scroll_v34_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_objective_scroll_v34.gd', '--', '--capture']);
  await run('enemy_health_ui_v34_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_enemy_health_ui_v34.gd', '--', '--capture']);
}
if (process.argv.includes('--render-combat-v33')) {
  await run('combat_v33_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_combat_v33.gd']);
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
if (process.argv.includes('--render-audio-v40')) {
  await run('title_music_native', ['--windowed', '--audio-driver', 'WASAPI', '--script', 'res://tests/test_title_music.gd', '--', '--natural']);
  await run('ui_scroll02_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_ui_scroll02.gd', '--', '--capture']);
}
if (process.argv.includes('--render-stage05')) {
  await run('stage05_main_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/play_stage05.gd', '--', '--coop', '--review-dir=' + path.join(out, 'stage05-native')]);
  await run('officer_fx_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_officer_weapon_fx.gd', '--', '--capture-dir=' + path.join(out, 'officer-native')]);
}
if (process.argv.includes('--render-stage05-flow')) {
  await run('stage05_campaign_flow_capture', ['--windowed', '--audio-driver', 'Dummy', '--script', 'res://tests/test_stage05_campaign_flow.gd', '--', '--capture-dir=' + path.join(out, 'campaign-flow-native')]);
}
const failed = results.filter(result => !result.ok);
console.log(`${failed.length ? 'FAIL' : 'PASS'}: ${results.length} selected native groups; ${failed.length} failed. ${skipped.length} groups excluded by the supplied selection flags.`);
console.log(`Report: ${path.join(out, historyName)}`);
console.log('Synthetic inputs and native renderer checks only; physical controllers, display-mode feel, remote networking and real listening remain separate acceptance.');
if (failed.length) process.exitCode = 1;
