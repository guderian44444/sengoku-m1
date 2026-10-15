from pathlib import Path
import json,shutil,hashlib
P=Path(__file__).resolve().parents[1];D=P/'actions/charge_release';C=P/'candidates/charge_release_legstep';B=D/'before_legstep'
if not B.exists():
 B.mkdir()
 for f in D.glob('*'):
  if f.is_file():shutil.copy2(f,B/f.name)
m=json.load(open(B/'metadata.json'));q=json.load(open(C/'metadata.json'))
for i,(r,c) in enumerate(zip(m['frames'],q['frames'])):
 for k in ['body_canvas','sword','sheath','composite']:shutil.copy2((B/f'{k}_00.png') if i in [0,16] else (C/f'{k}_{i:02}.png'),D/f'{k}_{i:02}.png')
 dx,dy=c['upper_translation'];r.update(upper_translation=c['upper_translation'],grip_world=c['grip_world'],right_support=c['right_support'],left_sole_estimate=c['left_sole_estimate'],root_world=[205,365],pivot_world=[205,365],legstep_source=c['lower_source'],lower_vertical_registration_scale=c['lower_vertical_registration_scale'],body_canvas_sha256=hashlib.sha256((D/f'body_canvas_{i:02}.png').read_bytes()).hexdigest(),raw_body_file_role='historical source only; body_canvas is current runtime-ready sprite')
 if 'saya_mouth' in r:r['saya_mouth']=[r['saya_mouth'][0]+dx,r['saya_mouth'][1]+dy]
 if r.get('event'):r['event_world_position']=r['grip_world']
m['revision']='20261015_0211_legstep_hands_candidate';m['limitations']=['crossing steps repaired; left-foot step speed remains uneven at pairs2-3,5-6,10-11,14-15','2D projected hand and lower body approximation; not live runtime validated'];m['legstep_qa']=json.load(open(C/'qa.json'))
(D/'metadata.json').write_text(json.dumps(m,indent=2));shutil.copy(C/'normal.gif',D/'charge_release_normal.gif');shutil.copy(C/'slow.gif',D/'charge_release_slow.gif')
