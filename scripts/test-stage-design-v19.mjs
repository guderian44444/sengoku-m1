import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import vm from 'node:vm';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const filename=path.join(root,'docs/第一關與24關設計-v0.19.html');
const html=await readFile(filename,'utf8');
const design=JSON.parse(html.match(/<script id="design-data" type="application\/json">([\s\S]*?)<\/script>/)[1]);
const live=JSON.parse(await readFile(path.join(root,'game/data/stage-01.json'),'utf8'));
const source=html.match(/<script>\s*([\s\S]*?)<\/script>/)[1];
new vm.Script(source,{filename});
let checks=1;
function check(ok,message){assert(ok,message);checks++;}
function equal(actual,expected,message){assert.deepEqual(actual,expected,message);checks++;}
check(design.format==='sengoku-stage-design-v19','Separate v19 review format');
check(design.title===live.title&&design.faction===live.faction,'Current campaign identity');
equal(design.target_minutes,live.target_minutes,'Duration remains the live design target');
check(design.segments.length===7&&new Set(design.segments.map(s=>s.theme)).size===7,'Seven distinct scenes');
let waveCount=0,checkpointCount=0,solo=0,coop=0;
const officerLocations=[];
for(const [index,segment] of live.segments.entries()){
 const planned=design.segments[index];
 check(planned.id===index+1&&planned.name===segment.name&&planned.theme===segment.theme,'Exact scene names and order');
 for(const key of ['weather','music','width','civilians'])equal(planned[key],segment[key],'Current '+key+' for scene '+(index+1));
 equal(planned.encounters,segment.encounters,'Every checkpoint, wave, boss and dialogue matches live JSON');
 equal(planned.props,segment.props,'Every object, position, food and mandatory flag matches live JSON');
 check(segment.width>=3200&&segment.width<=3800,'Long-scene width range');
 check(segment.encounters.length===2,'Two checkpoints per scene');
 checkpointCount+=segment.encounters.length;
 for(const [checkpoint,encounter] of segment.encounters.entries()){
  check(encounter.waves.length>=2&&encounter.waves.length<=3,'Two or three waves per checkpoint');
  check(encounter.end>(checkpoint?segment.encounters[checkpoint-1].end:0),'Checkpoint exits increase');
  if(encounter.boss)officerLocations.push([index+1,checkpoint+1,encounter.boss.name]);
  for(const wave of encounter.waves){
   const grunts=wave.filter(kind=>kind!=='boss').length,bosses=wave.length-grunts;
   check(bosses<=1,'Unique officer is never duplicated in a base wave');
   solo+=wave.length;coop+=Math.ceil(grunts*1.5)+bosses;waveCount++;
  }
 }
 check(segment.encounters.at(-1).end===segment.width,'Last checkpoint reaches scene end');
}
equal(design.totals,{scenes:7,checkpoints:checkpointCount,waves:waveCount,solo,coop,world_width:live.segments.reduce((n,s)=>n+s.width,0)},'Document totals are computed from live waves');
check(checkpointCount===14&&waveCount===31&&solo===108&&coop===165,'Published scheduled budget excludes timed reinforcements');
equal(officerLocations,[[2,2,'瀨名氏俊'],[4,2,'鵜殿長照'],[6,2,'井伊直盛'],[7,2,'松井宗信']],'Named commanders occupy the intended checkpoints');
check(design.stages.length===24&&design.stages[2][3]==='今川義元','Original 24-stage roster remains');
check(design.stages[19][4].includes('IF')&&design.stages[22][4].includes('IF'),'Concise IF markers survive');
const sourceIds=new Set(design.sources.map(s=>s[0]));
for(const stage of design.stages)check(stage[6].length>0&&stage[6].every(id=>sourceIds.has(id)),'Resolvable background sources for stage '+stage[0]);
check(design.sources.every(entry=>new URL(entry[2]).protocol==='https:'),'Source links use HTTPS');
check(html.includes('每 30 秒')&&html.includes('單人每次 4 人、雙人每次 6 人')&&html.includes('超過 48'),'Recurring reinforcements and queue threshold are explicit');
check(html.includes('不是原作的實測數值')&&html.includes('尚不宣稱全數完成'),'Timing and final-art acceptance boundaries are honest');
check(html.includes('倒地敵人不可再受擊')&&html.includes('起身時會震退'),'Knockdown and officer wake-up behavior is documented');

const fieldMap=new Map();
for(const segment of design.segments){
 fieldMap.set('segment.'+segment.id,{});
 for(const [checkpoint] of segment.encounters.entries())fieldMap.set('checkpoint.'+segment.id+'.'+(checkpoint+1),{});
}
for(const stage of design.stages)fieldMap.set('stage.'+stage[0],{});
for(const match of html.matchAll(/data-review="([^"]+)"/g))fieldMap.set('section.'+match[1],{});
check(fieldMap.size===51,'Seven scene, fourteen checkpoint, twenty-four stage and six section comments');
const validate=vm.runInNewContext(source.slice(source.indexOf('function validate('),source.indexOf('function collect('))+'\nvalidate',{design,fieldMap});
const record=comments=>({format:design.format,comments});
const valid=record({'checkpoint.1.2':'第二據點再加一波？','stage.23':'演義追擊保留'});
check(validate(valid)===valid,'Checkpoint comments survive validation');
for(const invalid of [null,{},record([]),record({'unknown':'x'}),record({'checkpoint.8.1':'x'}),record({'checkpoint.1.1':123}),record({'segment.1':'x'.repeat(5001)}),{format:'sengoku-stage-design-v18',comments:{}}]){assert.throws(()=>validate(invalid));checks++;}
check(source.includes('field.value=record.comments[field.dataset.field]')&&source.includes('if(loadFailed)'),'Comment persistence restores values and protects unreadable old data');
check(source.includes("sengoku-stage-design-v19-comments")&&source.includes('URL.revokeObjectURL'),'Versioned local storage and cleaned-up exports');
console.log(`PASS: ${checks} v19 design checks; 7 scenes, 14 checkpoints, 31 waves, 108 solo / 165 co-op scheduled enemies, 51 comment fields. Timed reinforcements add enemies; runtime playthrough and final visual/audio acceptance remain separate.`);
