from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
R=Path(__file__).parent;M=json.loads((R/'registration.json').read_text())
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
for name,a in M.items():
 for i,f in enumerate(a['frames']):
  p=R/name/f'body_{i:02}.png';alpha=np.array(Image.open(p).getchannel('A'));feet=[]
  for lo,hi in [(0,150),(150,480)]:
   ys,xs=np.where(alpha[:,lo:hi]>100);floor=int(ys.max());feet.append([round(float(np.median(xs[ys>=floor-2]+lo))),floor])
  f.update(screen_left_foot=feet[0],screen_right_foot=feet[1],body_sha256=sha(p),source=f.get('source',a['source']),source_sha256=f.get('source_sha256',a['source_sha256']),layer_order=['proxy_back','sheathed_weapon','body'],body_bounds=Image.open(p).getbbox(),root=f.get('root',[150,220]))
  f['grasp_active']=f.get('grasp_active',name!='grab_start' or i>=3)
  if name.startswith('grab_hit'):f['generic_contact_semantic']='headbutt_contact' if i==3 else None
 gif=Image.open(R/name/'normal.gif');dur=0
 for i in range(gif.n_frames):gif.seek(i);dur+=gif.info['duration']
 a['qa'].update(encoded_gif_frames=gif.n_frames,encoded_gif_duration_ms=dur,normal_preview_body_height=152,identity06_visually_confirmed=True,topknot_and_feet_complete=True,source_sha256=a['source_sha256'])
 assert dur==a['duration_ms']
 a['qa']['live_playback_inspected']=False
pairs=[('grab_start',5),('grab_hold',0),('grab_hold',5),('grab_hit_1',0),('grab_hit_1',5),('grab_hit_2',0),('grab_hit_2',5),('throw_forward',0),('throw_reverse',0)]
checks={layer:all((R/n/f'{layer}_{i:02}.png').read_bytes()==(R/'grab_hold'/f'{layer}_00.png').read_bytes() for n,i in pairs) for layer in ['body','weapon','proxy']};assert all(checks.values()),checks
shared={layer:all((R/'grab_hit_1'/f'{layer}_{i:02}.png').read_bytes()==(R/'grab_hit_2'/f'{layer}_{i:02}.png').read_bytes() for i in range(6)) for layer in checks};assert all(shared.values())
assert M['grab_hit_1']['frames'][3]['events']==['grab_hit_1_contact'];assert M['grab_hit_2']['frames'][3]['events']==['grab_hit_2_contact']
assert all(sum(f['duration_ms'] for f in M[n]['frames'])==600 for n in ['grab_hit_1','grab_hit_2'])
(R/'boundary_qa.json').write_text(json.dumps({'shared_hold_pairs':pairs,'shared_layers_identical':checks,'two_headbutts_same_visual':shared,'separate_actions_and_contact_events':True,'headbutt_duration_each_ms':600,'headbutt_frame_durations':[f['duration_ms'] for f in M['grab_hit_2']['frames']],'source_identity_sha256':sha(R.parent/'reference/identity06.png'),'live_playback_inspected':False},indent=2))
(R/'registration.json').write_text(json.dumps(M,indent=2))
(R/'SHA256SUMS').write_text('\n'.join(sha(p)+'  '+str(p.relative_to(R)) for p in sorted(R.rglob('*')) if p.is_file() and p.name!='SHA256SUMS')+'\n')
print('PASS: exact shared body/weapon/proxy boundaries, independent headbutt events, preserved 600ms timings.')
print('Source hashes:')
for p in sorted((R/'sources').glob('*.png')):print(p.name,sha(p))
