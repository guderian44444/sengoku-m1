import {spawn} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const game=path.join(root,'game');
const godot=path.join(root,'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const out=path.join(root,'artifacts/art-native-v09');
await mkdir(out,{recursive:true});
async function run(name,exe,args,timeout=120000){
  const child=spawn(exe,args,{cwd:root,windowsHide:true,stdio:['ignore','pipe','pipe']});
  let log='';
  child.stdout.on('data',data=>log+=data); child.stderr.on('data',data=>log+=data);
  await new Promise((resolve,reject)=>{
    const timer=setTimeout(()=>{child.kill();reject(Error(`${name} timed out`));},timeout);
    child.once('error',error=>{clearTimeout(timer);reject(error);});
    child.once('close',async code=>{
      clearTimeout(timer);await writeFile(path.join(out,name+'.log'),log);
      if(code!==0 || /SCRIPT ERROR|Parse Error|ERROR:/.test(log)) reject(Error(name+' failed:\n'+log));
      else {console.log(name+': PASS');resolve();}
    });
  });
}
for(const test of ['combat_v09','input_v09','art_assets','frame_animation','art_integration','render_v06','render_v07','render_v09'])
  await run(test,godot,['--path',game,'--headless','--script',`res://tests/test_${test}.gd`,...(test==='render_v09'?['--','--require-v09']:[])]);
if(process.argv.includes('--render')) await run('render-capture',godot,['--path',game,'--audio-driver','Dummy','--script','res://tests/capture_render_v09.gd','--','--output='+path.join(out,'render')]);
if(process.argv.includes('--movie')){
  const avi=path.join(out,'M1-v09-毛利軍試戰.avi');
  const mp4=path.join(out,'M1-v09-毛利軍試戰.mp4');
  await run('movie-capture',godot,['--path',game,'--audio-driver','Dummy','--write-movie',avi,'--fixed-fps','30','--disable-vsync','--script','res://tests/capture_v09.gd','--','--output='+path.join(out,'training')],240000);
  await run('movie-encode','ffmpeg.exe',['-y','-i',avi,'-t','60','-c:v','libx264','-crf','21','-pix_fmt','yuv420p','-c:a','aac','-movflags','+faststart',mp4]);
}
console.log('v0.9 checks complete. Captured images and video still require visual inspection.');
