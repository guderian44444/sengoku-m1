from PIL import Image,ImageDraw
from pathlib import Path
import math,json,hashlib
import numpy as np
from scipy.ndimage import label,binary_dilation
P=Path(__file__).resolve().parents[1];import sys
name=sys.argv[1];D=P/('actions/'+name);D.mkdir(exist_ok=True)
im=Image.open(P/('actions/'+name+'_source.png')).convert('RGBA');sw=Image.open(P/'reference/tachi.png').convert('RGBA');sa=Image.open(P/'reference/saya.png').convert('RGBA');W,H=520,280
# Cell-local landmark coordinates, measured from actual artwork. Constant world scale, support feet relocked after transform.
CFG={
'light_2':dict(cols=4,n=8,ruler=438,hands=[(255,195),(175,65),(370,175),(411,140),(360,272),(344,193),(260,202),(255,195)],roots=[(333,429),(373,435),(353,435),(393,435),(375,435),(377,435),(344,435),(333,429)],angles=[-55,-40,55,90,110,115,-35,-55],ds=[90,110,70,70,100,100,100,120]),
'light_3':dict(cols=5,n=10,ruler=382,hands=[(175,190),(105,52),(82,35),(285,228),(342,252),(382,245),(420,257),(244,185),(181,185),(175,190)],roots=[(258,383),(320,383),(300,383),(290,383),(360,383),(389,383),(420,383),(365,383),(350,383),(258,383)],angles=[-55,-60,-25,75,95,105,100,70,10,-55],ds=[100,120,100,60,60,80,100,100,120,160])}
cfg=CFG[name];n=cfg['n'];cols=cfg['cols'];hands=cfg['hands'];roots=cfg['roots'];angles=cfg['angles'];ds=cfg['ds'];ss=152/cfg['ruler'];xs=[180,180]+[190+min(i-2,2)*8 for i in range(2,n)]
if name=='light_3': xs=[180,180,190,225,255,270,275,275,275,275]
arr=np.asarray(im);labs,k=label(arr[:,:,3]>30);sizes=np.bincount(labs.ravel());ids=np.argsort(sizes[1:])[-n:]+1
parts=[]
for q in ids:
 yy,xx=np.where(labs==q);parts.append((int(yy.min()>im.height*.45),float(xx.mean()),int(q)))
parts.sort();ids=[x[2] for x in parts]
frames=[];records=[]
def weapon(src,anchor,point,angle,scale):
 t=math.radians(angle);c=math.cos(t)/scale;s=math.sin(t)/scale;gx,gy=point;ax,ay=anchor
 return src.transform((W,H),Image.Transform.AFFINE,(c,s,ax-c*gx-s*gy,-s,c,ay+s*gx-c*gy),Image.Resampling.BICUBIC)
for i in range(n):
 j=0 if i==n-1 else i;x0=round((j%cols)*im.width/cols);x1=round((j%cols+1)*im.width/cols);y0=round((j//cols)*im.height/2);y1=round((j//cols+1)*im.height/2)
 isolated=np.array(arr);mask=binary_dilation(labs==ids[j],iterations=2);isolated[:,:,3]=np.where(mask,isolated[:,:,3],0);body=Image.fromarray(isolated).crop((x0-100,y0,x1+100,y1));scale=ss
 roots[i]=(roots[i][0]+100,roots[i][1]);hands[i]=(hands[i][0]+100,hands[i][1])
 if i in [0,n-1]:
  ready=Image.open(P/'actions/light_1/body_00.png');body=ready;scale=152/416;roots[i]=(340,431);hands[i]=(228,215)
 body.save(D/f'body_{i:02}.png');rx,ry=roots[i];ox=xs[i]-rx*scale;oy=245-ry*scale
 layer=Image.new('RGBA',(W,H));small=body.resize((round(body.width*scale),round(body.height*scale)),Image.Resampling.LANCZOS);layer.alpha_composite(small,(round(ox),round(oy)));layer.save(D/f'body_canvas_{i:02}.png')
 gx,gy=hands[i];point=(ox+gx*scale,oy+gy*scale);sword=weapon(sw,(100,1080),point,angles[i],.085)
 # Sheath anchored at left waist behind body, angle diagonally down-back.
 saya=weapon(sa,(87,22),(ox+(225 if i in [0,n-1] else 325)*scale,oy+220*scale),65,.073);saya.save(D/f'sheath_{i:02}.png');sword.save(D/f'sword_{i:02}.png')
 comp=Image.new('RGBA',(W,H));comp.alpha_composite(saya);comp.alpha_composite(layer);comp.alpha_composite(sword)
 patch=body.crop((gx-13,gy-13,gx+13,gy+13)).resize((round(26*scale),round(26*scale)),Image.Resampling.LANCZOS);comp.alpha_composite(patch,(round(point[0]-13*scale),round(point[1]-13*scale)));comp.save(D/f'composite_{i:02}.png')
 bg=Image.new('RGB',(W,H),(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,246,W,246),fill=(80,86,93));dr.text((12,12),f'IEYASU 06 / {name} / {n} keyframes / {sum(ds)} ms',fill='white');dr.text((12,262),f'{i+1:02}  body + tachi + saya | candidate',fill=(180,190,200));frames.append(bg)
 records.append(dict(frame=i,source_cell=j,source_rect=[x0,y0,x1,y1],support_foot=[rx,ry],root_world=[xs[i],245],body_scale=scale,grip=[gx,gy],blade_angle=angles[i],duration_ms=ds[i],event=('contact_launch' if name=='light_3' else 'contact_push') if i==3 else None))
frames[0].save(D/(name+'_normal.gif'),save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2)
frames[0].save(D/(name+'_slow.gif'),save_all=True,append_images=frames[1:],duration=[d*3 for d in ds],loop=0,disposal=2)
sheet=Image.new('RGB',(W*cols,H*2));[sheet.paste(f,((i%cols)*W,(i//cols)*H)) for i,f in enumerate(frames)];sheet.save(D/'contact_sheet.png')
json.dump(dict(action=name,candidate=True,frames=records,total_ms=sum(ds),source_sha256=hashlib.sha256((P/('actions/'+name+'_source.png')).read_bytes()).hexdigest(),limitations=['whole-body frames; anatomical limb split not done','weapon baseline is candidate; blade perspective variants pending','not native runtime tested']),open(D/'metadata.json','w'),indent=2)
