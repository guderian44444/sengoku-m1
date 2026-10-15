from pathlib import Path
from PIL import Image,ImageDraw
import json,math,copy,numpy as np
from head_scale import shrink_head
P=Path(__file__).resolve().parents[1];B=P/'actions/light_3_fastlow_v3';D=P/'actions/light_3_scale_v4';D.mkdir(exist_ok=True);m=json.loads((B/'metadata.json').read_text());sw=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA');scales=[1,.97,.97,.97,.97,.97,.97,.97,.97,.97,1];headfix=[1,.88,.85,.87,.90,.92,.88,.83,.86,.85,1];frames=[];qa=[]
for i,r in enumerate(m['frames']):
 s=scales[i];pivot=r.get('support_world',[240,250]);px,py=pivot;dx=px*(1-s);dy=0;body=Image.open(B/f'body_canvas_{i:02}.png').convert('RGBA')
 if i not in [0,10]:
  ox,oy=r['body_offset'];ss=r['body_scale'];hr=r['source_head_rect'];rect=[hr[0]*ss+ox,hr[1]*ss+oy,hr[2]*ss+ox,hr[3]*ss+oy];body=shrink_head(body,(0,0,520,300),rect,1,1,headfix[i])
 body=body.transform((520,300),Image.Transform.AFFINE,(1/s,0,-dx/s,0,1,0),Image.Resampling.BICUBIC)
 if i in [0,10]:
  body=Image.open(B/f'body_canvas_{i:02}.png').convert('RGBA');weapon=Image.open(B/f'weapon_{i:02}.png').convert('RGBA');comp=Image.open(B/f'composite_{i:02}.png').convert('RGBA')
 else:
  transform=lambda p:[p[0]*s+dx,p[1]]
  grip=transform(r['grip_world']);hands=[transform(p) for p in r['hand_centers']];gx,gy=grip;t=math.radians(r['weapon_angle']);co=math.cos(t)/.145;si=math.sin(t)/.145;weapon=sw.transform((520,300),Image.Transform.AFFINE,(co,si,180-co*gx-si*gy,-si,co,710+si*gx-co*gy),Image.Resampling.BICUBIC);comp=body.copy();comp.alpha_composite(weapon);mask=Image.new('L',(520,300));dd=ImageDraw.Draw(mask)
  for hx,hy in hands:dd.ellipse((hx-4,hy-4,hx+4,hy+4),fill=255)
  hm=body.copy();hm.putalpha(Image.fromarray(np.minimum(np.array(body.getchannel('A')),np.array(mask))));comp.alpha_composite(hm)
  for key in ['front_foot_world','rear_foot_world','support_world']:r[key]=transform(r[key])
  r.update(original_grip_world=r['grip_world'],grip_world=grip,hand_centers=hands,body_scale=r['body_scale'])
  mat=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]])*.145
  for key,v in [('blade_tip_world',[185,7]),('blade_guard_world',[180,579])]:r[key]=(np.array(grip)+mat@(np.array(v)-np.array([180,710]))).tolist()
 r.update(anatomical_x_scale_correction=s,head_anatomical_correction=headfix[i],leg_length_scale=1,scale_anchor=pivot,scale_basis='head/topknot-to-chin and shoulder/torso width against frozen shared ready; not whole-pose bbox height',registration_affine=[s,0,dx,0,1,0],weapon_scale=.145)
 for ln,im in [('body_canvas',body),('body',body),('weapon',weapon),('composite',comp)]:im.save(D/f'{ln}_{i:02}.png')
 bg=Image.new('RGB',(520,300),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dd=ImageDraw.Draw(bg);dd.line((0,253,520,253),fill=(68,74,82));dd.text((12,12),'HIDEYOSHI / light_3 / scale corrected / 680 ms',fill='white');dd.text((12,280),f'{i+1:02}/11  {r["duration_ms"]} ms',fill=(170,180,190));frames.append(bg);bb=weapon.getbbox();qa.append({'index':i,'scale':s,'support_anchor':pivot,'weapon_bbox':bb,'weapon_clipped':bb[0]<=0 or bb[1]<=0 or bb[2]>=520 or bb[3]>=300})
frames[0].save(D/'light_3_scale_v4.gif',save_all=True,append_images=frames[1:],duration=[r['duration_ms'] for r in m['frames']],loop=0,disposal=2,optimize=False);frames[5].save(D/'representative.png');cs=Image.new('RGB',(2080,900),(42,48,56))
for i,f in enumerate(frames):cs.paste(f,(i%4*520,i//4*300))
cs.save(D/'contact.png');m.update(revision='fastlow_scale_corrected_v4',scale_correction_source=str(B),scale_qa=qa);m['contact_event'].update(grip_world=m['frames'][5]['grip_world'],blade_guard_world=m['frames'][5]['blade_guard_world'],blade_tip_world=m['frames'][5]['blade_tip_world']);(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));g=Image.open(D/'light_3_scale_v4.gif');assert g.n_frames==11;assert sum((g.seek(i) or g.info['duration']) for i in range(11))==680;assert sum(m['frames'][i]['duration_ms'] for i in [3,4,5,6])==130;print('11f 680ms active130 verified')
