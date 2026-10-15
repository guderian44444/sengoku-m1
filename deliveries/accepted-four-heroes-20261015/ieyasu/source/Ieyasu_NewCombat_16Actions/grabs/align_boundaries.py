from pathlib import Path
from PIL import Image,ImageDraw
import json,copy,math
R=Path(__file__).parent;M=json.loads((R/'registration.json').read_text());snap={(n,i):((R/n/f'body_{i:02}.png').read_bytes(),copy.deepcopy(f)) for n,a in M.items() for i,f in enumerate(a['frames'])}
repl={'grab_start':{4:('grab_hold',4),5:('grab_hold',0)},'grab_hold':{5:('grab_hold',0)},'grab_hit_2':{0:('grab_hold',0),5:('grab_hold',0)},'throw_forward':{0:('grab_hold',0)},'throw_reverse':{0:('grab_hold',0),5:('throw_reverse',6),6:('throw_reverse',5)}}
for n,items in repl.items():
 if n not in M:continue
 for i,(src,j) in items.items():
  data,original=snap[(src,j)];f=copy.deepcopy(original);duration=M[n]['frames'][i]['duration_ms'];f.update(frame=i,duration_ms=duration,reused_from={'action':src,'frame':j},source=M[src]['source'],source_sha256=M[src]['source_sha256']);M[n]['frames'][i]=f;(R/n/f'body_{i:02}.png').write_bytes(data)
if 'grab_hit_2' in M:
 M['grab_hit_1']=copy.deepcopy(M['grab_hit_2']);(R/'grab_hit_1').mkdir(exist_ok=True)
 for i in range(6):(R/'grab_hit_1'/f'body_{i:02}.png').write_bytes((R/'grab_hit_2'/f'body_{i:02}.png').read_bytes())
 for n in ['grab_hit_1','grab_hit_2']:
  M[n].update(action_key=n,visual_source_action='grab_hit_2',duration_ms=600,visual_reuse='User selected second-headbutt motion for both separate inputs; all new identity06 pixels.')
  assert sum(f['duration_ms'] for f in M[n]['frames'])==600
for n,a in M.items():
 out=R/n;sheet=Image.new('RGB',(1440,280*math.ceil(a['count']/3)),(78,88,99));d=ImageDraw.Draw(sheet)
 for i in range(a['count']):
  f=Image.open(out/f'body_{i:02}.png');sheet.paste(f,(i%3*480,i//3*280),f);d.text((i%3*480+8,i//3*280+8),f'{n} {i}',fill='white')
 sheet.resize((960,187*math.ceil(a['count']/3))).save(out/'contact_body.jpg')
(R/'registration.json').write_text(json.dumps(M,indent=2))
