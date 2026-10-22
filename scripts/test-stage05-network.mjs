import {spawn} from 'node:child_process';
import {mkdir,writeFile} from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const expedition=process.argv.includes('--stages07-10');
const label=expedition?'STAGE0710_NETWORK_':'STAGE05_NETWORK_';
const script=expedition?'test_stage07_10_network.gd':'test_stage05_network.gd';
const out=process.env.TEST_ARTIFACT_DIR||path.join(root,expedition?'artifacts/stages07-10-network':'artifacts/stage05-network');
await mkdir(out,{recursive:true});
const engine=path.join(root,'tools/godot-4.7.2/Godot_v4.7.2-stable_win64_console.exe');
const children=[];
let ready;
const hostReady=new Promise(resolve=>ready=resolve);
async function peer(name){
  const appdata=path.join(out,name+'-appdata');await mkdir(appdata,{recursive:true});
  const child=spawn(engine,['--headless','--path',path.join(root,'game'),'--log-file',path.join(out,name+'-engine.log'),'--script','res://tests/'+script,'--','--'+name],{windowsHide:true,env:{...process.env,APPDATA:appdata},stdio:['ignore','pipe','pipe']});
  children.push(child);let log='';let error=false;
  const collect=data=>{log+=data.toString();if(log.includes(label+'HOST_READY'))ready();if(/SCRIPT ERROR|Parse Error|Assertion failed/.test(data.toString())){error=true;ready();for(const p of children)p.kill();}};
  child.stdout.on('data',collect);child.stderr.on('data',collect);
  const code=await new Promise((resolve,reject)=>{child.on('error',reject);child.on('close',resolve);});
  await writeFile(path.join(out,name+'.log'),log);
  const clean=log.replace(/ERROR: Failed to read the root certificate store\.\s+at: get_system_ca_certificates \(platform\/windows\/os_windows\.cpp:\d+\)\s*/g,'');
  const ok=code===0&&!error&&!/ERROR:/.test(clean)&&log.includes(label+name.toUpperCase()+'_PASS');
  return {name,ok,code,evidence:log.split(/\r?\n/).filter(l=>l.includes(label)||l.includes('ERROR:'))};
}
const timer=setTimeout(()=>{ready();for(const p of children)p.kill();},120000);
try{
  const host=peer('host');await hostReady;
  const results=await Promise.all([host,peer('client')]);
  await writeFile(path.join(out,'results.json'),JSON.stringify({scope:'two independent Godot processes; ENet loopback; normal Main handshake, input and snapshot handlers; no remote LAN acceptance',results},null,2));
  console.log(JSON.stringify(results,null,2));
  if(results.some(r=>!r.ok))process.exitCode=1;
}finally{clearTimeout(timer);for(const p of children)if(p.exitCode===null)p.kill();}
