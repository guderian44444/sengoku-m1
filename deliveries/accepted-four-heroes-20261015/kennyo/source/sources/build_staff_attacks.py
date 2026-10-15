from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import numpy as np,json,math,hashlib
from scipy import ndimage
P=Path(__file__).parent
W,H=640,380;FLOOR=325

def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def data_frame(src,rect,feet,grips,angle,duration,event,**kw):
 return dict(source=src,rect=rect,feet=feet,grips=grips,angle=angle,duration=duration,event=event,**kw)
# Source coordinates are manually measured actual sandal / grip landmarks, not alpha-box anchors.
# All 1536x1024 sources use one shared anatomical scale. The 1254-square source has its own single uniform scale.
SCALES={'light_1/source.png':.337,'light_2/source.png':.337,'light_2/sweep-correction-source.png':.337,'light_2/step-correction-source.png':.337,'heavy/source.png':.337,'heavy/low-prep-body-only-source.png':.337,'light_3/source.png':.406}
common=data_frame('light_1/source.png',[0,0,512,512],{'left':[101,501],'right':[385,498]},[[278,209],[257,175]],-32,110,'guard',anchor='right',phase=0,root_dx=0)
# weapon_angle is clockwise from up. Grip 0 is principal; when grip 1 exists its axis determines angle.
configs={
'light_1':[
 common,
 data_frame('light_1/source.png',[560,0,1024,512],{'left':[632,475],'right':[848,500]},[[694,225]],-48,100,'rear_foot_lift',anchor='right',root_dx=5,hidden_auxiliary_hand=True),
 data_frame('light_1/source.png',[1024,0,1536,512],{'left':[1100,498],'right':[1460,502]},[[1144,157],[1204,182]],113,55,'rear_foot_plant',anchor='right',root_dx=11),
 data_frame('light_1/source.png',[0,515,565,1024],{'left':[100,1001],'right':[497,997]},[[164,599],[220,635]],123,55,'left_sweep_contact',anchor='right',root_dx=16,contact=True),
 data_frame('light_1/source.png',[565,515,1024,1024],{'left':[624,998],'right':[933,1000]},[[636,622]],105,70,'left_sweep_followthrough',anchor='right',front_dx=8,root_dx=16,hidden_auxiliary_hand=True),
 data_frame('light_1/source.png',[1024,515,1536,1024],{'left':[1130,1002],'right':[1453,1002]},[[1285,719],[1267,686]],-30,100,'recover',anchor='right',front_dx=16,root_dx=16),
 dict(common,duration=180,event='settled_guard',front_dx=16,root_dx=16)
],
'light_2':[
 dict(common),
 data_frame('light_2/step-correction-source.png',[560,0,1024,512],{'left':[657,439],'right':[917,497]},[[681,93],[695,80]],47,100,'rear_foot_lift',anchor='right',root_dx=5),
 data_frame('light_2/source.png',[1024,0,1536,512],{'left':[1075,502],'right':[1460,500]},[[1399,226],[1472,230]],93,60,'rear_foot_plant',anchor='right',root_dx=11),
 data_frame('light_2/sweep-correction-source.png',[0,515,557,1024],{'left':[52,995],'right':[488,996]},[[416,671],[501,650]],76,55,'right_sweep_contact',anchor='right',root_dx=16,contact=True),
 data_frame('light_2/sweep-correction-source.png',[557,515,1024,1024],{'left':[612,997],'right':[969,996]},[[894,647]],-45,75,'right_sweep_followthrough',anchor='right',front_dx=8,root_dx=16,hidden_auxiliary_hand=True),
 data_frame('light_2/source.png',[1024,515,1536,1024],{'left':[1091,996],'right':[1456,994]},[[1336,730]],65,100,'recover',anchor='right',front_dx=16,root_dx=16,hidden_auxiliary_hand=True),
 dict(common,duration=180,event='settled_guard',front_dx=16,root_dx=16)
],
'heavy':[
 dict(common,duration=110),
 data_frame('heavy/low-prep-body-only-source.png',[0,0,545,512],{'left':[84,500],'right':[440,499]},[[245,251],[358,256]],93,190,'draw_staff_close',anchor='left',root_dx=0),
 data_frame('heavy/low-prep-body-only-source.png',[545,0,1024,512],{'left':[591,499],'right':[858,472]},[[775,262],[868,266]],92,150,'one_front_step_lift',anchor='left',root_dx=5),
 data_frame('heavy/source.png',[1024,0,1536,512],{'left':[1070,497],'right':[1450,498]},[[1364,241],[1441,144]],38,80,'one_front_step_plant',anchor='left',root_dx=20),
 data_frame('heavy/source.png',[0,512,550,1024],{'left':[75,985],'right':[486,984]},[[386,650],[473,555]],42,60,'rising_contact',anchor='left',root_dx=20,contact=True),
 data_frame('heavy/source.png',[550,512,1024,1024],{'left':[591,984],'right':[974,983]},[[921,535]],25,110,'high_followthrough',anchor='left',root_dx=20,hidden_auxiliary_hand=True),
 data_frame('heavy/source.png',[1024,512,1536,1024],{'left':[1090,985],'right':[1447,984]},[[1391,725],[1434,654]],31,160,'lower_to_guard',anchor='left',root_dx=20),
 dict(common,duration=240,event='settled_guard',front_dx=20,root_dx=20)
],
'light_3':[
 dict(common),
 data_frame('light_3/source.png',[0,0,429,426],{'left':[99,400],'right':[328,414]},[[352,189],[404,173]],73,100,'rear_foot_lift',anchor='right',root_dx=5,phase=0),
 data_frame('light_3/source.png',[429,0,842,426],{'left':[489,416],'right':[767,416]},[[722,194],[788,189]],86,60,'rear_foot_plant',anchor='right',root_dx=12,phase=35),
 data_frame('light_3/source.png',[842,0,1254,434],{'left':[901,426],'right':[1161,410]},[[1036,183],[1134,192]],95,60,'front_quarter_turn',anchor='right',root_dx=18,phase=90,projection=.88),
 data_frame('light_3/source.png',[0,426,429,817],{'left':[91,807],'right':[380,809]},[[87,579]],270,60,'left_profile_half_turn',anchor='left',root_dx=18,phase=180,projection=.48,hidden_auxiliary_hand=True),
 data_frame('light_3/source.png',[429,426,842,817],{'left':[479,812],'right':[797,813]},[[790,577],[496,576]],-90,60,'back_three_quarter',anchor='left',root_dx=18,phase=225,behind=True),
 data_frame('light_3/source.png',[842,434,1254,817],{'left':[915,807],'right':[1164,800]},[[1206,593],[888,589]],-89,60,'back_view',anchor='left',root_dx=18,phase=270,behind=True),
 data_frame('light_3/source.png',[0,817,429,1254],{'left':[92,1222],'right':[377,1204]},[[416,970]],90,60,'right_profile_return',anchor='right',root_dx=18,phase=320,projection=.52,hidden_auxiliary_hand=True),
 data_frame('light_3/source.png',[429,817,856,1254],{'left':[458,1215],'right':[805,1216]},[[811,982]],88,70,'full_circle_contact',anchor='right',root_dx=18,phase=360,contact=True,hidden_auxiliary_hand=True),
 data_frame('light_3/source.png',[856,817,1254,1254],{'left':[918,1221],'right':[1171,1210]},[[1128,977],[1198,970]],84,120,'recover',anchor='right',front_dx=18,root_dx=18,phase=360),
 dict(common,duration=190,event='settled_guard',front_dx=18,root_dx=18,phase=360)
]}

def transform_weapon(weapon,pivot,angle,projection=1):
 # Real weapon length is constant. A recorded horizontal-spin view alone uses axial projection.
 theta=math.radians(angle);co,si=math.cos(theta),math.sin(theta)
 # source up axis after rotation: (sin(theta),-cos(theta)); affine inverse.
 a,b=co,si;d,e=-si/projection,co/projection
 gx,gy=pivot;return weapon.transform((W,H),Image.Transform.AFFINE,(a,b,64-a*gx-b*gy,d,e,178-d*gx-e*gy),Image.Resampling.BICUBIC)

def build(name):
 out=P/name;out.mkdir(exist_ok=True);weapon=Image.open(P/'weapons/ornate_shakujo.png').convert('RGBA');frames=[];records=[];body_only=[];dust_anchor=None;dust_phase=None
 common_s=SCALES[common['source']];baseline_x=286;common_ox=baseline_x-278*common_s
 common_foot={k:[common_ox+p[0]*common_s,FLOOR] for k,p in common['feet'].items()}
 for i,f in enumerate(configs[name]):
  src=Image.open(P/f['source']).convert('RGBA');x0,y0,x1,y1=f['rect'];body=src.crop(tuple(f['rect']));s=SCALES[f['source']]
  arr=np.array(body)
  if f['source']=='heavy/low-prep-body-only-source.png':
   clean_alpha=np.array(Image.open(P/'heavy/low-prep-correction-source.png').convert('RGBA').crop(tuple(f['rect'])).getchannel('A'));arr[:,:,3]=np.minimum(arr[:,:,3],clean_alpha)
  lab,n=ndimage.label(arr[:,:,3]>24); counts=np.bincount(lab.ravel()); counts[0]=0
  keep=ndimage.binary_dilation(lab==counts.argmax(),iterations=2);arr[:,:,3]=np.where(keep,arr[:,:,3],0);body=Image.fromarray(arr)
  anchor=f['anchor'];foot=f['feet'][anchor];targetx=common_foot[anchor][0]+f.get('front_dx',0)
  # During one-forward-step heavy, trailing foot remains anchored through contact.
  ox=targetx-(foot[0]-x0)*s;oy=FLOOR-(foot[1]-y0)*s
  # No per-frame bbox, alpha-bottom, head-height or posture rescaling.
  b=Image.new('RGBA',(W,H));scaled=body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS);b.alpha_composite(scaled,(round(ox),round(oy)))
  gs=[[ox+(g[0]-x0)*s,oy+(g[1]-y0)*s] for g in f['grips']]
  angle=f['angle']
  if len(gs)==2:angle=math.degrees(math.atan2(gs[1][0]-gs[0][0],-(gs[1][1]-gs[0][1])))
  projection=f.get('projection',1)
  w=transform_weapon(weapon,gs[0],angle,projection)
  back=w if f.get('behind') else Image.new('RGBA',(W,H));front=Image.new('RGBA',(W,H)) if f.get('behind') else w
  hands=Image.new('RGBA',(W,H))
  for g in f['grips']:
   radius=15 if f['source']!='light_3/source.png' else 12
   box=(g[0]-radius,g[1]-radius,g[0]+radius,g[1]+radius)
   patch=src.crop(box);mask=Image.new('L',patch.size);ImageDraw.Draw(mask).ellipse((1,1,2*radius-1,2*radius-1),fill=255)
   patch.putalpha(Image.fromarray(np.minimum(np.array(patch.getchannel('A')),np.array(mask))))
   patch=patch.resize((round(2*radius*s),round(2*radius*s)),Image.Resampling.LANCZOS)
   hands.alpha_composite(patch,(round(ox+(g[0]-radius-x0)*s),round(oy+(g[1]-radius-y0)*s)))
  fx=Image.new('RGBA',(W,H))
  if f['event'] in ['rear_foot_plant','one_front_step_plant']:
   dust_phase=0;dp=f['feet']['left' if f['event']=='rear_foot_plant' else 'right'];dust_anchor=[ox+(dp[0]-x0)*s,oy+(dp[1]-y0)*s]
  if dust_phase is not None and dust_phase<3:
   dust=Image.open(P/f'fx_neutral/footstep_{dust_phase+1:02}.png').convert('RGBA');fx.alpha_composite(dust,(round(dust_anchor[0]-32),round(dust_anchor[1]-44)));dust_phase+=1
  comp=Image.new('RGBA',(W,H));comp.alpha_composite(back);comp.alpha_composite(b);comp.alpha_composite(front);comp.alpha_composite(hands);comp.alpha_composite(fx)
  for layer,img in [('body',body),('body_canvas',b),('weapon',w),('weapon_back',back),('weapon_front',front),('hand_occlusion',hands),('effect',fx),('composite',comp)]:img.save(out/f'{layer}_{i+1:02}.png')
  can=Image.new('RGB',(W,H),(37,43,52));can.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(can);dr.line((25,FLOOR,615,FLOOR),fill=(67,75,86));dr.text((15,15),f'KENNYO 03 | {name} | 163 px equivalent',fill=(220,225,230));dr.text((15,H-24),f'{i+1}/{len(configs[name])}  {f["event"]}',fill=(180,190,200));frames.append(can)
  bo=Image.new('RGB',(W,H),(37,43,52));bo.paste(b,mask=b.getchannel('A'));body_only.append(bo)
  root=[baseline_x+f.get('root_dx',0),FLOOR]
  feet={k:[round(ox+(p[0]-x0)*s,3),round(oy+(p[1]-y0)*s,3)] for k,p in f['feet'].items()}
  tip=[gs[0][0]+math.sin(math.radians(angle))*147*projection,gs[0][1]-math.cos(math.radians(angle))*147*projection]
  records.append(dict(f,frame=i+1,source_sha256=sha(P/f['source']),source_crop_xyxy=f['rect'],alpha_mask_source=('heavy/low-prep-correction-source.png' if f['source']=='heavy/low-prep-body-only-source.png' else None),uniform_source_scale=s,render_origin=[ox,oy],world_root=root,root_motion_x=f.get('root_dx',0),screen_feet=feet,grip_world=gs,weapon_angle=angle,weapon_projection=projection,weapon_spin_phase=f.get('phase'),weapon_layer='back' if f.get('behind') else 'front',contact_point=tip if f.get('contact') else None,hand_occlusion='tight ellipse cutouts of actual fist pixels',effect_layer='generated neutral footstep dust on actual foot plant; emit independent blunt impact only on confirmed target contact',auxiliary_grip_status='measured visible' if len(gs)==2 else 'occluded, not fabricated',body_height_scale_basis='One fixed anatomical scale per source sheet. No individual frame bbox normalization.',standing_equivalent_px=163))
 durs=[f['duration'] for f in configs[name]]
 for filename,mult in [('normal.gif',1),('slow.gif',3)]:frames[0].save(out/filename,save_all=True,append_images=frames[1:],duration=[v*mult for v in durs],loop=0,disposal=2)
 body_only[0].save(out/'body_only.gif',save_all=True,append_images=body_only[1:],duration=durs,loop=0,disposal=2)
 contact=Image.new('RGB',(W*3,H*math.ceil(len(frames)/3)),(37,43,52))
 for i,im in enumerate(frames):contact.paste(im,((i%3)*W,(i//3)*H))
 contact.save(out/'contact.png');frames[3].save(out/'poster.png')
 elapsed=0
 for r in records:r['start_ms']=elapsed;elapsed+=r['duration']
 data=dict(action=name,version='kennyo03-new-spec-staff-attacks-v1',standing_equivalent_px=163,preview_canvas=[W,H],source_provenance='Built-in image_gen body-only; deterministic cropping, uniform scaling, weapon composition and timing only. No optical flow, Comfy or Qwen.',weapon_source='../weapons/ornate_shakujo.png',weapon_sha256=sha(P/'weapons/ornate_shakujo.png'),weapon_physical_length_px=215,shared_combo_guard='light_1/source.png rect [0,0,512,512], identical first and last body/grip/angle at retained root offset',runtime_integrated=False,root_motion_clamp='Renderer may stop root advance at blocking targets while retaining body pose sequence.',frames=records,total_duration_ms=elapsed,qa={'true_alpha':True,'no_per_frame_bbox_scaling':True,'body_weapon_fx_hands_separate':True,'final_root_retained':True,'rear_step_anatomy':name!='heavy','heavy_single_front_step':name=='heavy','visible_actual_spin_views':name=='light_3','damage_values':'not assigned','contact_response':('push_standing' if name in ['light_1','light_2'] else 'launch_high' if name=='heavy' else 'launch')})
 (out/'metadata.json').write_text(json.dumps(data,indent=2,ensure_ascii=False))
 print(name,elapsed,'ms',len(records),'frames')
if __name__=='__main__':
 import sys
 for n in (sys.argv[1:] or configs):build(n)
