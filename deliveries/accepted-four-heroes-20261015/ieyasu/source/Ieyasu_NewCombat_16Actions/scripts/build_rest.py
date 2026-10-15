from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
import numpy as np, math,json,hashlib,shutil
from pathlib import Path
P=Path(__file__).resolve().parents[1];W,H=560,400
CFG={
'heavy':dict(src='0c3fb3c9-7ce0-4fdc-8467-9811ddcf87c7',n=10,rows=2,cols=5,ruler=382,hands=[(207,185),(608,188),(993,134),(1383,122),(1952,100),(452,502),(885,503),(1048,550),(1432,576),(1810,577)],feet=[(280,383),(685,383),(1100,383),(1495,383),(1900,383),(375,765),(765,765),(1180,765),(1510,765),(1890,765)],angles=[90,90,60,65,90,90,90,90,50,45],ds=[130,170,100,100,70,70,90,110,140,160],xs=[150,150,150,155,185,220,260,275,275,275],events={4:'thrust_start',5:'pass_through_contact',7:'brake'},saya_hands=[(240,175),(640,190),(1040,185),(1440,185),(1835,185),(294,581),(690,581),(1110,577),(1480,565),(1850,565)]),
'charge_ready':dict(src='56003a97-c54e-4ded-a956-586bd9cf1e5c',n=6,rows=2,cols=3,ruler=495,hands=[(240,219),(668,226),(1187,265),(151,750),(665,750),(1195,752)],feet=[(370,505),(932,505),(1480,505),(470,990),(970,990),(1485,990)],angles=[-55,-70,-85,-100,-100,-100],ds=[100,100,110,110,120,130],events={0:'charge_start',5:'hold_enter'}),
'charge_release':dict(src='87308d19-f651-479c-83fc-92ae8471d23e',n=8,rows=2,cols=4,ruler=480,hands=[(300,210),(635,219),(1120,183),(1235,180),(55,685),(713,697),(862,710),(1400,722)],feet=[(330,480),(705,480),(1095,480),(1490,480),(330,985),(700,985),(1100,985),(1490,985)],angles=[90]*8,ds=[120,80,70,70,70,80,70,90,70,70,70,80,100,160],sequence=[0,1,2,3,4,6,0,1,2,3,4,6,0,7],events={2:'spin_contact_1',8:'spin_contact_2',12:'brake'}),
'air_light':dict(src='ca1c2dcc-0472-4973-880d-8ca22250df62',n=8,rows=2,cols=4,ruler=460,hands=[(195,317),(515,105),(936,32),(1427,274),(420,666),(593,750),(938,770),(1338,780)],feet=[(340,500),(680,485),(1070,460),(1470,510),(350,950),(700,980),(1060,980),(1470,980)],angles=[-55,-45,-20,65,90,140,70,-55],ds=[70,90,90,60,70,90,90,100],ys=[265,225,205,210,220,235,255,265],events={1:'takeoff',4:'air_melee_contact',7:'landing'}),
'air_heavy':dict(src='9c2a1e10-9bb8-444e-a57c-4f86d553d8cd',n=9,rows=3,cols=3,ruler=395,hands=[(215,350),(599,25),(1024,25),(290,580),(695,766),(1093,837),(226,1168),(600,1079),(994,1074)],feet=[(375,505),(660,406),(1080,440),(230,870),(795,881),(1190,882),(380,1263),(780,1250),(1160,1262)],angles=[-55,-70,-15,40,110,95,95,85,-55],ds=[80,100,110,70,60,80,90,120,140],ys=[265,220,195,210,240,265,265,265,265],events={1:'takeoff',5:'landing_knockdown',7:'recover'}),
'dash_heavy':dict(src='9e346248-0039-48a5-bfc0-bdf4262a7b3b',n=8,rows=2,cols=4,ruler=460,hands=[(199,230),(520,102),(1010,238),(1512,181),(183,763),(590,776),(975,722),(1329,726)],feet=[(295,465),(705,475),(1050,475),(1490,455),(350,970),(705,970),(1080,970),(1480,970)],angles=[-55,-40,60,90,115,110,70,-55],ds=[70,90,60,60,90,120,140,170],xs=[155,175,195,215,225,230,230,230],events={3:'dash_contact',5:'brake'})}
def transform(src,anchor,point,angle,scale,foreshorten=1):
 t=math.radians(angle);c=math.cos(t);s=math.sin(t);M=np.array([[c*scale,-s*scale*foreshorten],[s*scale,c*scale*foreshorten]]);A=np.linalg.inv(M);b=np.array(anchor)-A@np.array(point);return src.transform((W,H),Image.Transform.AFFINE,tuple([A[0,0],A[0,1],b[0],A[1,0],A[1,1],b[1]]),Image.Resampling.BICUBIC)
def build(name):
 c=CFG[name];D=P/'actions'/name;D.mkdir(exist_ok=True);src=D/'source.png'
 if not src.exists(): shutil.copy(P.parent/'generated_images'/('exec-'+c['src']+'.png'),src)
 im=Image.open(src).convert('RGBA');a=np.array(im);labs,k=label(a[:,:,3]>30);sizes=np.bincount(labs.ravel());ids=np.argsort(sizes[1:])[-c['n']:]+1;objs=[]
 for q in ids:
  y,x=np.where(labs==q);objs.append([int(np.mean(y)//(im.height/c['rows'])),float(np.mean(x)),int(q)])
 objs.sort();ids=[q[2] for q in objs];seq=c.get('sequence',list(range(c['n'])));s=152/c['ruler'];sword=Image.open(P/'reference/tachi.png').convert('RGBA');saya=Image.open(P/'reference/saya.png').convert('RGBA');frames=[];recs=[]
 for i,j in enumerate(seq):
  body=np.array(a);body[:,:,3]=np.where(binary_dilation(labs==ids[j],iterations=2),a[:,:,3],0);ys,xs=np.where(body[:,:,3]>0);box=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));crop=Image.fromarray(body).crop(box);crop.save(D/f'body_{i:02}.png');root=c['feet'][j];ox=c.get('xs',[205]*len(seq))[i]-root[0]*s;oy=100+c.get('ys',[265]*len(seq))[i]-root[1]*s;layer=Image.new('RGBA',(W,H));small=crop.resize((round(crop.width*s),round(crop.height*s)),Image.Resampling.LANCZOS);layer.alpha_composite(small,(round(ox+box[0]*s),round(oy+box[1]*s)));layer.save(D/f'body_canvas_{i:02}.png');gx,gy=c['hands'][j];grip=(ox+gx*s,oy+gy*s)
  # Constant physical blade scale, only perspective length varies for waist-axis spin.
  angle=c['angles'][j];projection=1;behind=False;phase=None;sw=sword.copy()
  if name=='heavy' and i<4:
   frac=[0,0,.30,.7][i];ar=np.array(sw);ar[:max(0,int(955-940*frac)),:,3]=0;sw=Image.fromarray(ar)
  if name=='charge_release':
   phase=min(i*60,720);v=(math.cos(math.radians(phase)),.22*math.sin(math.radians(phase)));projection=max(.18,math.hypot(*v));angle=math.degrees(math.atan2(v[1],v[0]))+90;behind=j in [2,3,4] or math.sin(math.radians(phase))<-.1
  weapon=transform(sw,(100,1080),grip,angle,.085,projection);weapon.save(D/f'sword_{i:02}.png')
  if name=='heavy':mx,my=c['saya_hands'][j];sp=(ox+mx*s,oy+my*s);saangle=90
  else:sp=(ox+(box[0]+crop.width*.50)*s,oy+(box[1]+crop.height*.49)*s);saangle=65
  sheath=transform(saya,(87,22),sp,saangle,.070);sheath.save(D/f'sheath_{i:02}.png');comp=Image.new('RGBA',(W,H));comp.alpha_composite(sheath)
  if behind:comp.alpha_composite(weapon)
  comp.alpha_composite(layer)
  if not behind:comp.alpha_composite(weapon)
  # Foreground grip patch from the character itself.
  pp=Image.fromarray(body).crop((gx-14,gy-14,gx+14,gy+14));pp=pp.resize((max(1,round(28*s)),max(1,round(28*s))),Image.Resampling.LANCZOS);comp.alpha_composite(pp,(round(grip[0]-14*s),round(grip[1]-14*s)));comp.save(D/f'composite_{i:02}.png')
  bg=Image.new('RGB',(W,H),(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,366,W,366),fill=(80,86,93));dr.text((12,10),f'IEYASU / {name} / {len(seq)} frames / {sum(c["ds"])} ms',fill='white');dr.text((12,382),f'{i+1:02} body + tachi + saya | candidate',fill=(180,190,200));frames.append(bg)
  recs.append(dict(frame=i,source_pose=j,source_crop=box,source_grip=[gx,gy],source_foot=root,body_scale=s,root_world=[c.get('xs',[205]*len(seq))[i],100+c.get('ys',[265]*len(seq))[i]],blade_angle_deg=angle,blade_projection=projection,spin_accumulated_deg=phase,weapon_behind=behind,duration_ms=c['ds'][i],event=c['events'].get(i),saya_mouth=list(sp)))
 for suffix,m in [('normal',1),('slow',3)]:frames[0].save(D/f'{name}_{suffix}.gif',save_all=True,append_images=frames[1:],duration=[x*m for x in c['ds']],loop=0,disposal=2)
 cols=4;sheet=Image.new('RGB',(W*cols,H*math.ceil(len(seq)/cols)),(47,53,61));[sheet.paste(f,((i%cols)*W,(i//cols)*H)) for i,f in enumerate(frames)];sheet.save(D/'contact_sheet.png');json.dump(dict(action=name,candidate=True,source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),unique_source_poses=len(set(seq)),frames=recs,total_ms=sum(c['ds']),limitations=['whole-body character frames, not anatomical limb split','visual contact-sheet QA; realtime playback QA pending','not native runtime tested']),open(D/'metadata.json','w'),indent=2)
 return D
if __name__=='__main__':
 import sys
 for name in sys.argv[1:] or CFG:build(name)
