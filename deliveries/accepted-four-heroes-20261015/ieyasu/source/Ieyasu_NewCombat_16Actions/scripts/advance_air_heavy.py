from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil,hashlib
P=Path(__file__).resolve().parents[1];D=P/'actions/air_heavy';B=D/'before_forward_landing'
if not B.exists():
 B.mkdir()
 for f in D.glob('*'):
  if f.is_file():shutil.copy(f,B/f.name)
m=json.load(open(B/'metadata.json'));dx=[0,6,16,27,38,46,52,52,52,52,52,52];out=[]
for i,r in enumerate(m['frames']):
 for kind in ['body_canvas','sword','sheath','composite']:
  im=Image.open(B/f'{kind}_{i:02}.png');new=Image.new('RGBA',im.size);new.alpha_composite(im,(dx[i],0));new.save(D/f'{kind}_{i:02}.png')
 r['root_world'][0]+=dx[i]
 for key in ['grip_world','saya_mouth']:
  if key in r:r[key][0]+=dx[i]
 r.update(root_forward_offset_px=dx[i],body_canvas_sha256=hashlib.sha256((D/f'body_canvas_{i:02}.png').read_bytes()).hexdigest())
 if r.get('event'):r['event_world_position']=list(r['root_world'])
 comp=Image.open(D/f'composite_{i:02}.png');bg=Image.new('RGB',comp.size,(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,370,560,370),fill=(80,86,93));dr.text((12,10),'IEYASU 06 / air_heavy / 12 frames / 850 ms / forward landing',fill='white');dr.text((12,382),f'{i+1:02} forward {dx[i]}px; landing holds new root',fill=(180,190,200));out.append(bg)
ds=[r['duration_ms'] for r in m['frames']]
for suf,factor in [('normal',1),('slow',3)]:out[0].save(D/f'air_heavy_{suf}.gif',save_all=True,append_images=out[1:],duration=[x*factor for x in ds],disposal=2)
cs=Image.new('RGB',(2240,1200))
for i,im in enumerate(out):cs.paste(im,((i%4)*560,(i//4)*400))
cs.save(D/'contact_sheet.png');m.update(revision='12 poses850ms; jump advances52px, landing root retained through recovery',root_motion={'space':'152px character reference','start_x':205,'landing_x':257,'landing_frame':6,'horizontal_offsets':dx,'no_return_to_start':True},preview_playback='one-shot; final root retained; do not loop reset')
(D/'metadata.json').write_text(json.dumps(m,indent=2))
assert all(m['frames'][i]['root_world'][0]==257 for i in range(6,12));assert sum(ds)==850
