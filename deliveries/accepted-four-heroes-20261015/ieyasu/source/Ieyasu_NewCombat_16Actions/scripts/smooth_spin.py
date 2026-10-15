from pathlib import Path
from PIL import Image,ImageDraw
import json,math,shutil,hashlib
import numpy as np
from scipy.ndimage import label,binary_dilation
from build_rest import transform
P=Path(__file__).resolve().parents[1];D=P/'actions/charge_release';B=D/'before_smooth';old=json.load(open(B/'metadata.json'));sw=Image.open(P/'reference/tachi.png');sa=Image.open(P/'reference/saya.png')
# Coordinates measured on the new full-size source sheets. Right anatomical foot remains pivot.
C={
'right':dict(ruler=670,feet=[(130,680),(744,680),(1300,680),(2070,680)],hands=[(65,175),(850,175),(1395,175),(2060,177)]),
'back':dict(ruler=670,feet=[(415,676),(974,676),(1540,676),(2080,662)],hands=[(522,180),(1081,181),(1636,182),(2155,191)]),
'left':dict(ruler=700,feet=[(486,698),(1005,696),(1504,695),(2075,702)],hands=[(420,303),(875,318),(1280,310),(1744,298)]),
'front':dict(ruler=650,feet=[(95,674),(667,674),(1250,674),(1790,674)],hands=[(105,190),(568,190),(1100,190),(1670,190)])}
seq=[None]+[('right',j) for j in [1,2,3]]+[(n,j) for n in ['back','left','front'] for j in range(4)]+[None];out=[];recs=[];ds=[80]*11+[70]*6
for i,item in enumerate(seq):
 if item is None or i==1:
  saved=1 if i==1 else 0
  for k in ['body','body_canvas','sword','sheath','composite']:shutil.copy(B/f'{k}_{saved:02}.png',D/f'{k}_{i:02}.png')
  r=dict(old['frames'][saved]);r.update(frame=i,duration_ms=ds[i],spin_accumulated_deg=i*22.5,event=None)
 else:
  n,j=item;c=C[n];src=D/'sources'/('smooth_'+n+'.png');a=np.array(Image.open(src).convert('RGBA'));l,num=label(a[:,:,3]>30);sz=np.bincount(l.ravel());qs=np.argsort(sz[1:])[-4:]+1;qs=sorted(qs,key=lambda q:np.where(l==q)[1].mean());ar=a.copy();ar[:,:,3]=np.where(binary_dilation(l==qs[j],iterations=2),a[:,:,3],0);yy,xx=np.where(ar[:,:,3]>0);box=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)];body=Image.fromarray(ar).crop(box);s=152/c['ruler'];rx,ry=c['feet'][j];gx,gy=c['hands'][j];ox=205-rx*s;oy=365-ry*s;layer=Image.new('RGBA',(560,400));layer.alpha_composite(body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS),(round(ox+box[0]*s),round(oy+box[1]*s)));grip=[ox+gx*s,oy+gy*s]
  if n=='left': grip=[[222,252],[210,252],[198,252],[185,252]][j]
  yaw=math.radians(45+i*22.5);vx=-math.cos(yaw);vy=.12*math.sin(yaw);proj=max(.045,math.hypot(vx,vy));angle=math.degrees(math.atan2(vy,vx))+90;weapon=transform(sw,(100,1080),grip,angle,.085,proj);sheath=transform(sa,(87,22),(ox+(box[0]+body.width*.5)*s,oy+(box[1]+body.height*.5)*s),65,.07);behind=n=='left';comp=Image.new('RGBA',(560,400));comp.alpha_composite(sheath)
  if behind:comp.alpha_composite(weapon)
  comp.alpha_composite(layer)
  if not behind:comp.alpha_composite(weapon)
  if not behind:
   patch=Image.fromarray(ar).crop((gx-14,gy-14,gx+14,gy+14)).resize((7,7));comp.alpha_composite(patch,(round(grip[0]-3.5),round(grip[1]-3.5)))
  for k,im in [('body',body),('body_canvas',layer),('sword',weapon),('sheath',sheath),('composite',comp)]:im.save(D/f'{k}_{i:02}.png')
  r=dict(frame=i,source='sources/'+src.name,source_pose=j,source_crop=box,source_grip=[gx,gy],support_foot=[rx,ry],root_world=[205,365],pivot_world=[205,365],body_scale=s,grip_world=grip,blade_angle_deg=angle,blade_projection=proj,weapon_behind=behind,spin_accumulated_deg=i*22.5,duration_ms=ds[i],event='single_spin_contact' if i==8 else None)
 recs.append(r);comp=Image.open(D/f'composite_{i:02}.png');bg=Image.new('RGB',comp.size,(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,366,560,366),fill=(80,86,93));dr.text((12,10),f'IEYASU 06 / single spin revised perspective / {i+1}/17 /1300ms',fill='white');out.append(bg)
for suf,f in [('normal',1),('slow',3)]:out[0].save(D/f'charge_release_{suf}.gif',save_all=True,append_images=out[1:],duration=[d*f for d in ds],disposal=2)
cs=Image.new('RGB',(2240,2000))
for i,im in enumerate(out):cs.paste(im,((i%4)*560,(i//4)*400))
cs.save(D/'contact_sheet.png');old.update(frames=recs,revision='15 interior poses redrawn in ordered quarter-view batches; continuous projected blade axis, far arm occlusion',limitations=['view angles remain artist approximations, not measured 3D rig','contact review only; not runtime validated']);(D/'metadata.json').write_text(json.dumps(old,indent=2));print('grips',[list(map(lambda x:round(x,1),r['grip_world'])) for r in recs])
