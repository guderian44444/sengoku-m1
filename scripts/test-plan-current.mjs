import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const file = path.join(root, 'docs/第一關與24關設計-v0.19.html');
const html = fs.readFileSync(file, 'utf8');
const design = JSON.parse(html.match(/<script id="design-data" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const stages = fs.readdirSync(path.join(root, 'game/data'))
  .filter(name => /^stage-\d{2}\.json$/.test(name))
  .map(name => JSON.parse(fs.readFileSync(path.join(root, 'game/data', name), 'utf8')))
  .sort((a, b) => a.id - b.id);
assert.equal(stages[0].id, 1, 'First chapter remains the source of the detailed outline');
assert.equal(design.format, 'sengoku-stage-design-v19');
assert(html.includes("const STORAGE_KEY='sengoku-stage-design-v19-comments'"), 'Keep saved review storage compatible');
assert.deepEqual(design.segments.map(s => s.id), [1,2,3,4,5,6,7], 'Keep scene review IDs');
for (const [i, scene] of stages[0].segments.entries()) {
  for (const [key, value] of Object.entries(scene)) assert.deepEqual(design.segments[i][key], value, `First-stage data drift: ${i+1}/${key}`);
}
const waves = stages[0].segments.flatMap(s => s.encounters).flatMap(e => e.waves);
assert.deepEqual(design.totals, {
  scenes:stages[0].segments.length,
  checkpoints:stages[0].segments.reduce((sum,s) => sum+s.encounters.length, 0),
  waves:waves.length,
  solo:waves.reduce((sum,w) => sum+w.length, 0),
  coop:waves.reduce((sum,w) => sum+Math.ceil(w.filter(k => k!=='boss').length*1.5)+w.filter(k => k==='boss').length, 0),
  world_width:stages[0].segments.reduce((sum,s) => sum+s.width, 0),
});
assert.deepEqual(design.current_stages.map(s => s.id), stages.map(s => s.id), 'Current chapter table must match the chapter files, including gaps');
for (const [i, stage] of stages.entries()) {
  const row = design.current_stages[i];
  assert.deepEqual([row.id,row.title,row.year,row.scenes,row.checkpoints], [stage.id,stage.title,stage.year,stage.segments.length,stage.segments.reduce((sum,s) => sum+s.encounters.length, 0)]);
  assert(html.includes(`<td>${row.id} · ${row.title}<br>${row.year}</td><td>${row.scenes}／${row.checkpoints}</td>`), 'Rendered table matches embedded data');
  assert(typeof row.status === 'string' && row.status.length > 0 && !row.status.includes('尚未實作'), 'Chapter data does not imply final acceptance, but its status must be explicit');
  assert(html.includes(`<td>${row.note}</td><td>${row.status}</td>`), 'Rendered status and summary match embedded data');
}
assert.deepEqual(design.stages.map(s => s[0]), Array.from({length:24}, (_, i) => i+1));
assert.equal(design.stages[4][2], stages[4].title);
assert(stages.every(stage => design.stages.some(row => row[0] === stage.id)), 'Every chapter belongs to the 24-stage outline');
for (const stage of design.stages) for (const source of stage[6]) assert(design.sources.some(s => s[0]===source), `Missing source ${source}`);
for (const script of html.matchAll(/<script>([\s\S]*?)<\/script>/g)) new vm.Script(script[1]);
for (const match of html.slice(0, html.indexOf('<script')).matchAll(/href="([^"#]+)"/g)) {
  const href = match[1];
  if (/^[a-z]+:/i.test(href)) continue;
  assert(fs.existsSync(path.resolve(path.dirname(file), href)), `Broken document link: ${href}`);
}
assert(!/固定補給|飯糰35HP|玩家最大生命 × [23]/.test(html), 'Do not present obsolete supplies or HP scaling as current');
assert(html.includes('尚未實作') && html.includes('墨俣渡河') && html.includes('2026-10-22'));
for (const section of ['basis','first-overall','rules','boss','acceptance','sources']) assert(html.includes(`data-review="${section}"`), `Keep section review ID: ${section}`);
assert(html.includes("review('checkpoint.'+s.id+'.'+(i+1)") && html.includes("review('segment.'+s.id") && html.includes("review('stage.'+s[0]"), 'Keep checkpoint, scene and chapter comment IDs');
console.log(`CURRENT PLAN PASS: ${design.current_stages.length} chapter files reflected, ${design.stages.length} planned chapters; ${design.totals.solo}/${design.totals.coop} fixed enemies`);
