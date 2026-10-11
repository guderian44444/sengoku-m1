import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const file=path.join(root,'docs/武器分層與六格角色製作方案-v0.21.html');
const html=await readFile(file,'utf8');
const script=html.match(/<script>([\s\S]+?)<\/script>/)[1];
new vm.Script(script,{filename:file});
let checks=1;
const check=(result,message)=>{assert(result,message);checks++;};
const ids=[...html.matchAll(/\bid="([^"]+)"/g)].map(match=>match[1]);
check(ids.length===new Set(ids).size,'Duplicate HTML IDs');
for(const match of html.matchAll(/\b(?:href|src)="([^"]+)"/g)){
 const link=match[1];
 if(link.startsWith('#'))check(ids.includes(link.slice(1)),'Missing section '+link);
 else{await access(path.resolve(path.dirname(file),link));checks++;}
}
const inventory=JSON.parse(await readFile(path.join(root,'docs/weapon-layer-inventory-v21.json'),'utf8'));
for(const hero of inventory.heroes){
 check(hero.registered_clips===hero.clips.length,'Inventory clip count mismatch');
 check(hero.registered_frames===hero.clips.reduce((sum,clip)=>sum+clip.registered_frames,0),'Inventory frame count mismatch');
 check(html.includes(`data-hero="${hero.id}" data-clips="${hero.registered_clips}" data-frames="${hero.registered_frames}"`),'HTML inventory drift');
}
const sections=[...html.matchAll(/data-review="([^"]+)"/g)].map(match=>match[1]);
check(sections.length===6&&new Set(sections).size===6,'Six distinct review sections');
const fieldMap=new Map(sections.map(id=>[id,{}]));
const FORMAT='sengoku-weapon-plan-v21-comments';
const validate=vm.runInNewContext(script.slice(script.indexOf('function validate('),script.indexOf('function collect('))+'\nvalidate',{FORMAT,fieldMap});
const record=comments=>({format:FORMAT,comments});
check(validate(record({six:'命中格待播放確認'})).comments.six==='命中格待播放確認','Valid comment changed');
for(const invalid of [null,{},record([]),record({unknown:'x'}),record({six:4}),record({six:'x'.repeat(5001)}),{format:'other',comments:{}}]){
 assert.throws(()=>validate(invalid));checks++;
}
check(script.includes('field.value=record.comments[field.dataset.field]'),'Saved comments must be applied as values');
check(script.includes('if(loadFailed)')&&script.includes('未覆寫'),'Unreadable data must not be overwritten');
check(html.includes('尚未完成外觀換裝')&&html.includes('命中 tick 14、總長 36 tick'),'Proposal must preserve scope and timing');
check(html.includes('頭側立刀雙手握柄')&&html.includes('第一刀逐格下揮、第二反切、第三橫切')&&!html.includes('刀收近腰'),'Nobunaga stance revision must replace forward/waist-ready posture');
check(html.includes('金剛護符吸收 40、玄鐵護符吸收 75、明鏡護符吸收 110'),'Shield proposal matches v21 values');

// Run the actual page script against a small DOM/storage fixture; this is not a browser render.
function pageFixture(saved=null,writeFails=false){
 const inputs=[],nodes=new Map();let stored=saved,writes=0;
 const node=tag=>({tag,dataset:{},value:'',textContent:'',className:'',events:{},append(){},addEventListener(type,handler){this.events[type]=handler;},click(){}});
 for(const id of ['export','print','save-status'])nodes.set(id,node('element'));
 const reviews=sections.map(id=>{const box=node('div');box.dataset.review=id;return box;});
 const document={
  querySelectorAll(selector){return selector==='[data-review]'?reviews:inputs;},
  createElement(tag){const element=node(tag);if(tag==='textarea')inputs.push(element);return element;},
  getElementById(id){return nodes.get(id);}
 };
 const localStorage={getItem(){return stored;},setItem(key,value){if(writeFails)throw new Error('blocked storage');stored=value;writes++;}};
 vm.runInNewContext(script,{document,localStorage,Blob,URL:{createObjectURL(){return 'blob:test';},revokeObjectURL(){}},window:{print(){}},setTimeout(handler){handler();}});
 return {inputs,nodes,read:()=>stored,writes:()=>writes};
}
const blank=pageFixture();
check(blank.inputs.length===6,'Actual page script creates six review inputs');
blank.inputs[3].value='六格重手試點';blank.inputs[3].events.input();
const stored=JSON.parse(blank.read());
check(stored.comments.six==='六格重手試點'&&blank.writes()===1,'Input event must save the correct section');
const reload=pageFixture(blank.read());
check(reload.inputs[3].value==='六格重手試點','Saved review must reload');
const corrupt=pageFixture('invalid JSON');
corrupt.inputs[0].value='新意見';corrupt.inputs[0].events.input();
check(corrupt.writes()===0&&corrupt.read()==='invalid JSON','Corrupt saved review must survive new typing');
check(corrupt.nodes.get('save-status').className==='error','Corrupt storage must be explained');
const blocked=pageFixture(null,true);blocked.inputs[0].events.input();
check(blocked.nodes.get('save-status').className==='error','Write failure must be visible');
const literal=pageFixture(JSON.stringify(record({decision:'<img src=x onerror=alert(1)>'})));
check(literal.inputs[0].value.startsWith('<img'),'User comments remain literal form values');
console.log(`PASS: ${checks} weapon plan checks; links, inventory, script syntax, DOM/storage fixture (not browser layout)`);
