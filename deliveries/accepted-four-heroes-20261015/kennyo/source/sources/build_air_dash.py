from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage
import numpy as np, json, math, hashlib
P=Path(__file__).parent; W,H=640,340;FLOOR=285
S=.334

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def K(src,rect,root,grips,dur,event,dx=0,air=0,angle=None,scale=S,feet=None,**kw):return dict(source=src,rect=rect,root_source=root,grips=grips,duration=dur,event=event,dx=dx,air_height=air,angle=angle,scale=scale,feet=feet or {},**kw)
# Shared guard exactly matches the light-attack set, including physical scale and two actual fist landmarks.
guard=K('light_1/source.png',[0,0,512,512],[278,498],[[278,209],[257,175]],150,'settled_guard',feet={'left':[101,501],'right':[385,498]})
configs={
'air_light':[
 dict(guard,duration=80,event='ready'),
 K('air_light/body-source.png',[0,0,540,525],[300,510],[[269,414],[292,402]],90,'spring_crouch',feet={'left':[92,509],'right':[460,507]}),
 K('air_light/body-source.png',[570,0,1020,520],[790,600],[[707,61],[685,69]],100,'rising_close_swing_windup',dx=4,air=32,feet={'left':[704,425],'right':[800,495]}),
 K('air_light/body-source.png',[1030,0,1536,525],[1300,600],[[1113,147],[1146,165]],70,'airborne_lateral_swing',dx=12,air=48,feet={'left':[1285,504],'right':[1381,472]}),
 K('air_light/body-source.png',[0,525,635,1024],[350,1060],[[590,675]],60,'near_swing_contact',dx=18,air=34,angle=118,contact=True,auxiliary='occluded behind visible front fist',feet={'left':[60,991],'right':[416,955]}),
 K('air_light/body-source.png',[640,520,1030,1024],[850,1080],[[840,787],[858,780]],80,'descending_followthrough',dx=20,air=12,feet={'left':[720,889],'right':[836,984]}),
 K('air_light/body-source.png',[1035,525,1536,1024],[1300,992],[[1316,857]],110,'soft_landing_crouch',dx=22,angle=70,landing=True,auxiliary='occluded adjacent fist',feet={'left':[1100,994],'right':[1450,992]}),
 dict(guard,dx=22,duration=180)
],
'air_heavy':[
 dict(guard,duration=90,event='ready'),
 K('air_heavy/body-source.png',[0,0,560,570],[300,560],[[350,50],[404,72]],110,'rising_raise_staff',air=24,feet={'left':[212,555],'right':[333,477]}),
 K('air_heavy/body-source.png',[570,0,1035,550],[800,570],[[808,25],[876,45]],140,'apex_staff_high',dx=8,air=58,feet={'left':[650,402],'right':[875,462]}),
 K('air_heavy/body-source.png',[1035,0,1536,558],[1300,550],[[1360,240],[1381,209]],85,'descending_overhand',dx=16,air=24,feet={'left':[1100,545],'right':[1460,541]}),
 K('air_heavy/contact-body-source.png',[0,0,1272,1236],[640,1175],[[700,460],[1140,815]],70,'downward_slam_contact',dx=22,scale=.128,contact=True,landing=True,feet={'left':[150,1173],'right':[1140,1170]}),
 K('air_heavy/body-source-fixed.png',[0,575,568,1024],[290,995],[[399,836],[440,831]],110,'horse_stance_landing_recoil',dx=22,landing=True,feet={'left':[82,994],'right':[500,992]}),
 K('air_heavy/body-source.png',[568,558,1040,1024],[800,995],[[778,758],[843,750]],120,'rise_from_horse_stance',dx=22,feet={'left':[618,992],'right':[984,992]}),
 dict(guard,dx=22,duration=220)
],
'dash_heavy':[
 K('dash_heavy/body-source.png',[0,0,560,500],[300,480],[[346,214],[431,214]],90,'running_last_stride',air=8,feet={'left':[85,420],'right':[481,464]}),
 K('dash_heavy/body-source.png',[565,0,1052,500],[800,492],[[744,99],[775,71]],90,'long_step_windup',dx=14,feet={'left':[619,462],'right':[994,483]}),
 K('dash_heavy/body-source.png',[1052,0,1536,501],[1300,485],[[1232,164]],65,'front_foot_plants_swing',dx=36,angle=66,front_anchor=[1480,485],auxiliary='other fist behind the visible grip',feet={'left':[1090,472],'right':[1480,485]}),
 K('dash_heavy/contact-body-source.png',[0,0,1351,1164],[700,1110],[[942,450],[1237,635]],65,'forward_sweep_contact',dx=52,scale=.145,front_anchor=[1240,1110],contact=True,feet={'left':[80,1080],'right':[1240,1110]}),
 K('dash_heavy/body-source.png',[625,510,1108,1024],[850,990],[[911,769]],100,'brake_followthrough',dx=58,angle=118,front_anchor=[1047,987],auxiliary='second hand behind front fist',feet={'left':[672,958],'right':[1047,987]}),
 K('dash_heavy/body-source.png',[1108,495,1536,1024],[1300,991],[[1267,688],[1390,626]],120,'recover_upright',dx=58,front_anchor=[1440,990],feet={'left':[1161,991],'right':[1440,990]}),
 dict(guard,dx=58,duration=200)
]}

def clean_body(im,rect):
 b=im.crop(rect);a=np.array(b);lab,n=ndimage.label(a[:,:,3]>24);counts=np.bincount(lab.ravel());counts[0]=0;keep=ndimage.binary_dilation(lab==counts.argmax(),iterations=2);a[:,:,3]=np.where(keep,a[:,:,3],0);return Image.fromarray(a)
def transform_weapon(weapon,pivot,angle,grip=(64,178)):
 t=math.radians(angle);co,si=math.cos(t),math.sin(t);x,y=pivot
 return weapon.transform((W,H),Image.Transform.AFFINE,(co,si,grip[0]-co*x-si*y,-si,co,grip[1]+si*x-co*y),Image.Resampling.BICUBIC)
def bg(comp,name,event,ix,n):
 c=Image.new('RGB',(W,H),(37,43,52));c.paste(comp,mask=comp.getchannel('A'));d=ImageDraw.Draw(c);d.line((25,FLOOR,615,FLOOR),fill=(67,75,86));d.text((15,15),f'KENNYO 03 | {name} | 163 px equivalent',fill=(220,225,230));d.text((15,316),f'{ix+1}/{n}  {event}',fill=(180,190,200));return c

def dummy(frame,contact_i,x,action):
 # Measurement dummy only, not a character art asset. Separate from every main-character layer.
 im=Image.new('RGBA',(W,H));d=ImageDraw.Draw(im);col=(110,149,172,210);lw=8
 if frame<contact_i:
  y=FLOOR;d.ellipse((x-12,y-140,x+12,y-116),fill=col);d.line((x,y-112,x,y-58),fill=col,width=lw);d.line((x,y-95,x-22,y-68),fill=col,width=lw);d.line((x,y-95,x+22,y-75),fill=col,width=lw);d.line((x,y-60,x-20,y),fill=col,width=lw);d.line((x,y-60,x+20,y),fill=col,width=lw)
 elif action=='air_heavy':
  y=FLOOR-8;d.ellipse((x+45,y-16,x+68,y+7),fill=col);d.line((x+41,y-5,x-15,y-5),fill=col,width=lw);d.line((x-15,y-5,x-58,y+2),fill=col,width=lw);d.line((x+25,y-5,x+12,y-26),fill=col,width=lw)
 elif action=='dash_heavy':
  dt=frame-contact_i;x+=dt*32;y=FLOOR-45-max(0,50-dt*15);d.ellipse((x+12,y-30,x+36,y-6),fill=col);d.line((x+12,y-7,x-30,y+21),fill=col,width=lw);d.line((x-30,y+21,x-58,y+32),fill=col,width=lw);d.line((x-30,y+21,x-25,y+58),fill=col,width=lw);d.line((x,y,x+20,y+25),fill=col,width=lw)
 else:
  y=FLOOR;x+=9;d.ellipse((x-6,y-142,x+18,y-118),fill=col);d.line((x+4,y-114,x-4,y-58),fill=col,width=lw);d.line((x,y-96,x-21,y-72),fill=col,width=lw);d.line((x-4,y-58,x-23,y),fill=col,width=lw);d.line((x-4,y-58,x+18,y),fill=col,width=lw)
 return im

def build(name):
 out=P/name;out.mkdir(exist_ok=True);cfg=configs[name];default_weapon='ornate_shakujo';allcomps={w:[] for w in ['long_staff','ornate_shakujo','approved03_naginata']};raws=[];recs=[];bodyonly=[]
 for i,f in enumerate(cfg):
  src=Image.open(P/f['source']).convert('RGBA');rect=f['rect'];x0,y0,x1,y1=rect;braw=clean_body(src,rect);s=f['scale'];rx,ry=f['root_source'];worldroot=[286+f['dx'],FLOOR-f['air_height']]
  ox=worldroot[0]-(rx-x0)*s;oy=worldroot[1]-(ry-y0)*s
  if f.get('front_anchor'):
   fx,fy=f['front_anchor'];ox=388-(fx-x0)*s;oy=FLOOR-(fy-y0)*s
  if name=='dash_heavy' and f['event']=='settled_guard':ox=388-(385-x0)*s;oy=FLOOR-(498-y0)*s
  body=Image.new('RGBA',(W,H));body.alpha_composite(braw.resize((round(braw.width*s),round(braw.height*s)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
  gp=[[ox+(x-x0)*s,oy+(y-y0)*s] for x,y in f['grips']];angle=f['angle']
  if len(gp)>1:angle=math.degrees(math.atan2(gp[1][0]-gp[0][0],-(gp[1][1]-gp[0][1])))
  hands=Image.new('RGBA',(W,H))
  for gx,gy in f['grips']:
   rad=15 if s>.2 else 34;patch=src.crop((gx-rad,gy-rad,gx+rad,gy+rad));mask=Image.new('L',patch.size);ImageDraw.Draw(mask).ellipse((1,1,2*rad-2,2*rad-2),fill=255);patch.putalpha(Image.fromarray(np.minimum(np.array(patch.getchannel('A')),np.array(mask))));patch=patch.resize((round(2*rad*s),round(2*rad*s)),Image.Resampling.LANCZOS);hands.alpha_composite(patch,(round(ox+(gx-rad-x0)*s),round(oy+(gy-rad-y0)*s)))
  effect=Image.new('RGBA',(W,H))
  if f.get('landing'):
   dust=Image.open(P/'fx_neutral/footstep_02.png').convert('RGBA');dust=dust.resize((92,46),Image.Resampling.LANCZOS);effect.alpha_composite(dust,(round(worldroot[0]-46),FLOOR-32))
  for wn in allcomps:
   weapon=Image.open(P/f'weapons/{wn}.png').convert('RGBA');w=transform_weapon(weapon,gp[0],angle);back=Image.new('RGBA',(W,H));front=w.copy()
   if (name=='air_light' and f.get('contact')) or (name=='air_heavy' and f.get('contact')) or (name=='dash_heavy' and f.get('contact')):
    yy,xx=np.mgrid[0:H,0:W];t=math.radians(angle);forward=(xx-gp[0][0])*math.sin(t)-(yy-gp[0][1])*math.cos(t)>=-3;aa=np.array(w);bb=aa.copy();ff=aa.copy();bb[:,:,3]=np.where(forward,0,aa[:,:,3]);ff[:,:,3]=np.where(forward,aa[:,:,3],0);back=Image.fromarray(bb);front=Image.fromarray(ff)
   comp=Image.new('RGBA',(W,H));comp.alpha_composite(back);comp.alpha_composite(body);comp.alpha_composite(front);comp.alpha_composite(hands);comp.alpha_composite(effect);allcomps[wn].append(comp)
   if wn==default_weapon:
    for layer,img in [('body',braw),('body_canvas',body),('weapon',w),('weapon_front',front),('weapon_back',back),('hand_occlusion',hands),('effect',effect),('composite',comp)]:img.save(out/f'{layer}_{i+1:02}.png')
  tip=[gp[0][0]+math.sin(math.radians(angle))*147,gp[0][1]-math.cos(math.radians(angle))*147]
  recs.append(dict(f,frame=i+1,source_sha256=sha(P/f['source']),source_crop_xyxy=rect,uniform_source_scale=s,render_origin=[ox,oy],world_root=worldroot,ground_root=[worldroot[0],FLOOR],airborne_height_px=f['air_height'],grip_world=gp,weapon_angle=angle,weapon_layer=('split_tail_back_head_front' if (f.get('contact')) else 'front'),weapon_real_length_px=215,weapon_grip_source=[64,178],aux_grip_source=([64,178-math.dist(gp[0],gp[1])] if len(gp)>1 else None),contact_point=tip if f.get('contact') else None,screen_feet={k:[ox+(v[0]-x0)*s,oy+(v[1]-y0)*s] for k,v in f['feet'].items()},hand_occlusion='Tight actual fist-pixel cutouts, separate layer',body_height_scale_basis='Shared fixed anatomical scale per generated sheet; single contact pose calibrated by head and torso to sheet, never by cropped pose height',standing_equivalent_px=163))
  bodyonly.append(bg(body,name,f['event'],i,len(cfg)))
 durs=[x['duration'] for x in cfg];normal=[bg(c,name,cfg[i]['event'],i,len(cfg)) for i,c in enumerate(allcomps[default_weapon])]
 def gif(filename,ims,m=1):ims[0].save(out/filename,save_all=True,append_images=ims[1:],duration=[v*m for v in durs],loop=0,disposal=2)
 gif('normal.gif',normal);gif('slow.gif',normal,3);gif('body_only.gif',bodyonly)
 for wn in ['long_staff','approved03_naginata']:gif(f'alternate-{wn}.gif',[bg(c,name,cfg[i]['event'],i,len(cfg)) for i,c in enumerate(allcomps[wn])])
 ci=next(i for i,f in enumerate(cfg) if f.get('contact'));point=recs[ci]['contact_point'];tx=min(530,max(380,point[0]));contactframes=[]
 for i,c in enumerate(allcomps[default_weapon]):
  target=dummy(i,ci,tx,name);target.save(out/f'contact_target_{i+1:02}.png');co=target.copy();co.alpha_composite(c);hit=Image.new('RGBA',(W,H))
  if i in [ci,ci+1]:
   burst=Image.open(P/f'fx_neutral/blunt_impact_{1 if i==ci else 3:02}.png').convert('RGBA');hit.alpha_composite(burst,(round(point[0]-32),round(point[1]-32)));co.alpha_composite(hit)
  hit.save(out/f'contact_effect_{i+1:02}.png');contactframes.append(bg(co,name,'confirmed contact / '+cfg[i]['event'],i,len(cfg)))
 gif('contact_preview.gif',contactframes)
 sheet=Image.new('RGB',(W*3,H*math.ceil(len(normal)/3)),(37,43,52))
 for i,im in enumerate(normal):sheet.paste(im,((i%3)*W,(i//3)*H))
 sheet.save(out/'contact.png');normal[ci].save(out/'poster.png')
 contactframes[ci].save(out/'contact-poster.png')
 elapsed=0
 for r in recs:r['start_ms']=elapsed;elapsed+=r['duration']
 meta={'action':name,'version':'kennyo03-air-dash-v1','standing_equivalent_px':163,'scale_contract':'../identity/scale-contract.json','preview_canvas':[W,H],'source_provenance':'Built-in image_gen body-only; deterministic crop, fixed anatomical scale, layer registration and composition. No local generative model, optical-flow or invented in-between poses.','frame_design':'Distinct authored key poses with nonuniform game timing. Slow preview runs 3x slower.','default_weapon':'../weapons/ornate_shakujo.png','weapon_length_px':215,'weapon_alternates':['../weapons/long_staff.png','../weapons/approved03_naginata.png'],'weapon_metadata':'../weapons/weapons-metadata.json','body_weapon_fx_hand_layers_separate':True,'air_root_and_pose_separate':True,'no_per_frame_bbox_scaling':True,'runtime_integrated':False,'numeric_multiplier':1.2 if name=='air_light' else 1.3 if name=='air_heavy' else None,'multiplier_applies_to':'runtime attack power and range only; not PNG scaling','response':'knockdown' if name=='air_heavy' else 'launch normal enemy; boss block and shield normal-hit are runtime exceptions' if name=='dash_heavy' else 'contact only; no extra control behavior invented','contact_preview':'Separate simple blue measurement dummy; confirmed-contact effect layer only. Normal no-target GIF contains no hit sparks.','total_duration_ms':elapsed,'frames':recs}
 (out/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2));print(name,len(cfg),elapsed,'ms')
if __name__=='__main__':
 import sys
 for n in sys.argv[1:] or configs:build(n)
