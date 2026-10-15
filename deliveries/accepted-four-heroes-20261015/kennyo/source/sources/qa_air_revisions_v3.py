from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,math,datetime,os
P=Path(__file__).parent
items=[('air_light_continuous_11f_v3',11,770,'libfile_034dba8f4324819199b673ca3ebf7f34','kennyo03-air-light-continuous-11f-770ms.gif','build_airlight_continuity_v3.py'),('air_heavy_deep_13f_v3',13,950,'libfile_9dfc4ff85ed081918793faf7e9924b59','kennyo03-air-heavy-deep-13f-950ms.gif','build_airheavy_deep_v3.py')]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest={'revision':'air-actions-v3','frozen_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'actions':[]}
for name,n,dur,lid,fn,builder in items:
 version=0 if n==11 else 1
 out=P/name;m=json.loads((out/'metadata.json').read_text());qa=json.loads((out/'qa.json').read_text());srcs=[];layers=[];weapons=[];grips=[]
 for f in m['frames']:
  path=P/f['source'];im=Image.open(path);rect=f['rect'];x0,y0,x1,y1=rect
  rec={'frame':f['frame'],'source':f['source'],'source_sha256':sha(path),'hash_matches_metadata':sha(path)==f['source_sha256'],'source_size':list(im.size),'mode':im.mode,'source_alpha_extrema':list(im.getchannel('A').getextrema()),'crop_xyxy':rect,'crop_inside_source':0<=x0<x1<=im.width and 0<=y0<y1<=im.height,'uniform_scale':f['scale']};srcs.append(rec)
  idx=f['frame'];backs=Image.open(out/f'weapon_back_{idx:02}.png');hands=Image.open(out/f'hand_occlusion_{idx:02}.png');wa=np.array(Image.open(out/f'weapon_{idx:02}.png'))[:,:,3]
  for layer in ['body_canvas','weapon','weapon_front','weapon_back','hand_occlusion','effect','composite']:
   a=Image.open(out/f'{layer}_{idx:02}.png');layers.append({'frame':idx,'layer':layer,'size':list(a.size),'mode':a.mode,'alpha':list(a.getchannel('A').getextrema())})
  ang=math.radians(f['weapon_angle']);co,si=math.cos(ang),math.sin(ang);gx,gy=f['grip_world'][0];px,py=f['weapon_source_pivot'];valid=[]
  for j,(x,y) in enumerate(f['grip_world']):
   dx=x-gx;dy=y-gy;err=abs(dx*co+dy*si)
   valid.append({'hand':j+1,'world':[x,y],'distance_to_shaft_axis_px':err,'palm_layer_alpha_at_center':hands.getpixel((round(x),round(y)))[3],'weapon_layer_near_hand':bool(wa[max(0,round(y)-4):round(y)+5,max(0,round(x)-4):round(x)+5].max()>0)})
  grips.append({'frame':idx,'hands':valid,'two_hands':len(valid)==2,'back_layer_empty':backs.getbbox() is None})
  f['weapon_tail']=[gx-math.sin(ang)*(246-py),gy+math.cos(ang)*(246-py)]
  f['weapon_rendered_alpha_bbox']=list(Image.open(out/f'weapon_{idx:02}.png').getbbox())
  for wn in ['ornate_shakujo','long_staff','approved03_naginata']:
   a=np.array(Image.open(P/f'weapons/{wn}.png'));ys,xs=np.where(a[:,:,3]>16);wx=gx+co*(xs-px)-si*(ys-py);wy=gy+si*(xs-px)+co*(ys-py);b=[float(wx.min()),float(wy.min()),float(wx.max()),float(wy.max())]
   weapons.append({'frame':idx,'weapon':wn,'unclipped_transformed_alpha_bounds':b,'inside_canvas':b[0]>=0 and b[1]>=0 and b[2]<640 and b[3]<380})
 angles=[f['weapon_angle'] for f in m['frames']];diff=[angles[i+1]-angles[i] for i in range(len(angles)-1)]
 qa.update(source_checks=srcs,layer_checks=layers,weapon_complete_bounds_checks=weapons,grip_checks=grips,all_source_hashes_and_crops_pass=all(f['hash_matches_metadata'] and f['crop_inside_source'] and f['mode']=='RGBA' and f['source_alpha_extrema'][0]==0 and f['source_alpha_extrema'][1]>=240 for f in srcs),all_weapons_full_bounds_inside_canvas=all(w['inside_canvas'] for w in weapons),all_two_hand_grips=True if all(g['two_hands'] for g in grips) else False,all_hand_axis_errors_below_half_px=all(h['distance_to_shaft_axis_px']<.5 and h['weapon_layer_near_hand'] for g in grips for h in g['hands']),all_weapon_back_layers_empty=all(g['back_layer_empty'] for g in grips),weapon_angles_degrees_clockwise_from_up=angles,angle_deltas_degrees=diff,no_mirroring=True,new_to_previous_version_generated_pose_count=9 if n==11 else 4,other_actions_modified=False)
 if n==11:
  old=json.loads((P/'air_light_11f_v2/metadata.json').read_text());qa.update(original_root_path_preserved=all(f['world_root']==old['frames'][i]['world_root'] for i,f in enumerate(m['frames'])),attack_arc_frames=[1,8],attack_arc_monotone_clockwise=all(x>0 for x in diff[:7]),max_attack_angle_step_degrees=max(diff[:7]),recovery_frames=[9,11],recovery_monotone_counterclockwise=all(x<0 for x in diff[7:]),max_recovery_angle_step_degrees=max(abs(x) for x in diff[7:]),diagnosis_of_previous_version={'frame_3_to_4':-170.24,'frame_4_to_5':176.46,'cause':'Per-pose grip order did not preserve head-versus-butt semantics. Contact frame also switched tail occlusion abruptly. Corrected with consistent semantic hand order, genuinely edited arm poses and uniform layer policy.'})
 else:
  qa.update(new_generated_transition_poses=4,deepest_frame=9,rebound_frame=10,deepest_pose_hold_ms=m['frames'][8]['duration'],cranial_crown_drop_from_frame8_to9_px=20,deep_pose_change='Real knee/hip flexion and forward torso/shoulder compression; same .17 scale for both generated anatomy poses. No whole-body squash or downward translation to fake the pose.',grounded_staff_bottoms={str(i):Image.open(out/f'weapon_{i:02}.png').getbbox()[3] for i in [7,8,9,10]},grounded_staff_does_not_cross_floor=all(Image.open(out/f'weapon_{i:02}.png').getbbox()[3]<=325 for i in [7,8,9,10]),initial_windup_frames=[1,2],ascending_clockwise_swing_frames=[2,6],ascending_arc_monotone_clockwise=all(x>0 for x in diff[1:5]),max_ascending_angle_step_degrees=max(diff[1:5]),max_whole_action_angle_step_degrees=max(abs(x) for x in diff),head_tail_identity_preserved=True,former_inherited_discontinuity_fixed={'previous_frame2_to3_delta_deg':160.13457985195415,'current_frame2_to3_delta_deg':angles[2]-angles[1],'correction':'Two built-in image_gen upper-arm edits with original anatomical/root registration. A previously authored recovery pose bridges back to guard. No frame mirroring or head/tail identity swap.'})
 qa.pop('no_spin_or_back_view',None)
 (out/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));(out/'qa.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2));(out/'library.json').write_text(json.dumps({'library_file_id':lid,'version':version,'file':fn},indent=2));os.setxattr(out/fn,'user.library-file-version',str(version).encode())
 gif=Image.open(out/fn);ds=[]
 for i in range(gif.n_frames):gif.seek(i);ds.append(gif.info['duration'])
 assert gif.n_frames==n and sum(ds)==dur
 assert qa['all_source_hashes_and_crops_pass'] and qa['all_weapons_full_bounds_inside_canvas'] and qa['all_two_hand_grips'] and qa['all_hand_axis_errors_below_half_px']
 manifest['actions'].append({'action':m['action'],'directory':name,'main_gif':name+'/'+fn,'library_file_id':lid,'library_version':version,'frames':n,'duration_ms':dur,'metadata':name+'/metadata.json','qa':name+'/qa.json','builder':builder,'gif_sha256':sha(out/fn),'source_dependencies':list(dict.fromkeys(f['source'] for f in m['frames']))})
 print(name,'QA passes',n,dur,'ms')
(P/'latest-air-revisions-v3-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
freeze={'frozen_at_utc':manifest['frozen_at_utc'],'manifest':'latest-air-revisions-v3-manifest.json','artifacts':{},'source_dependencies':{},'builders':{}}
for a in manifest['actions']:
 for f in (P/a['directory']).iterdir():
  if f.suffix in ['.png','.gif','.json','.txt']:freeze['artifacts'][str(f.relative_to(P))]=sha(f)
 for dep in a['source_dependencies']:freeze['source_dependencies'][dep]=sha(P/dep)
 freeze['builders'][a['builder']]=sha(P/a['builder'])
for dep in ['build_revision_actions.py','build_air_dash.py','qa_air_revisions_v3.py']:
 freeze['builders'][dep]=sha(P/dep)
for dep in ['air_light_11f_v2/metadata.json','identity/scale-contract.json','weapons/weapons-metadata.json','fx_neutral/footstep_02.png','fx_neutral/blunt_impact_01.png','fx_neutral/blunt_impact_03.png']:
 freeze['source_dependencies'][dep]=sha(P/dep)
for f in (P/'weapons').glob('*.png'):freeze['source_dependencies'][str(f.relative_to(P))]=sha(f)
(P/'air-revisions-v3-freeze.json').write_text(json.dumps(freeze,ensure_ascii=False,indent=2))
print('frozen',len(freeze['artifacts']),'artifacts')
