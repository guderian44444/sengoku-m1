import { spawn } from 'node:child_process';
import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import assert from 'node:assert/strict';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const godot = path.join(root, 'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const game = path.join(root, 'game');
const out = path.join(root, 'artifacts/art-native-v07');
await mkdir(out, { recursive: true });
async function run(name, executable, args, timeout = 30000) {
  const child = spawn(executable, args, { windowsHide: true, stdio: ['ignore','pipe','pipe'] });
  let log = '';
  child.stdout.on('data', b => log += b); child.stderr.on('data', b => log += b);
  return new Promise((resolve, reject) => {
    const timer = setTimeout(async () => {child.kill(); await writeFile(path.join(out,name+'.log'),log); reject(Error(name+' timed out:\n'+log));}, timeout);
    child.on('error', e => {clearTimeout(timer);reject(e);});
    child.on('close', async code => {
      clearTimeout(timer); await writeFile(path.join(out,name+'.log'),log);
      if(code !== 0 || /SCRIPT ERROR|Parse Error|ERROR:/.test(log)) reject(Error(name+' failed:\n'+log));
      else resolve(log);
    });
  });
}
for(const name of ['art_demo','art_assets','frame_animation','art_integration','render_v06','render_v07']) {
  await run(name,godot,['--path',game,'--headless','--script','res://tests/test_'+name+'.gd',...(name.startsWith('render_') ? ['--','--require-'+name.slice(7)] : [])]);
}
for(const face of ['right','left']) {
  const folder = path.join(out,face);
  const report = path.join(out,face+'.json');
  await mkdir(folder,{recursive:true});
  await run('capture-'+face,godot,['--path',game,'--audio-driver','Dummy','--','--art-demo',...(face==='left'?['--art-facing-left']:[]),'--art-capture-dir='+folder,'--report='+report]);
  const result = JSON.parse(await readFile(report,'utf8'));
  assert.equal(result.ok,true); assert.equal(result.poses,10); assert.equal(result.heroes,2);
  for(let i=1;i<=10;i++) assert.ok((await readFile(path.join(folder,`pose-${String(i).padStart(2,'0')}.png`))).length>10000);
}
if(process.argv.includes('--frames')) {
  await run('animation-frames',godot,['--path',game,'--audio-driver','Dummy','--script','res://tests/capture_animation.gd','--','--output='+path.join(out,'frames')],120000);
  assert.equal(JSON.parse(await readFile(path.join(out,'frames/frames.json'),'utf8')).length,47);
}
if(process.argv.includes('--movie')) {
  const avi=path.join(out,'M1-素材循環.avi');
  const mp4=path.join(out,'M1-素材循環.mp4');
  await run('movie-capture',godot,['--path',game,'--audio-driver','Dummy','--write-movie',avi,'--fixed-fps','30','--disable-vsync','--quit-after','720','--','--art-demo'],120000);
  await run('movie-encode','ffmpeg.exe',['-y','-i',avi,'-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart','-an',mp4],120000);
  assert.ok((await readFile(mp4)).length>100000);
  const trainingAvi=path.join(out,'M1-鍵盤練習場.avi');
  const trainingMp4=path.join(out,'M1-鍵盤練習場.mp4');
  await run('v07-capture',godot,['--path',game,'--audio-driver','Dummy','--write-movie',trainingAvi,'--fixed-fps','30','--disable-vsync','--script','res://tests/capture_v07.gd','--','--output='+path.join(out,'training')],120000);
  await run('v07-encode','ffmpeg.exe',['-y','-i',trainingAvi,'-t','36','-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-movflags','+faststart',trainingMp4],60000);
}
if(process.argv.includes('--legacy-movies')) {
  const comboAvi=path.join(out,'M1-連段對照.avi');
  const comboMp4=path.join(out,'M1-連段對照.mp4');
  await run('combo-capture',godot,['--path',game,'--audio-driver','Dummy','--write-movie',comboAvi,'--fixed-fps','30','--disable-vsync','--script','res://tests/capture_combo.gd'],60000);
  await run('combo-encode','ffmpeg.exe',['-y','-i',comboAvi,'-t','8','-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-movflags','+faststart','-an',comboMp4],60000);
  const trainingAvi=path.join(out,'M1-v06-鍵盤回歸.avi');
  const trainingMp4=path.join(out,'M1-v06-鍵盤回歸.mp4');
  await run('training-capture',godot,['--path',game,'--audio-driver','Dummy','--write-movie',trainingAvi,'--fixed-fps','30','--disable-vsync','--script','res://tests/capture_training.gd','--','--output='+path.join(out,'training')],120000);
  await run('training-encode','ffmpeg.exe',['-y','-i',trainingAvi,'-t','48','-c:v','libx264','-crf','20','-pix_fmt','yuv420p','-c:a','aac','-movflags','+faststart',trainingMp4],60000);
}
console.log('PASS: isolated demo state, render mapping, all 10 poses × 2 heroes × both facings captured. Screenshots/video still require visual review.');
