from pathlib import Path
import copy, json, math, hashlib, shutil
from PIL import Image, ImageDraw
import numpy as np
import build_staff_attacks as base
P=Path(__file__).parent
OUT=P/'light_1_v3'
S='light_1_v3/source.png'; C='light_1_v3/arc-correction-source.png'
base.SCALES[S]=.408;base.SCALES[C]=.408
f=base.data_frame
common=copy.deepcopy(base.common)
common['feet']['right']=[410,498]  # anatomical forefoot ball, ~8 px behind rendered toe
base.common=copy.deepcopy(common)
# The right SCREEN foot is always the same anatomical LEFT planted support foot.
# Every source landmark below is measured on its actual opaque sandal sole.
frames=[dict(common,duration=80,event='normal_guard_fixed_left_foot'),
f(S,[0,0,418,426],{'left':[56,400],'right':[333,413]},[[137,75],[110,32]],-32,80,'wind_up_over_fixed_left_foot',anchor='right'),
f(S,[418,0,836,426],{'left':[567,376],'right':[750,415]},[[588,90],[565,47]],-28,70,'right_foot_lift_left_foot_planted',anchor='right'),
f(C,[0,426,418,840],{'left':[89,819],'right':[377,830]},[[178,542],[206,484]],26,60,'moving_right_foot_cross_step',anchor='right'),
f(C,[836,0,1254,426],{'left':[970,411],'right':[1189,416]},[[1127,112],[1185,58]],47,40,'diagonal_arc_acceleration',anchor='right'),
f(S,[418,426,836,840],{'left':[525,824],'right':[784,828]},[[728,578],[769,572]],82,40,'single_sweep_contact_tail_grip',anchor='right',contact=True),
f(S,[836,426,1254,840],{'left':[926,826],'right':[1209,829]},[[1127,609],[1157,621]],112,50,'down_right_arc_followthrough',anchor='right'),
f(S,[0,840,418,1254],{'left':[88,1237],'right':[355,1239]},[[265,962],[299,919]],38,60,'close_elbows_recover',anchor='right'),
f(S,[418,840,836,1254],{'left':[492,1234],'right':[765,1239]},[[595,939],[575,898]],-26,70,'normal_grip_guard_recovery',anchor='right'),
dict(common,duration=120,event='settled_guard_same_left_foot')]
PIVOTS=[178,184,190,206,222,234,234,218,194,178]
for i,x in enumerate(frames):x.update(root_dx=0,front_dx=0,anatomical_support_foot='left',moving_foot='right',support_exchange=False,weapon_source_grip=[64,PIVOTS[i]])
_it=iter(PIVOTS)
def weapon_transform(weapon,pivot,angle,projection=1):
 sy=next(_it);t=math.radians(angle);co,si=math.cos(t),math.sin(t);a,b=co,si;d,e=-si/projection,co/projection;gx,gy=pivot
 return weapon.transform((base.W,base.H),Image.Transform.AFFINE,(a,b,64-a*gx-b*gy,d,e,sy-d*gx-e*gy),Image.Resampling.BICUBIC)
base.transform_weapon=weapon_transform;base.configs['light_1_v3']=frames;base.build('light_1_v3')
m=json.loads((OUT/'metadata.json').read_text())
m.update(action='light_1',version='kennyo03-light1-v3-fixed-pivot-true-swing',revision='v3-fixed-anatomical-left-foot-and-visible-angular-arc',replaces='light_1_v2',requested_changes=['Actual swing with clear changing staff angle; not a fixed-angle thrust.','One same anatomical left foot remains planted; anatomical right foot moves around it.','Ten rendered frames, exactly 670 ms, fixed 163 px anatomical scale.'],weapon_grip_track_source_y=PIVOTS,weapon_swing_plane='visible clockwise screen-plane arc, no foreshortening',shared_combo_guard='Original body guard at start/end, with normal grip at source y178 and no root offset.',root_motion_policy='Latest user fixed-foot request overrides prior forward root advance. Root displacement is zero; generated articulation transfers weight around the planted left foot.',support_foot={'anatomical':'left','screen_side':'right','constant_world_ball_contact':[330.484,325.0],'registration':'Each generated source is uniformly scaled at 0.408 and registered by measured opaque ball-of-sandal contact, never bbox normalized.'},gif_duration_unit_ms=10,source_prompt_files=['source-prompt.txt','arc-correction-prompt.txt'])
m['qa'].update(contact_response='push_standing',rear_step_anatomy=True,final_root_retained=False,fixed_support_foot=True,one_contact=True)
for i,r in enumerate(m['frames']):
 sy=PIVOTS[i];r['weapon_source_grip']=[64,sy];r['weapon_working_length_from_main_px']=sy-31
 dist=math.dist(*r['grip_world']);r['weapon_auxiliary_source_grip']=[64,sy-dist]
 r['anatomical_feet_world']={'left':r['screen_feet']['right'],'right':r['screen_feet']['left']}
 r['effect_layer']='Empty during this air swing; independent neutral impact emits only on confirmed target contact.';r['weapon_spin_phase']=None;r['body_height_scale_basis']='Original guard: fixed 0.337. Every new body pose, including corrected arm poses: fixed 0.408. No bbox-height normalization.'
 if r.get('contact'):
  a=math.radians(r['weapon_angle']);g=r['grip_world'][0];r['contact_point']=[g[0]+(sy-31)*math.sin(a),g[1]-(sy-31)*math.cos(a)]
# QA measures exported pixels, not only declared metadata.
qa={'action':'light_1_v3','expected_frames':10,'expected_duration_ms':670,'support_foot':'same anatomical left / screen right in every generated pose','frames':[]}
foot_review=Image.new('RGB',(1000,240),(37,43,52));d=ImageDraw.Draw(foot_review)
for i,r in enumerate(m['frames']):
 body=Image.open(OUT/f'body_canvas_{i+1:02}.png').convert('RGBA');ba=np.asarray(body)[:,:,3]
 w=Image.open(OUT/f'weapon_{i+1:02}.png').convert('RGBA');wa=np.asarray(w)[:,:,3]
 ys,xs=np.where(wa>180);pts=np.stack([xs,ys],axis=1);cov=np.cov(pts,rowvar=False);_,vec=np.linalg.eigh(cov);v=vec[:,-1]
 ref=np.array([math.sin(math.radians(r['weapon_angle'])),-math.cos(math.radians(r['weapon_angle']))]);v=v if np.dot(v,ref)>0 else -v
 measured=math.degrees(math.atan2(v[0],-v[1]));err=abs((measured-r['weapon_angle']+180)%360-180)
 # Near-floor sole pixels within +/- 3 px of fixed planted ball. No feet swap is permitted.
 px,py=330,325;yy,xx=np.where(ba[py-2:py+3,px-3:px+4]>80)
 nearest=min((math.hypot(x-3,y-2) for x,y in zip(xx,yy)),default=999)
 hand_hits=[]
 for gx,gy in r['grip_world']:
  ix,iy=round(gx),round(gy);hand_hits.append(bool(np.max(wa[iy-2:iy+3,ix-2:ix+3])>80))
 entry={'frame':i+1,'rendered_weapon_pca_angle_degrees':round(measured,3),'declared_angle_degrees':round(r['weapon_angle'],3),'angle_error_degrees':round(err,3),'fixed_contact_pixel_distance':round(nearest,3),'hand_shaft_pixel_contact':hand_hits,'weapon_bbox':w.getbbox(),'support_ball_world':r['screen_feet']['right']}
 qa['frames'].append(entry)
 # Two rows of magnified actual body footprints; crosshair is identical fixed world point.
 crop=body.crop((290,300,370,340));tile=Image.new('RGB',(200,120),(37,43,52));crop=crop.resize((200,100),Image.Resampling.NEAREST);tile.paste(crop,(0,20),crop.getchannel('A'));td=ImageDraw.Draw(tile);td.text((4,3),f'{i+1}: left pivot fixed',fill='white');td.line((100,20,100,119),fill=(240,80,90));td.line((0,82,199,82),fill=(240,80,90));foot_review.paste(tile,((i%5)*200,(i//5)*120))
 assert err<3,(i,err)
 assert nearest<=2,(i,nearest)
 assert all(hand_hits),(i,hand_hits)
 assert xs.min()>0 and xs.max()<base.W-1 and ys.min()>0 and ys.max()<base.H-1,(i,'weapon clipping')
im=Image.open(OUT/'normal.gif');ds=[]
for i in range(im.n_frames):im.seek(i);ds.append(im.info['duration'])
assert len(ds)==10 and sum(ds)==670 and all(x%10==0 for x in ds)
assert sum(bool(r.get('contact')) for r in m['frames'])==1
assert len({tuple(r['screen_feet']['right']) for r in m['frames']})==1
angles=[round(r['weapon_angle'],2) for r in m['frames']]
assert all(b>a for a,b in zip(angles[2:6],angles[3:7])),angles
m['actual_gif_durations_ms']=ds;m['actual_gif_total_ms']=sum(ds);m['actual_weapon_angles_degrees']=angles
qa.update(passed=True,actual_gif_frame_count=len(ds),actual_gif_durations_ms=ds,actual_gif_total_ms=sum(ds),rendered_active_arc_degrees=round(angles[6]-angles[2],2),single_contact_frame=6,fixed_pivot_world=[330.484,325.0],unchanged_previous_assets=True)
baseline=json.loads((OUT/'unchanged-baseline.json').read_text())
for action,hashes in baseline.items():
 for rel,digest in hashes.items():assert hashlib.sha256((P/action/rel).read_bytes()).hexdigest()==digest,(action,rel,'modified')
(OUT/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));(OUT/'QA.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2));foot_review.save(OUT/'footprint-pixel-QA.png')
shutil.copyfile(OUT/'normal.gif',OUT/'kennyo03-light1-fixed-pivot-arc-v3.gif')
(OUT/'REVISION.md').write_text('''Light 1 v3. New body-only key poses generated with built-in imagegen; targeted imagegen arm correction supplies the diagonal intermediates. The rendered attack now rotates the full staff through a clearly measured arc instead of translating a horizontal pole. Every frame registers the same anatomical left sandal ball to (330.484,325), with no support exchange or root translation. The anatomical right foot lifts, steps and recovers. Staff grip slides toward the tail only on contact/follow-through, then returns to normal guard. All visible hand centers contact the actual rendered shaft. Fixed source scales: 0.337 original guard and 0.408 all new poses; no per-frame bbox equalization. Exactly 10 encoded frames and 670 ms. One contact at frame 6. Independent body/weapon front-back/hand-occlusion/effect PNGs, normal/slow/body-only GIFs, source prompts, metadata and pixel QA included. Prior light1_v2, light2_v3, heavy and other existing actions are unchanged.\n''')
print(json.dumps({'qa':qa,'output':str(OUT)},ensure_ascii=False))
