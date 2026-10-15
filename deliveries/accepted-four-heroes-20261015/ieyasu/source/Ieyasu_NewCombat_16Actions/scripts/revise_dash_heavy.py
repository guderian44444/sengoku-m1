from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
from pathlib import Path
import numpy as np,json,hashlib,shutil,math
from build_rest import transform
P=Path(__file__).resolve().parents[1];D=P/'actions/dash_heavy';B=D/'before_10frames'
if not B.exists():
 B.mkdir()
 for p in D.glob('*'):
  if p.is_file():shutil.copy2(p,B/p.name)
old=json.loads((B/'metadata.json').read_text());src=D/'revision_sources/transitions.png';a=np.array(Image.open(src).convert('RGBA'));labs,k=label(a[:,:,3]>30);ids=[i for i,n in enumerate(np.bincount(labs.ravel())) if i and n>3000];ids.sort(key=lambda q:np.where(labs==q)[1].mean())
seq=[0,1,'A',2,3,'B',4,5,6,7];ds=[60,70,50,50,50,50,80,100,130,160]
# source landmarks inserted after visual inspection
new={'A':(0,(513,192),(846,827),185,10),'B':(1,(1492,510),(1685,830),220,102)}
sword=Image.open(P/'reference/tachi.png').convert('RGBA');saya=Image.open(P/'reference/saya.png').convert('RGBA');frames=[];recs=[]
for i,j in enumerate(seq):
 if isinstance(j,int):
  r=dict(old['frames'][j]);r['source_file']='source.png'
  for nm in ['body','body_canvas','sword','sheath','composite']:shutil.copy2(B/f'{nm}_{j:02}.png',D/f'{nm}_{i:02}.png')
  comp=Image.open(D/f'composite_{i:02}.png').convert('RGBA')
 else:
  q,(gx,gy),(fx,fy),rx,angle=new[j];s=152/800;ry=365;aa=a.copy();aa[:,:,3]=np.where(binary_dilation(labs==ids[q],iterations=2),a[:,:,3],0);y,x=np.where(aa[:,:,3]>0);box=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)];crop=Image.fromarray(aa).crop(box);body=Image.new('RGBA',(560,400));small=crop.resize((round(crop.width*s),round(crop.height*s)),Image.Resampling.LANCZOS);body.alpha_composite(small,(round(rx+(box[0]-fx)*s),round(ry+(box[1]-fy)*s)));grip=(rx+(gx-fx)*s,ry+(gy-fy)*s);sp=(rx+(box[0]+crop.width*.5-fx)*s,ry+(box[1]+crop.height*.49-fy)*s);weapon=transform(sword,(100,1080),grip,angle,.085);sheath=transform(saya,(87,22),sp,65,.070);comp=Image.new('RGBA',(560,400));comp.alpha_composite(sheath);comp.alpha_composite(body);comp.alpha_composite(weapon);patch=body.crop((round(grip[0]-4),round(grip[1]-4),round(grip[0]+4),round(grip[1]+4)));comp.alpha_composite(patch,(round(grip[0]-4),round(grip[1]-4)))
  for nm,im in [('body',crop),('body_canvas',body),('sword',weapon),('sheath',sheath),('composite',comp)]:im.save(D/f'{nm}_{i:02}.png')
  r=dict(source_file='revision_sources/transitions.png',source_pose=q,source_crop=box,source_grip=[gx,gy],source_foot=[fx,fy],body_scale=s,root_world=[rx,ry],blade_angle_deg=angle,blade_projection=1,spin_accumulated_deg=None,weapon_behind=False,saya_mouth=list(sp),grip_world=list(grip))
 r.update(frame=i,duration_ms=ds[i],event={4:'dash_contact',7:'brake'}.get(i),body_canvas_sha256=hashlib.sha256((D/f'body_canvas_{i:02}.png').read_bytes()).hexdigest());recs.append(r)
 bg=Image.new('RGB',(560,400),(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,366,560,366),fill=(80,86,93));dr.text((12,10),'IEYASU 06 / dash_heavy / 10 frames / 800 ms',fill='white');dr.text((12,382),f'{i+1:02} body + tachi + saya | revision',fill=(180,190,200));frames.append(bg)
for suff,m in [('normal',1),('slow',3)]:frames[0].save(D/f'dash_heavy_{suff}.gif',save_all=True,append_images=frames[1:],duration=[x*m for x in ds],loop=0,disposal=2)
sheet=Image.new('RGB',(2240,1200),(47,53,61));[sheet.paste(f,((i%4)*560,(i//4)*400)) for i,f in enumerate(frames)];sheet.save(D/'contact_sheet.png');old.update(frames=recs,total_ms=sum(ds),unique_source_poses=10,revision='8 to10 poses: preparation and followthrough inbetweens',new_source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),ruler_px=152);(D/'metadata.json').write_text(json.dumps(old,indent=2));print('frames',len(frames),'ms',sum(ds))
