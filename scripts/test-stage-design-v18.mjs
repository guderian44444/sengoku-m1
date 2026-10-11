import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import vm from 'node:vm';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const filename=path.join(root,'docs/第一關與24關設計-v0.18.html');
const html=await readFile(filename,'utf8');
const design=JSON.parse(html.match(/<script id="design-data" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const live=JSON.parse(await readFile(path.join(root,'game/data/stage-01-v18.json'),'utf8'));
const source=html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
new vm.Script(source,{filename});
let checks=1;
function check(condition,message){assert(condition,message);checks++;}
check(design.segments.length===10,'First stage has ten segments');
check(live.segments.length===10&&design.faction===live.faction&&design.title===live.title,'Document follows the live ten-segment Imagawa campaign');
const foodNames={rice:'飯糰（35 HP）',fish:'烤魚（50 HP）',dango:'糰子（25 HP）',peach:'桃子（60 HP）'};
for(const [index,segment] of live.segments.entries()){
 const planned=design.segments[index];
 check(planned.id===index+1&&planned.name===segment.name&&planned.theme===segment.theme,'Segment '+(index+1)+' location and theme match live data');
 check(planned.weather_id===segment.weather&&planned.music_id===segment.music,'Segment '+(index+1)+' weather and music match live data');
 check(planned.width===segment.width&&planned.civilians===segment.civilians,'Segment '+(index+1)+' dimensions and civilians match live data');
 assert.deepEqual(planned.wave_kinds,segment.waves,'Segment '+(index+1)+' wave order and enemies match live data');checks++;
 assert.deepEqual(planned.waves,segment.waves.map(w=>w.filter(kind=>kind!=='boss').length),'Segment '+(index+1)+' displayed ordinary counts match live data');checks++;
 check(planned.boss===(segment.boss?.name??'')&&planned.boss_line===(segment.boss?.line??''),'Segment '+(index+1)+' boss and dialogue match live data');
 for(const prop of segment.props)if(prop[3])check(planned.food.includes(foodNames[prop[3]]),'Segment '+(index+1)+' documents the actual food drop '+prop[3]);
}
check(live.segments.reduce((n,s)=>n+s.waves.length,0)===22,'Live campaign has 22 waves');
check(live.segments.flatMap(s=>s.waves).filter(w=>!w.includes('boss')).length===18,'Co-op adds one soldier to 18 ordinary waves');
check(live.segments.filter(s=>s.boss).map(s=>s.name).join('|')===design.segments.filter(s=>s.boss).map(s=>s.name).join('|'),'Boss segments cannot drift between document and game');
check(design.stages.length===24,'All twenty-four existing stages remain');
check(new Set(design.segments.map(s=>s.theme)).size===10,'Each segment has its own area theme');
check(design.segments.reduce((sum,s)=>sum+s.waves.reduce((a,b)=>a+b,0)+(s.reinforcements||0),0)===86,'Wave budget totals 86 ordinary enemies');
check(design.segments.filter(s=>s.boss).map(s=>s.id).join(',')==='3,6,8,10','Three midbosses and one final boss');
check(new Set(design.segments.map(s=>s.music)).size===4,'Four atmosphere loops can span adjoining areas');
check(design.segments[9].boss==='松井宗信'&&design.stages[2][3]==='今川義元','Imagawa Yoshimoto stays in the third stage');
check(design.stages.map(s=>s[0]).join(',')===Array.from({length:24},(_,i)=>i+1).join(','),'Stage IDs preserve original ordering');
check(design.stages[19][4].includes('1577')&&design.stages[22][4].includes('IF'),'Fictional placements retain concise IF labels');
const sourceIds=new Set(design.sources.map(s=>s[0]));
check(sourceIds.size===design.sources.length,'Source IDs must be unique');
for(const stage of design.stages){check(stage[6].length>0&&stage[6].every(id=>sourceIds.has(id)),'Stage '+stage[0]+' has resolvable history references');}
for(const entry of design.sources){const url=new URL(entry[2]);check(url.protocol==='https:','Source links use HTTPS');}
check(html.includes('沒有證明 Saturn')&&html.includes('不是原作的實測數值'),'No invented Saturn timing or segment count');
check(html.includes('最大遊戲顯示尺寸不可超過')&&html.includes('保留其傳說性質'),'Art and historical acceptance are explicit');

// Exercise the page's own trust boundary, with the exact fields rendered by the document.
const fieldMap=new Map();
for(const segment of design.segments)fieldMap.set('segment.'+segment.id,{});
for(const stage of design.stages)fieldMap.set('stage.'+stage[0],{});
for(const match of html.matchAll(/data-review="([^"]+)"/g))fieldMap.set('section.'+match[1],{});
check(fieldMap.size===40,'Ten segment, twenty-four stage and six section comments');
const validate=vm.runInNewContext(source.slice(source.indexOf('function validate('),source.indexOf('function collect('))+'\nvalidate',{design,fieldMap});
const record=comments=>({format:design.format,comments});
const valid=record({'segment.1':'第一段太短，想加一波','stage.23':'優先選原創追兵與服部支援'});
check(validate(valid)===valid,'Valid comments survive without changing content');
for(const invalid of [null,{},record([]),record({'unknown':'a'}),record({'segment.1':123}),record({'segment.1':'a'.repeat(5001)}),record({'__proto__.polluted':'yes'}),{format:'other',comments:{}}]){assert.throws(()=>validate(invalid));checks++;}
check(validate(record({'segment.1':'<img src=x onerror=alert(1)>'})).comments['segment.1'].startsWith('<img'),'Literal user text remains literal');
check(source.includes('field.value=record.comments[field.dataset.field]'),'Comments are restored into values, never HTML');
check(source.includes('if(loadFailed)')&&source.includes('未覆寫'),'Corrupt or inaccessible saved data is never silently overwritten');
check(source.includes('localStorage.setItem')&&source.includes('URL.revokeObjectURL'),'Local persistence and export URL cleanup are present');
console.log(`PASS: ${checks} stage-design checks; archived v18 JSON aligned, 10 segments, 22 waves, 24 stages, 90 solo / 108 co-op enemies, 40 comment fields. Static/document checks only; native gameplay, duration and listening remain separate.`);
