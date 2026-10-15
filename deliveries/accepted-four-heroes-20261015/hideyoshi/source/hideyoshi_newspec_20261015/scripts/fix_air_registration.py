from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil,math,numpy as np
P=Path(__file__).resolve().parents[1];W,H=520,380
CFG={
'air_light':dict(pelvis=[(185,249),(185,278),(279,207),(218,196),(235,188),(255,191),(175,194),(231,241),(181,242),(181,278),(185,249)],scale=[1,.90,.98,1,.98,.90,.94,.88,.92,.88,1],head=[29,34,31,29,28,36,31,35,31,36,29],chest=[35,38,35,34,38,40,40,40,40,43,35],xs=[185]*11,ys=[249,278,225,211,194,194,213,241,257,278,249],ground=[0,1,9,10],desc='原地起跳與落地：腰帶／骨盆中心X固定，頭胸校準固有尺度；11格620ms。',suffix='inplace_scale_v2'),
'air_heavy':dict(pelvis=[(185,249),(177,278),(249,225),(222,211),(216,195),(160,205),(151,225),(158,251),(155,280),(170,278),(185,249)],scale=[1,.90,1,.94,.94,.97,.90,.90,.94,.88,1],head=[29,34,29,32,32,31,33,36,31,36,29],chest=[35,38,35,36,36,37,40,40,39,42,35],xs=[185,185,187,192,198,206,214,220,221,221,221],ys=[249,278,230,211,195,213,240,257,280,278,249],ground=[0,1,8,9,10],desc='前進一步空中落斬：骨盆沿連續前進弧線移動36px，落地後不退回；頭胸校準固有尺度。',suffix='forwardstep_scale_v2')}
sword=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
for n,c in CFG.items():
 D=P/'actions'/n;B=P/'actions'/f'{n}_11frame_pre_registration'
 if not B.exists():shutil.copytree(D,B)
 m=json.loads((B/'metadata.json').read_text());frames=[];qa=[]
 for i,r in enumerate(m['frames']):
  oldbody=Image.open(B/f'body_canvas_{i:02}.png').convert('RGBA');s=c['scale'][i];sx,sy=c['pelvis'][i];tx,ty=c['xs'][i],c['ys'][i]
  # Grounding uses the sole only after anatomy calibration, never sets scale from bbox height.
  if i in c['ground']:ty=330-(oldbody.getbbox()[3]-1-sy)*s
  dx=tx-sx*s;dy=ty-sy*s;aff=(1/s,0,-dx/s,0,1/s,-dy/s);body=oldbody.transform((W,H),Image.Transform.AFFINE,aff,Image.Resampling.BICUBIC);
  lower_y_scale=.80 if n=='air_light' and i==2 else .90 if n=='air_heavy' and i==2 else 1.0
  if lower_y_scale!=1:
   split=round(ty);lower=body.crop((0,split,W,H));lower=lower.resize((W,round(lower.height*lower_y_scale)),Image.Resampling.BICUBIC);fixed=Image.new('RGBA',(W,H));fixed.alpha_composite(body.crop((0,0,W,split)),(0,0));fixed.alpha_composite(lower,(0,split));body=fixed
  body.save(D/f'body_canvas_{i:02}.png');body.save(D/f'body_{i:02}.png')
  gx,gy=r['grip_world'];gx=gx*s+dx;gy=gy*s+dy;t=math.radians(r['weapon_angle']);co=math.cos(t)/.145;si=math.sin(t)/.145;weapon=sword.transform((W,H),Image.Transform.AFFINE,(co,si,180-co*gx-si*gy,-si,co,710+si*gx-co*gy),Image.Resampling.BICUBIC);weapon.save(D/f'weapon_{i:02}.png');comp=body.copy();comp.alpha_composite(weapon);hand=body.crop((round(gx-3),round(gy-3),round(gx+4),round(gy+4)));comp.alpha_composite(hand,(round(gx-3),round(gy-3)));comp.save(D/f'composite_{i:02}.png')
  bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));d=ImageDraw.Draw(bg);d.line((0,331,W,331),fill=(68,74,82));d.line((185,333,185,342),fill=(100,135,170));
  if n=='air_heavy':d.line((221,333,221,342),fill=(170,135,100))
  d.text((12,12),f'HIDEYOSHI / {n} / {m["duration_ms"]} ms',fill='white');d.text((12,360),f'{i+1:02} / 11 - '+('vertical jump' if n=='air_light' else 'forward step +36px'),fill=(170,180,190));frames.append(bg)
  r.update(original_grip_world=r['grip_world'],grip_world=[gx,gy],root=[tx,330],pelvis_world=[tx,ty],anatomical_scale_correction=s,lower_body_y_scale=lower_y_scale,registration_affine=[s,0,dx,0,s,dy],body_scale=r.get('body_scale',1)*s,scale_basis={'measured_head_height_px':c['head'][i],'measured_chest_width_px':c['chest'][i],'baseline_head_height_px':29,'baseline_chest_width_px':35,'method':'Manual head, chest and limb comparison; no pose-bbox-height normalization; foreshortening retained'},weapon_scale_constant=.145)
  bb=weapon.getbbox();qa.append({'index':i,'pelvis_x':tx,'pelvis_y':ty,'corrected_head_height':round(c['head'][i]*s,2),'corrected_chest_width':round(c['chest'][i]*s,2),'weapon_bbox':bb,'weapon_clipped':bb[0]<=0 or bb[1]<=0 or bb[2]>=W or bb[3]>=H})
 name=n+'_'+c['suffix'];frames[0].save(D/f'{name}.gif',save_all=True,append_images=frames[1:],duration=[f['duration_ms'] for f in m['frames']],loop=0,disposal=2);shutil.copy(D/f'{name}.gif',D/f'{n}.gif');hit=next(i for i,r in enumerate(m['frames']) if r.get('event'));frames[hit].save(D/'representative.png');sheet=Image.new('RGB',(W*4,H*3),(42,48,56))
 for i,fr in enumerate(frames):sheet.paste(fr,(i%4*W,i//4*H))
 sheet.save(D/'contact.png');m.update(revision=c['suffix'],description=c['desc'],registration='pelvis-based; fixed X in air_light; explicit +36px landing in air_heavy',body_raw_semantics='body_XX now registered canvas, same as body_canvas_XX',scale_qa=qa);(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));(D/'registration_qa.json').write_text(json.dumps({'frames':qa,'contact_review':'pending','normal_speed_playback':'parent browser required','body_landmark_precision_px':3},indent=2));print(n,[q['pelvis_x'] for q in qa])
