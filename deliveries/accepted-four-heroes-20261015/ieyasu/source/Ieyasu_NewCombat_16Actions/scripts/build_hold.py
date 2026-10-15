from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil,copy
P=Path(__file__).resolve().parents[1];R=P/'actions/charge_ready';H=P/'actions/charge_hold';S=P/'actions/charge_release';H.mkdir(exist_ok=True)
r=json.load(open(R/'metadata.json'));holdrec=copy.deepcopy(r['frames'][-1]);holdrec.update(frame=0,duration_ms=760,event='full_charge_hold')
for kind in ['body','body_canvas','sword','sheath','composite']:shutil.copy(R/f'{kind}_05.png',H/f'{kind}_00.png')
comp=Image.open(H/'composite_00.png');b=Image.new('RGB',comp.size,(47,53,61));b.paste(comp,mask=comp.getchannel('A'));d=ImageDraw.Draw(b);d.line((0,366,560,366),fill=(80,86,93));d.text((12,10),'IEYASU / charge_hold / stable authored pose / 760 ms loop',fill='white');d.text((12,382),'Full charge: feet and grip locked; no artificial jitter',fill=(180,190,200));b.save(H/'charge_hold_normal.gif',duration=760,loop=0);b.save(H/'charge_hold_slow.gif',duration=2280,loop=0);b.save(H/'contact_sheet.png');json.dump(dict(action='charge_hold',candidate=True,unique_source_poses=1,frames=[holdrec],total_ms=760,source='charge_ready final pose, exact shared boundary'),open(H/'metadata.json','w'),indent=2)
