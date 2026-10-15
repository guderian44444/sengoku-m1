from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil,copy
P=Path(__file__).resolve().parents[1];R=P/'actions/charge_ready';H=P/'actions/charge_hold';S=P/'actions/charge_release';H.mkdir(exist_ok=True)
r=json.load(open(R/'metadata.json'));holdrec=copy.deepcopy(r['frames'][-1]);holdrec.update(frame=0,duration_ms=760,event='full_charge_hold')
for kind in ['body','body_canvas','sword','sheath','composite']:shutil.copy(R/f'{kind}_05.png',H/f'{kind}_00.png')
comp=Image.open(H/'composite_00.png');b=Image.new('RGB',comp.size,(47,53,61));b.paste(comp,mask=comp.getchannel('A'));d=ImageDraw.Draw(b);d.line((0,366,560,366),fill=(80,86,93));d.text((12,10),'IEYASU / charge_hold / stable authored pose / 760 ms loop',fill='white');d.text((12,382),'Full charge: feet and grip locked; no artificial jitter',fill=(180,190,200));b.save(H/'charge_hold_normal.gif',duration=760,loop=0);b.save(H/'charge_hold_slow.gif',duration=2280,loop=0);b.save(H/'contact_sheet.png');json.dump(dict(action='charge_hold',candidate=True,unique_source_poses=1,frames=[holdrec],total_ms=760,source='charge_ready final pose, exact shared boundary'),open(H/'metadata.json','w'),indent=2)
# Add exact full-charge boundary before true two-turn sequence.
m=json.load(open(S/'metadata.json'))
if not m.get('hold_boundary_added'):
 for i in range(13,-1,-1):
  for kind in ['body','body_canvas','sword','sheath','composite']:shutil.move(S/f'{kind}_{i:02}.png',S/f'{kind}_{i+1:02}.png')
 for kind in ['body','body_canvas','sword','sheath','composite']:shutil.copy(H/f'{kind}_00.png',S/f'{kind}_00.png')
 for q in m['frames']:q['frame']+=1
 p=copy.deepcopy(holdrec);p.update(frame=0,duration_ms=100,event='release_start',spin_accumulated_deg=None);m['frames']=[p]+m['frames'];m['total_ms']+=100;m['hold_boundary_added']=True
 json.dump(m,open(S/'metadata.json','w'),indent=2)
frames=[]
for i,q in enumerate(m['frames']):
 comp=Image.open(S/f'composite_{i:02}.png');b=Image.new('RGB',comp.size,(47,53,61));b.paste(comp,mask=comp.getchannel('A'));d=ImageDraw.Draw(b);d.line((0,366,560,366),fill=(80,86,93));d.text((12,10),'IEYASU / charge_release / 15 frames / 1300 ms / 720 deg',fill='white');d.text((12,382),f'{i+1:02} waist-height two full turns; projected independent blade',fill=(180,190,200));frames.append(b)
for suffix,scale in [('normal',1),('slow',3)]:frames[0].save(S/f'charge_release_{suffix}.gif',save_all=True,append_images=frames[1:],duration=[q['duration_ms']*scale for q in m['frames']],loop=0,disposal=2)
s=Image.new('RGB',(560*4,400*4),(47,53,61));[s.paste(b,((i%4)*560,(i//4)*400)) for i,b in enumerate(frames)];s.save(S/'contact_sheet.png')
