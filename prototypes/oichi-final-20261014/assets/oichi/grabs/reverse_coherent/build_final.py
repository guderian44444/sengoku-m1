from PIL import Image,ImageDraw
from pathlib import Path
from scipy.ndimage import label,find_objects,distance_transform_edt
import numpy as np,json,hashlib
P=Path(__file__).parent
spec={'b':('base_slim.png',8,490),'t':('turn_slim_fix.png',3,690),'e':('end_slim.png',2,940)};sources={}
for key,(file,count,ruler) in spec.items():
 a=np.array(Image.open(P/file).convert('RGBA'));lab,num=label(a[:,:,3]>32);major=[]
 for k,sl in enumerate(find_objects(lab)):
  if np.sum(lab[sl]==k+1)>20000:major.append((k+1,sl))
 major.sort(key=lambda t:((t[1][0].start>500) if key=='b' else 0,t[1][1].start));assert len(major)==count,(file,len(major));core=np.zeros(lab.shape,np.int16)
 for i,(k,sl) in enumerate(major):core[lab==k]=i+1
 idx=distance_transform_edt(core==0,return_distances=False,return_indices=True);own=core[tuple(idx)];total=np.zeros(a.shape[:2],np.uint16)
 for i in range(count):
  b=a.copy();b[:,:,3]=np.where(own==i+1,a[:,:,3],0);total+=b[:,:,3];ys,xs=np.where(b[:,:,3]>0);rect=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];crop=Image.fromarray(b).crop(rect);name=f'{key}{i}.png';crop.save(P/name);sources[key+str(i)]=(name,rect,ruler)
 assert np.array_equal(total,a[:,:,3].astype(np.uint16))
base_hands=[(329,142),(238,111),(241,102),(91,117),(47,44),(26,132),(107,227),(99,220)]
roots={};hands={}
for i,h in enumerate(base_hands):roots[f'b{i}']=[i%4*384+205,i//4*512+495];hands[f'b{i}']=[h[0]+i%4*384,h[1]+i//4*512]
for i,(root,hand) in enumerate(zip([[555,700],[1145,700],[1745,700]],[[637,176],[1160,170],[1560,170]])):roots[f't{i}']=root;hands[f't{i}']=hand
for i,(root,hand) in enumerate(zip([[440,940],[1130,940]],[[120,125],[970,420]])):roots[f'e{i}']=root;hands[f'e{i}']=hand
seq=['b0','t0','b1','t1','b2','b3','t2','b4','e0','b5','b6','e1','b7'];dur=[70,50,70,50,90,70,50,80,50,90,100,50,140];shoulders=[(227,88),(216,89),(205,91),(193,92),(181,93),(176,83),(160,70),(144,56),(132,65),(109,91),(76,137),(65,162),(60,189)];hips=[(230,139),(230,135),(229,131),(228,112),(224,94),(211,55),(183,33),(155,13),(130,17),(91,48),(35,119),(20,150),(15,189)];frames=[];records=[];time=0;bow=Image.open(P.parent/'bow_azusa.png').convert('RGBA');bow.thumbnail((38,120))
for i,key in enumerate(seq):
 name,rect,ruler=sources[key];ruler=880 if key=='e1' else 730 if key=='t2' else ruler;body=Image.open(P/name);s=148/ruler;root=roots[key];off=(round(170+(rect[0]-root[0])*s),round(202+(rect[1]-root[1])*s));hand=(round(170+(hands[key][0]-root[0])*s),round(202+(hands[key][1]-root[1])*s));victim=Image.new('RGBA',(420,260));d=ImageDraw.Draw(victim);sh=np.array(shoulders[i],float);hip=np.array(hips[i],float);u=(hip-sh)/np.linalg.norm(hip-sh);n=np.array([-u[1],u[0]]);head=sh-u*17;d.ellipse((head[0]-8,head[1]-8,head[0]+8,head[1]+8),fill='#8293a6');d.line([tuple(sh),tuple(hip)],fill='#8293a6',width=16)
 for sign in [-1,1]:d.line([tuple(hip),tuple(hip+u*42+n*12*sign)],fill='#8293a6',width=9)
 d.line([tuple(sh),hand if i<9 else tuple(sh+u*20+n*22)],fill='#a6b5c6',width=8);victim.save(P/f'final_victim_{i:02}.png');canvas=Image.new('RGBA',(420,260),'#313845');canvas.alpha_composite(victim);canvas.alpha_composite(bow,(181,86));canvas.alpha_composite(body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS),off);d=ImageDraw.Draw(canvas);d.text((10,8),f'Reverse / continuous 13 / slim legs / {i+1:02}',fill='white');d.text((10,239),'148px | 960ms | separate neutral preview victim',fill='#bdc8d8');frames.append(canvas.convert('RGB'));records.append(dict(frame=i,pose=key,file=name,source=spec[key[0]][0],source_rect=rect,root_full_source=root,grip_full_source=hands[key],grip_preview=hand,body_height=ruler,scale=s,start_ms=time,duration_ms=dur[i],events=['release'] if i==9 else ['victim_land'] if i==12 else [],victim_grip_constrained=i<9,victim_shoulder=shoulders[i],victim_hip=hips[i],weapon_behind=True));time+=dur[i]
for tag,m in [('normal',1),('slow',3)]:frames[0].save(P/f'reverse_coherent13_slim_{tag}.gif',save_all=True,append_images=frames[1:],duration=[d*m for d in dur],loop=0,disposal=2)
sheet=Image.new('RGB',(840,1820),'#313845')
for i,f in enumerate(frames):sheet.paste(f,(i%2*420,i//2*260))
sheet.save(P/'final_contact_sheet.jpg');(P/'final_metadata.json').write_text(json.dumps(dict(clip='throw_reverse',prototype=True,frame_count=13,total_ms=time,release_ms=580,frames=records),indent=2));assert time==960
