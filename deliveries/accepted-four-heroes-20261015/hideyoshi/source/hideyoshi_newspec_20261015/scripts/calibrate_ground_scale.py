from pathlib import Path
from PIL import Image,ImageDraw
import json,math,shutil
P=Path(__file__).resolve().parents[1]
CONFIG={'light_2':([1,.975,.975,.98,.98,.98,.98,1],'body_canvas'),'dash_heavy':([.98,.98,.98,.98,.98,.98,1,1],'body_canvas'),'heavy':([1,1,1,1,.975,1,1,.975,1,1,1,1],'body')}
mf=json.loads((P/'review_manifest.json').read_text());audit={}
for aid,(scales,stem) in CONFIG.items():
 a=next(x for x in mf['actions'] if x['id']==aid);D=Path(a['metadata']).resolve().parent;B=D/'scale_audit_original';B.mkdir(exist_ok=True)
 if not (B/'metadata.json').exists():
  for f in [D/'metadata.json',*D.glob(f'{stem}_*.png'),*D.glob('weapon_*.png'),*D.glob('composite_*.png')]:shutil.copy2(f,B/f.name)
 m=json.loads((B/'metadata.json').read_text());frames=[];sw=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
 for i,r in enumerate(m['frames']):
  body=Image.open(B/f'{stem}_{i:02}.png').convert('RGBA');s=scales[i];anchor=r.get('root',[173 if i==4 else 182,250]);ax,ay=anchor;px,py=r['grip_world'];px=ax+(px-ax)*s;py=ay+(py-ay)*s
  body=body.transform(body.size,Image.Transform.AFFINE,(1/s,0,ax*(1-1/s),0,1/s,ay*(1-1/s)),Image.Resampling.BICUBIC) if s!=1 else body
  if s==1:wp=Image.open(B/f'weapon_{i:02}.png').convert('RGBA');comp=Image.open(B/f'composite_{i:02}.png').convert('RGBA')
  else:
   angle=r.get('weapon_angle',r.get('blade_angle'));t=math.radians(angle);co=math.cos(t)/.145;si=math.sin(t)/.145
   if aid=='heavy':
    roll=r['blade_roll_scale'];wp=sw.transform(body.size,Image.Transform.AFFINE,(co/roll,si/roll,180-(co*px+si*py)/roll,-si,co,710+si*px-co*py),Image.Resampling.BICUBIC)
   else:
    length=([1,1,1,.4,1,.65,.8,1][i] if aid=='light_2' else 1);wp=sw.transform(body.size,Image.Transform.AFFINE,(co,si,180-co*px-si*py,-si/length,co/length,710+(si*px-co*py)/length),Image.Resampling.BICUBIC)
   comp=body.copy();comp.alpha_composite(wp);x,y=round(px),round(py);comp.alpha_composite(body.crop((x-4,y-4,x+4,y+4)),(x-4,y-4))
  body.save(D/f'{stem}_{i:02}.png');wp.save(D/f'weapon_{i:02}.png');comp.save(D/f'composite_{i:02}.png');r['grip_world']=[px,py];r['intrinsic_scale_correction']=s;r['scale_anchor']=anchor
  bg=Image.new('RGB',body.size,(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,251,520,251),fill=(68,74,82));dr.text((12,12),f'HIDEYOSHI / {aid} / {m["duration_ms"]}ms',fill='white');dr.text((12,280),f'{i+1:02}/{len(scales):02} scale calibrated',fill=(180,190,200));frames.append(bg)
 durations=[r['duration_ms'] for r in m['frames']];frames[0].save(a['gif'],save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2);hit=next((i for i,r in enumerate(m['frames']) if r.get('event')),len(scales)//2);frames[hit].save(a['representative']);contact=Image.new('RGB',(2080,300*((len(frames)+3)//4)));[contact.paste(f,((i%4)*520,(i//4)*300)) for i,f in enumerate(frames)];contact.save(a['contact']);m['scale_audit']='Conservative 2–2.5% intrinsic correction from same-orientation head/chest landmarks. Support foot fixed, natural crouch height retained; sword length unchanged.';(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));a['revision']+='_scale_calibrated';a['status']='candidate';audit[aid]={'corrections':scales,'landmark_method':'Visual head hairline/chin and shoulder/waist comparison, not alpha bbox; precision about 2–3 game pixels','no_regeneration':True,'unchanged_duration':sum(durations)}
(P/'review_manifest.json').write_text(json.dumps(mf,ensure_ascii=False,indent=2));audit['light_1']={'revision':'downcut10_scale_registration_v6','additional_correction':False,'prior_correction':'Inserted frames 4 and 8 reduced 8%, support foot registration repaired. No additional clear discrepancy.'};(P/'scale_audit_ground.json').write_text(json.dumps(audit,ensure_ascii=False,indent=2))
