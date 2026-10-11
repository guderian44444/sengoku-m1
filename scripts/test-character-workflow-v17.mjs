import assert from 'node:assert/strict';
import { readFile, access, mkdir, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const document = path.join(root, 'docs/人物建構與驗收流程-v0.17.html');
const html = await readFile(document, 'utf8');
const source = html.match(/<script>([\s\S]+?)<\/script>/)[1];
new vm.Script(source, { filename: document });
const data = vm.runInNewContext(source.slice(0, source.indexOf('function statusSelect')) + '\n({FORMAT,STORAGE_KEY,STATUSES,stageIds,moves})');
let checks = 1;
const check = (condition, message) => { assert(condition, message); checks++; };
check(data.stageIds.length === 13 && data.moves.length === 42, 'Twelve stages, one character-specific review and 42 moves');
check(new Set(data.moves.map(row => row[0])).size === 42, 'Move identifiers must be unique');
check(['charge-neutral','charged','charge-up','charged_upper','charge-down','charged_slam','dead','victory','dash_heavy'].every(id=>data.moves.some(row=>row[0]===id)), 'Charge holds, releases and terminal states must be separate');
check(!html.includes('value="pass" selected'), 'New records must not pre-certify acceptance');
check(html.includes('v0.19 規則更新') && html.includes('6 個真正關鍵姿勢可接受') && !html.includes('以每動作 12 張真正重畫為目標'), 'Current workflow accepts six real key poses without a universal twelve-frame target');
const walk = data.moves.find(row => row[0] === 'walk')[3];
check(walk.includes('開→窄→交錯→換腿開→窄→交錯') && walk.includes('固定完整 cycle') && walk.includes('60 tick'), 'Walking preserves both-leg phases and its natural complete cycle');
check(html.includes('既有 12 張素材、個別規格與歷史證據保留') && html.includes('idle 6；walk、run、jump、light1–3、heavy1–2、victory 各 12'), 'Existing hero and Tadakatsu twelve-frame evidence remains intact');
check(source.includes('實際 source 數；cycle／每格 tick；hit tick'), 'Each move records its actual source count and timing rather than a target count');
const ids = [...html.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);
check(ids.length === new Set(ids).size, 'HTML IDs must be unique');
const links = [...html.matchAll(/\bhref="([^"]+)"/g)].map(match=>match[1]);
for (const link of links) {
 if (link.startsWith('#')) check(ids.includes(link.slice(1)), 'Missing section '+link);
 else { await access(path.resolve(path.dirname(document),link)); checks++; }
}

// Exercise imported JSON validation using the page's real validator and declared fields.
const fieldMap = new Map();
for (const match of html.matchAll(/<(?:input|textarea)[^>]+data-field="(meta\.[^"]+)"[^>]+maxlength="(\d+)"/g)) fieldMap.set(match[1], {maxLength:Number(match[2])});
for (const id of data.stageIds) for (const [field,length] of [['status',80],['evidence',1600],['note',5000]]) fieldMap.set('stage.'+id+'.'+field,{maxLength:length});
for (const [id] of data.moves) for(const [field,length] of [['status',80],['evidence',2400]]) fieldMap.set('move.'+id+'.'+field,{maxLength:length});
const validate = vm.runInNewContext(source.slice(source.indexOf('function validate('),source.indexOf('function apply('))+'\nvalidate',{FORMAT:data.FORMAT,STATUSES:data.STATUSES,fieldMap});
const record = fields => ({format:data.FORMAT,fields});
const good = record({'meta.actor':'本多忠勝','meta.reviewer':'測試人員','move.charged_slam.status':'pending','move.charged_slam.evidence':'片段 00:12／第 7 張；待人眼確認'});
check(validate(good)===good, 'Accept valid partial records without auto-accepting moves');
for(const invalid of [null,{},record([]),record({'unknown':'x'}),record({'meta.actor':3}),record({'meta.actor':'x'.repeat(121)}),record({'move.charged_slam.status':'approved'}),record({'__proto__.x':'x'}),{format:'other',fields:{}}]) {
 assert.throws(()=>validate(invalid)); checks++;
}
check(validate(record({'meta.actor':'<img src=x onerror=alert(1)>'})).fields['meta.actor'].startsWith('<img'), 'Literal comments are preserved; the UI applies values, not HTML');
check(source.includes('field.value = record.fields[field.dataset.field]'), 'Imported text must enter input values, not HTML');
check(source.includes('if (loadFailed)') && source.includes('未覆寫'), 'Unreadable saved data must not be silently overwritten');
check(source.includes('file.size>1000000'), 'Import size must be bounded');
check(source.includes('window.confirm'), 'Replacing an existing worksheet requires an explicit local confirmation');
const out = path.join(root,'artifacts/native-v17');
await mkdir(out,{recursive:true});
await writeFile(path.join(out,'workflow-verification.json'),JSON.stringify({pass:true,checks,document:path.relative(root,document),stages:12,character_specific:1,moves:data.moves.length,acceptance:'Static links, script syntax and JSON trust boundary only. Native game, art, audio and hardware remain separate acceptance.'},null,2)+'\n');
console.log(`PASS: ${checks} workflow checks; 12 stages, 1 specific review, 42 moves, linked paths and imported JSON validation`);
