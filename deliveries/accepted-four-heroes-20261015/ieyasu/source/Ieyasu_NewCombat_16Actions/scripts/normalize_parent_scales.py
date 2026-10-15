from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil,hashlib
P=Path(__file__).resolve().parents[1]
# Conservative visual head/torso matching; never equalize crouching body bounding boxes.
F={'light_1':[1]*8,'light_2':[1]+[.985]*6+[1],'light_3':[1]+[.975]*8+[1],'heavy':[.985]*10,'charge_ready':[1,1,.98,.98,.98,1],'charge_hold':[1],'charge_release':[1]*12+[.97]*4+[1],'air_light':[1,.985,.985,1,1,1,1,1]}
report=[]
for n,fac in F.items():
 D=P/'actions'/n;B=D/'before_scale_tune'
 if not B.exists():
  B.mkdir()
  for f in D.glob('*'):
   if f.is_file():shutil.copy(f,B/f.name)
 m=json.load(open(B/'metadata.json'));out=[]
 for i,(r,k) in enumerate(zip(m['frames'],fac)):
  root=r.get('root_world',r.get('root_preview'));rx,ry=root
  for kind in ['body_canvas','sword','sheath','composite']:
   source=Image.open(B/f'{kind}_{i:02}.png').convert('RGBA')
   if k!=1:
    source=source.transform(source.size,Image.Transform.AFFINE,(1/k,0,rx-rx/k,0,1/k,ry-ry/k),Image.Resampling.BICUBIC)
   source.save(D/f'{kind}_{i:02}.png')
  for key in ['grip_world','saya_mouth']:
   if key in r:r[key]=[rx+(r[key][0]-rx)*k,ry+(r[key][1]-ry)*k]
  r.update(scale_tune_factor=k,scale_tune_pivot=root,body_scale=r.get('body_scale',1)*k,body_canvas_sha256=hashlib.sha256((D/f'body_canvas_{i:02}.png').read_bytes()).hexdigest())
  comp=Image.open(D/f'composite_{i:02}.png');bg=Image.new('RGB',comp.size,(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);floor=246 if comp.height==280 else 366
  dr.line((0,floor,comp.width,floor),fill=(80,86,93));dr.text((12,10),f'IEYASU 06 {n} / {i+1}/{len(fac)} / scale-tuned',fill='white');out.append(bg)
 ds=[r['duration_ms'] for r in m['frames']]
 for suf,mul in [('normal',1),('slow',3)]:out[0].save(D/f'{n}_{suf}.gif',save_all=True,append_images=out[1:],duration=[x*mul for x in ds],disposal=2,**({'loop':0} if n=='charge_hold' else {}))
 m['scale_tune']='visual head and torso proportion matching, conservative<=3%, root locked; no bbox equal-height';(D/'metadata.json').write_text(json.dumps(m,indent=2));report.append({'action':n,'factors':fac,'method':'visual head/torso reference; not automated bone measurement','fixed_root':True,'unchanged_timing':sum(ds)})
 cs=Image.new('RGB',(out[0].width*4,out[0].height*((len(out)+3)//4)),(47,53,61))
 for i,im in enumerate(out):cs.paste(im,((i%4)*im.width,(i//4)*im.height))
 cs.save(D/'contact_sheet.png')
(P/'SCALE_TUNE_PARENT.json').write_text(json.dumps(report,indent=2))
