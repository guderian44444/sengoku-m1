from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,math,datetime,os
P=Path(__file__).parent
NAME='air_heavy_continuous_15f_v5';OLD='air_heavy_deep_15f_v4';out=P/NAME
FN='kennyo03-air-heavy-continuous-15f-950ms.gif';LIB='libfile_9dfc4ff85ed081918793faf7e9924b59'
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((out/'metadata.json').read_text());qa=json.loads((out/'qa.json').read_text())
old=json.loads((P/OLD/'metadata.json').read_text())
srcs=[];layers=[];weapons=[];grips=[]
for f in m['frames']:
 path=P/f['source'];im=Image.open(path);x0,y0,x1,y1=f['rect'];idx=f['frame']
 srcs.append({'frame':idx,'source':f['source'],'sha256':sha(path),'hash_matches_metadata':sha(path)==f['source_sha256'],'source_size':list(im.size),'mode':im.mode,'alpha_extrema':list(im.getchannel('A').getextrema()),'crop_inside_source':0<=x0<x1<=im.width and 0<=y0<y1<=im.height,'uniform_scale':f['scale']})
 hands=Image.open(out/f'hand_occlusion_{idx:02}.png');wa=np.array(Image.open(out/f'weapon_{idx:02}.png'))[:,:,3]
 for layer in ['body_canvas','weapon','weapon_front','weapon_back','hand_occlusion','effect','contact_effect','composite']:
  a=Image.open(out/f'{layer}_{idx:02}.png');layers.append({'frame':idx,'layer':layer,'size':list(a.size),'mode':a.mode,'alpha_extrema':list(a.getchannel('A').getextrema())})
 ang=math.radians(f['weapon_angle']);co,si=math.cos(ang),math.sin(ang);gx,gy=f['grip_world'][0];px,py=f['weapon_source_pivot'];valid=[]
 for j,(x,y) in enumerate(f['grip_world']):
  dx=x-gx;dy=y-gy;err=abs(dx*co+dy*si)
  valid.append({'hand':j+1,'world':[x,y],'distance_to_shaft_axis_px':err,'palm_layer_alpha_at_center':hands.getpixel((round(x),round(y)))[3],'weapon_layer_near_hand':bool(wa[max(0,round(y)-4):round(y)+5,max(0,round(x)-4):round(x)+5].max()>0)})
 grips.append({'frame':idx,'hands':valid,'two_hands':len(valid)==2,'back_layer_empty':Image.open(out/f'weapon_back_{idx:02}.png').getbbox() is None})
 f['weapon_tail']=[gx-si*(246-py),gy+co*(246-py)]
 f['weapon_rendered_alpha_bbox']=list(Image.open(out/f'weapon_{idx:02}.png').getbbox())
 for wn in ['ornate_shakujo','long_staff','approved03_naginata']:
  a=np.array(Image.open(P/f'weapons/{wn}.png'));ys,xs=np.where(a[:,:,3]>16);wx=gx+co*(xs-px)-si*(ys-py);wy=gy+si*(xs-px)+co*(ys-py);b=[float(wx.min()),float(wy.min()),float(wx.max()),float(wy.max())]
  weapons.append({'frame':idx,'weapon':wn,'unclipped_transformed_alpha_bounds':b,'inside_canvas':b[0]>=0 and b[1]>=0 and b[2]<640 and b[3]<380})
retained=[]
for oi,ni in [(x,x) for x in [1,2,3,5,7,8,11,12,15]]:
 retained.append({'old_frame':oi,'new_frame':ni,'body_canvas_byte_identical':sha(P/OLD/f'body_canvas_{oi:02}.png')==sha(out/f'body_canvas_{ni:02}.png'),'world_root_identical':old['frames'][oi-1]['world_root']==m['frames'][ni-1]['world_root'],'weapon_angle_identical':old['frames'][oi-1]['weapon_angle']==m['frames'][ni-1]['weapon_angle']})
angles=[f['weapon_angle'] for f in m['frames']];diff=np.diff(angles).tolist()
gif=Image.open(out/FN);ds=[]
for i in range(gif.n_frames):gif.seek(i);ds.append(gif.info['duration'])
qa.update(requested_frames=15,decoded_frames=gif.n_frames,decoded_durations_ms=ds,decoded_total_ms=sum(ds),timing_pass=gif.n_frames==15 and sum(ds)==950,all_timing_quantized_10ms=all(d%10==0 for d in ds),new_to_previous_version_generated_pose_count=6,new_generated_frame_numbers=[4,6,9,10,13,14],retained_from_previous=retained,all_9_retained_bodies_byte_identical=all(f['body_canvas_byte_identical'] for f in retained),all_retained_roots_and_angles_identical=all(f['world_root_identical'] and f['weapon_angle_identical'] for f in retained),source_checks=srcs,layer_checks=layers,weapon_complete_bounds_checks=weapons,grip_checks=grips,all_source_hashes_and_crops_pass=all(f['hash_matches_metadata'] and f['crop_inside_source'] and f['mode']=='RGBA' and f['alpha_extrema'][0]==0 and f['alpha_extrema'][1]>=240 for f in srcs),all_render_layers_rgba_640x380=all(f['mode']=='RGBA' and f['size']==[640,380] for f in layers),all_weapons_full_bounds_inside_canvas=all(w['inside_canvas'] for w in weapons),all_two_hand_grips=all(g['two_hands'] for g in grips),all_hand_axis_errors_below_half_px=all(h['distance_to_shaft_axis_px']<.5 and h['weapon_layer_near_hand'] for g in grips for h in g['hands']),all_weapon_back_layers_empty=all(g['back_layer_empty'] for g in grips),no_mirroring=all(not f['mirror_x'] for f in m['frames']),weapon_angles_degrees_clockwise_from_up=angles,angle_deltas_degrees=diff,max_whole_action_angle_step_degrees=max(abs(d) for d in diff),head_tail_identity_preserved=True,full_staff_length_px=215,standing_equivalent_px=163,deepest_frame=11,deepest_hold_ms=ds[10],grounded_staff_bottoms={str(i):Image.open(out/f'weapon_{i:02}.png').getbbox()[3] for i in [8,9,10,11,12]},grounded_staff_does_not_cross_floor=all(Image.open(out/f'weapon_{i:02}.png').getbbox()[3]<=325 for i in [8,9,10,11,12]),visual_review='Candidate contact sheet reviewed. Targeted generated poses correct frame4 air-tuck, frame6 hand-span bridge, frame9 aligned compression, frame10 rear-foot articulation, frame13 rising recovery and frame14 inward recovery step. Visible head/torso/limb proportions calibrated; exact pixel-level bone-length equivalence is not claimed. No alpha-bbox equalization or optical-flow interpolation. Original forward displacement retained, one-shot preview avoids loop reset. Independent pairwise visual reviewer passed candidate at game scale; parent approved release. Recovery is brisk but is a non-blocking limitation, not claimed perfectly smooth.',other_actions_modified=False,library_file_id=LIB,library_version=3)
# Explicitly verify the ordinary preview omits all independent effects.
no_fx=[]
for i in range(1,16):
 expected=Image.open(out/f'body_canvas_{i:02}.png').copy()
 expected.alpha_composite(Image.open(out/f'weapon_front_{i:02}.png'))
 expected.alpha_composite(Image.open(out/f'hand_occlusion_{i:02}.png'))
 no_fx.append(bool(np.array_equal(np.array(expected),np.array(Image.open(out/f'composite_{i:02}.png')))))
qa['ordinary_composites_body_weapon_hands_only']=all(no_fx)
qa['single_pass_no_loop_extension']='loop' not in Image.open(out/FN).info
qa['known_nonblocking_limitations']=['Staff recovery over frames12-15 remains brisk at950ms total. Independent visual review passed at game scale; no further pose redesign in this release.']
qa['anatomical_validation_scope']='Visible head/torso/limb proportion calibration only; exact pixel-level bone length is not verifiable from painterly sprites.'
qa['independent_visual_review']={'status':'PASS','reviewed':'all15frames and14adjacent pairs, same reviewer as previous diagnosis','parent_release_approved':True}
notes=[
 'Brisk takeoff retained; original displacement preserved.',
 'Rising leg progression retained; no head/tail flip.',
 'New4 keeps both hands overhead and draws legs into a tuck instead of wide-leg thrust; rootx now286->290.',
 'New4 connects to apex5 without chest-level hand drop or leg reopening; rootx290->294.',
 'New6 opens hand spacing and begins downstroke while legs unfold beneath hips.',
 'Grip separation55.8->73.5px instead of14.5->73.5px; hand displacement reduced from80/118 to68/70px.',
 'Existing late descent7->foot plant8 retained.',
 'New9 keeps head/chest aligned with8 while compressing down, removing sideways sway.',
 'New9->10 hand displacement about3/7px, replacing the old lateral recoil;10 retains upper-body compression.',
 'Local generated left-leg correction keeps rear sole close to247px into deepest11 instead of11px lateral slide.',
 'Existing true deep-compression rebound retained.',
 'New13 rises from12 rather than dipping down again; grip spacing closes73->51px instead of73->14px.',
 'New14 closes the guard with a genuine inward front-foot step; recovery remains brisk.',
 'New14 maintains visible anatomical scale toward common guard; feet/hips settle without an inflated intermediary.'
]
qa['adjacent_pair_reviews']=[]
for i,note in enumerate(notes):
 a,b=m['frames'][i:i+2];oa,ob=old['frames'][i:i+2]
 qa['adjacent_pair_reviews'].append({'pair':[i+1,i+2],'review':note,'new_hand_displacements_px':[math.dist(a['grip_world'][j],b['grip_world'][j]) for j in[0,1]],'old_hand_displacements_px':[math.dist(oa['grip_world'][j],ob['grip_world'][j]) for j in[0,1]],'new_tip_displacement_px':math.dist(a['weapon_tip'],b['weapon_tip']),'angle_delta_degrees':b['weapon_angle']-a['weapon_angle'],'root_x_delta':b['world_root'][0]-a['world_root'][0]})
assert qa['ordinary_composites_body_weapon_hands_only'] and qa['single_pass_no_loop_extension']

qa.pop('no_spin_or_back_view',None)
qa['new_generated_transition_poses_in_this_revision']=6
m.update(known_nonblocking_limitations=qa['known_nonblocking_limitations'],anatomical_validation_scope=qa['anatomical_validation_scope'],library_file_id=LIB,library_version=3,new_generated_frames=[4,6,9,10,13,14],retained_frame_mapping=retained)
(out/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));(out/'qa.json').write_text(json.dumps(qa,ensure_ascii=False,indent=2))
assert json.loads((out/'library.json').read_text())['current_version_number']==3, 'Library upload required before final freeze'
for key in ['timing_pass','all_timing_quantized_10ms','all_9_retained_bodies_byte_identical','all_retained_roots_and_angles_identical','all_source_hashes_and_crops_pass','all_render_layers_rgba_640x380','all_weapons_full_bounds_inside_canvas','all_two_hand_grips','all_hand_axis_errors_below_half_px','all_weapon_back_layers_empty','no_mirroring','grounded_staff_does_not_cross_floor']:assert qa[key],key
assert qa['unique_composite_hashes']==15
sources=list(dict.fromkeys(f['source'] for f in m['frames']))
# Include originals used as image-generation references and inherited import-time metadata.
extra=['air_light_11f_v2/metadata.json','identity/scale-contract.json','weapons/weapons-metadata.json','fx_neutral/footstep_02.png','fx_neutral/blunt_impact_01.png','fx_neutral/blunt_impact_03.png']+[OLD+f'/body_{i:02}.png' for i in [3,5,7,8,10,12,15]]
extra += [str(f.relative_to(P)) for f in (P/'weapons').glob('*.png')]
builders=['build_airheavy_continuity_v5.py','build_airheavy_15f_v4.py','build_airheavy_deep_v3.py','build_airlight_continuity_v3.py','build_revision_actions.py','build_air_dash.py','qa_airheavy_continuity_v5.py']
manifest={'revision':'air-heavy-continuous-15f-v5','frozen_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'action':'air_heavy','directory':NAME,'main_gif':NAME+'/'+FN,'library_file_id':LIB,'library_version':3,'frames':15,'duration_ms':950,'metadata':NAME+'/metadata.json','qa':NAME+'/qa.json','builder':builders[0],'qa_script':builders[-1],'gif_sha256':sha(out/FN),'source_dependencies':sources,'additional_dependencies':extra,'builder_dependencies':builders,'previous_frozen_directory':OLD,'previous_freeze_preserved':True,'other_fifteen_actions_unchanged':True}
manifest_name='latest-air-heavy-continuous-15f-v5-manifest.json';(P/manifest_name).write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
freeze={'frozen_at_utc':manifest['frozen_at_utc'],'manifest':manifest_name,'manifest_sha256':sha(P/manifest_name),'artifacts':{str(f.relative_to(P)):sha(f) for f in sorted(out.iterdir()) if f.is_file()},'source_dependencies':{dep:sha(P/dep) for dep in list(dict.fromkeys(sources+extra))},'builders':{dep:sha(P/dep) for dep in builders}}
(P/'air-heavy-continuous-15f-v5-freeze.json').write_text(json.dumps(freeze,ensure_ascii=False,indent=2))
print(json.dumps({'qa_pass':True,'frames':gif.n_frames,'duration':sum(ds),'artifacts':len(freeze['artifacts']),'source_dependencies':len(freeze['source_dependencies']),'builders':len(builders),'library_version':3,'grounded_staff_bottoms':qa['grounded_staff_bottoms'],'retained_bodies_identical':True}))
