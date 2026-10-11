import {spawn} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const godot=path.join(root,'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const out=path.join(root,'artifacts/art-native-v10');
await mkdir(out,{recursive:true});
async function run(name,args){
  const child=spawn(godot,['--path',path.join(root,'game'),...args],{windowsHide:true,stdio:['ignore','pipe','pipe']});
  let log='';
  child.stdout.on('data',data=>log+=data);child.stderr.on('data',data=>log+=data);
  await new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{child.kill();reject(Error(name+' timed out'));},120000);
    child.once('error',error=>{clearTimeout(timer);reject(error);});
    child.once('close',async code=>{
      clearTimeout(timer);await writeFile(path.join(out,name+'.log'),log);
      if(code!==0||/SCRIPT ERROR|Parse Error|ERROR:/.test(log))reject(Error(name+' failed:\n'+log));
      else {console.log(name+': PASS');resolve();}
    });
  });
}
for(const test of ['combat_v10','input_v10','audio_v10','art_v10','render_v10'])
  await run(test,['--headless','--script',`res://tests/test_${test}.gd`,...(['art_v10','render_v10'].includes(test)?['--','--require-v10','--require-factions']:[])]);
if(process.argv.includes('--render'))await run('capture-render',['--audio-driver','Dummy','--script','res://tests/capture_render_v10.gd','--','--output='+path.join(out,'render')]);
console.log('v0.10 automated checks complete. Real DualSense feel and voice listening require human review.');
