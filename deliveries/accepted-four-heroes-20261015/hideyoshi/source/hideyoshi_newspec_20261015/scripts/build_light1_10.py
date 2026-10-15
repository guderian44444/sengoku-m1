from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,math,hashlib,shutil
from scipy.ndimage import label,find_objects,binary_dilation
from head_scale import shrink_head
P=Path(__file__).resolve().parents[1]
CFG={'light_1':{'seq':[0,1,2,'a',3,4,5,'b',6,7],'dur':[90,70,60,40,50,80,60,60,80,110],'scale':.20,'heads':[(455,145,628,327),(1190,155,1360,345)],'grips':[(795,170),(1421,574)],'feet':[(760,890),(1425,895)],'roots':[(229,250),(229,250)],'angles':[45,120]}}
for name,cfg in CFG.items():
 D=P/'actions'/name;backup=P/'actions'/f'{name}_8frame_baseline'
 if not backup.exists():shutil.copytree(D,backup)
 old=json.loads((backup/'metadata.json').read_text());src=P/'actions'/f'{name}_extra2_source.png';im=Image.open(src).convert('RGBA');arr=np.array(im);lab,num=label(arr[:,:,3]>40);objs=[]
 for i,s in enumerate(find_objects(lab)):
  if s and (lab[s]==i+1).sum()>4000:objs.append((i+1,[s[1].start,s[0].start,s[1].stop,s[0].stop]))
 objs.sort(key=lambda q:q[1][0]);assert len(objs)==2
 sw=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA');frames=[];md=[]
 for i,(sel,dur) in enumerate(zip(cfg['seq'],cfg['dur'])):
  if isinstance(sel,int):
   for layer in ['body','body_canvas','weapon','composite']:shutil.copy(backup/f'{layer}_{sel:02}.png',D/f'{layer}_{i:02}.png')
   comp=Image.open(D/f'composite_{i:02}.png').convert('RGBA');rec=old['frames'][sel].copy();rec['baseline_frame']=sel
  else:
   k='ab'.index(sel);cid,box=objs[k];x0,y0,x1,y1=box;a=arr[y0:y1,x0:x1].copy();mask=binary_dilation(lab==cid,iterations=1)[y0:y1,x0:x1];a[:,:,3]=np.where(mask,a[:,:,3],0);body=Image.fromarray(a);body=shrink_head(body,box,cfg['heads'][k],1,1,.95);body.save(D/f'body_{i:02}.png');s=cfg['scale'];fx,fy=cfg['feet'][k];rx,ry=cfg['roots'][k];ox=rx-fx*s;oy=ry-fy*s;bc=Image.new('RGBA',(520,300));bc.alpha_composite(body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS),(round(ox+x0*s),round(oy+y0*s)));bc.save(D/f'body_canvas_{i:02}.png');gx,gy=cfg['grips'][k];px,py=ox+gx*s,oy+gy*s;angle=cfg['angles'][k];t=math.radians(angle);ws=.145;co=math.cos(t)/ws;si=math.sin(t)/ws;wl=sw.transform((520,300),Image.Transform.AFFINE,(co,si,180-co*px-si*py,-si,co,710+si*px-co*py),Image.Resampling.BICUBIC);wl.save(D/f'weapon_{i:02}.png');comp=bc.copy();comp.alpha_composite(wl)
   # Restore only the small real fist interface over the separate hilt.
   hand=im.crop((gx-11,gy-11,gx+11,gy+11)).resize((round(22*s),round(22*s)),Image.Resampling.LANCZOS);comp.alpha_composite(hand,(round(px-11*s),round(py-11*s)));comp.save(D/f'composite_{i:02}.png')
   rec={'source':'../'+src.name,'source_rect':box,'body_scale':s,'root':[rx,ry],'source_grip':[gx,gy],'grip_world':[px,py],'weapon_angle':angle,'event':None,'new_transition_pose':sel,'head_scale':.95,'source_sha256':hashlib.sha256(src.read_bytes()).hexdigest()}
  rec['index']=i;rec['duration_ms']=dur;md.append(rec);bg=Image.new('RGB',(520,300),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));d=ImageDraw.Draw(bg);d.line((0,251,520,251),fill=(68,74,82));d.text((12,12),f'HIDEYOSHI / {name} / {sum(cfg["dur"])} ms',fill='white');d.text((12,280),f'{i+1:02} / 10 - separate body + katana',fill=(170,180,190));frames.append(bg)
 frames[0].save(D/f'{name}_10.gif',save_all=True,append_images=frames[1:],duration=cfg['dur'],loop=0,disposal=2);shutil.copy(D/f'{name}_10.gif',D/f'{name}.gif');hit=next(i for i,r in enumerate(md) if r.get('event'));frames[hit].save(D/'representative.png');contact=Image.new('RGB',(520*4,300*3),(42,48,56))
 for i,fr in enumerate(frames):contact.paste(fr,(i%4*520,i//4*300))
 contact.save(D/'contact.png');old.update(frames=md,frame_count=10,duration_ms=sum(cfg['dur']),revision='downcut_head95_plus2_realposes_700ms',added_pose_source=str(src.relative_to(P)),added_pose_source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),canvas=[520,300],floor=251,interpolation='none; two new imagegen poses inserted among eight unchanged baseline frames');(D/'metadata.json').write_text(json.dumps(old,ensure_ascii=False,indent=2));g=Image.open(D/f'{name}_10.gif');assert g.n_frames==10;assert sum((g.seek(j) or g.info['duration']) for j in range(10))==sum(cfg['dur']);print(name,g.n_frames,sum(cfg['dur']))
