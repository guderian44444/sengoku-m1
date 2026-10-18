from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib,math
D=Path(__file__).resolve().parents[1];I=json.load(open(D/'inventory.json'));A=json.load(open(D/'packaged-assets.json'))
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def relpath(p):
 p=Path(p)
 if p.is_absolute():
  try:return str(p.relative_to(D))
  except ValueError:return str(p)
 if str(p).startswith(D.name+'/'):return str(p)[len(D.name)+1:]
 return str(p)
def file(p):
 p=Path(p);im=Image.open(p);return {'path':str(p.relative_to(D)),'sha256':sha(p),'canvas_px':list(im.size),'mode':im.mode}
def goldfeet(im):
 a=np.array(im);rgb=a[:,:,:3].astype(float);v=rgb.max(2);y,x=np.where(a[:,:,3]>40)
 if not len(x):return [None,None]
 cutoff=y.min()+.76*(y.max()-y.min());mid=(x.min()+x.max())/2;r,g,b=np.moveaxis(rgb,2,0);m=(r>90)&(g>50)&(r>g*1.1)&(g>b*1.2)&(a[:,:,3]>90);Y,X=np.indices(m.shape);m&=Y>cutoff
 pts=[]
 for side in [X<mid,X>=mid]:
  yy,xx=np.where(m&side)
  if not len(xx):pts.append(None);continue
  bot=yy.max();near=yy>=bot-5;pts.append([round(float(np.mean(xx[near])),2),float(bot)])
 return pts

def anchors(k,i,row,im):
 method='copied authored artwork landmark; not runtime contact calibration';feet=None;root=None
 if k=='throw_reverse':return row['root_anchor_native'],row['fixed_sole_contacts_native'],'approved fixed native sole contacts and root'
 for first,second in [('support_sole_native','moving_sole_native'),('support_sole_native','passing_sole_native'),('original_support_sole','traveling_sole'),('front_sole_native','rear_sole_native')]:
  if first in row and second in row:feet=[row[first],row.get(second)];root=row[first];break
 if k in ['charge_ready','charge_hold']:
  root=[1200,1350]
  if k=='charge_ready':front=np.array(row['lower_sole_front']);rear=np.array(row['lower_sole_rear']);sc=row['uniform_camera_registration'];off=np.rint(np.array(root)-front*sc);feet=[(front*sc+off).tolist(),(rear*sc+off).tolist()]
  else:feet=[[1200,1350],[435,1358]]
  method='transformed original lower-body sole landmarks through native compositing registration'
 if k=='charge_release':
  root=[2000,1500] if i<21 else [2000+70*2.25/.58,1500]
  feet=goldfeet(im);method='root copied from native renderer anchor; foot samples estimated from lower gold sole pixels'
 if feet is None:
  feet=goldfeet(im);root=feet[1] if feet[1] else feet[0];method='image-derived lower gold sole extrema; advisory, not validated contact/grounding or collision'
 return root,feet,method

manifest={'schema':'nobunaga-approved-art-delivery-v1','version':'2026-10-16-approved-visible-layers','approval':I['approval'],'scope':'16 approved clips, immutable approved animation images; current-appearance layer extraction and art metadata','total_clips':16,'total_frames':232,'total_duration_ms':10520,'runtime_ready':False,'weapon_swap_ready':False,'coordinate_contract':{'native':'pixel coordinates, x right, y down, top-left origin; native canvas may vary per frame','layer_transforms':'identity (same frame canvas); preserve all approved pixels; never normalize bbox heights','preview':'per-frame scale/offset below describes art presentation only; legacy fields named world are preview/render-space, NOT gameplay world','runtime_world_displacement':None,'runtime_world_displacement_policy':'Not supplied or changed. Existing engine motion/events must be retained and verified separately. Do not copy preview offsets into gameplay motion.','angles':'clockwise degrees from image +x, base to visible blade tip; advisory curved-blade chord'},'fixed_standing_ruler':{'reference':'light_2/frames-composite/000.png','native_body_height_px':914,'measurement':'inherited manual standing hair-to-sole estimate, approx +/-5 px; excludes blade/cape; never remeasure crouch/rotation to resize','legacy_game_example_scale':.18,'legacy_game_reference_height_px':164.52,'policy':'Preserve each approved source/anatomical registration and per-frame review transform. No new per-frame or per-clip bbox normalization introduced.'},'verified':{'approved_gif_hashes_match':True,'approved_gif_timing_match':True,'native_source_art_not_redrawn':True,'layer_recomposition':'see validation-final.json','original_runtime_site_git_modified':False},'unverified_runtime':['weapon sockets/rig calibration','collision/hitbox/hurtbox','victim attachment and gameplay grab/release events','world-space displacement, facing/mirroring','engine state transitions and recovery/landing trigger wiring'],'clips':[]}
gaps=[];all_actor_hashes=[];footqa=Image.new('RGB',(1600,400*4),(40,44,50));footdraw=ImageDraw.Draw(footqa)
for ci,c in enumerate(I['clips']):
 k=c['key'];dur=c['approved_preview']['durations_ms'];n=len(dur);rev=k=='throw_reverse';ms=json.load(open(D/k/('frame-manifest.json' if rev else 'layers-visible-manifest.json')));mapping=None if rev else json.load(open(D/k/'source-mapping.json'))['frames'];rows=c['source_records'] if isinstance(c['source_records'],list) else [{} for _ in range(n)];frames=[];t=0
 for i,d in enumerate(dur):
  p=D/k/'frames-composite'/f'{i:03}.png';im=Image.open(p).convert('RGBA');m=ms[i];row=rows[i];root,feet,method=anchors(k,i,row,im)
  if rev:
   layers={name:{**val,'path':k+'/'+val['path']} for name,val in m['layer_paths'].items()};order=m['layer_order'];tr={'matrix_2x3':row['native_to_preview_affine']};grip=m['grip_palm_centers_native'];axis=m['weapon_axis'];behind='source occlusion baked; visible pixels only';hiddenflags={'torso_occludes_blade':axis.get('occluded_between_grip_and_blade',False),'visible_tip_clipped':axis.get('tip_clipped',False)}
  else:
   layers={name:{'path':m[name+'_path'],'sha256':m[name+'_sha256']} for name in ['body','weapon','hand_occlusion']};order=m['layer_order_back_to_front'];tr=mapping[i]['source_to_review'];grip={'primary':m.get('grip_art_px'),'additional':m.get('additional_hand_regions',[])};axis={'base':m.get('blade_base_art_px'),'visible_tip':m.get('blade_tip_art_px'),'clockwise_angle_deg':m.get('blade_projected_angle_clockwise_from_right_deg',m.get('blade_angle_deg')),'status':'image-derived/manual advisory; not runtime socket'};behind=m.get('weapon_behind_body',m.get('visible_weapon_depth'));hiddenflags={'likely_body_blade_underlap_pixels_heuristic':m.get('likely_body_hidden_by_blade_pixels'),'hilt_guard_contents':m.get('weapon_contents','visible sword partition; semantic boundaries approximate')}
  actorp=D/k/'layers-native'/'actor'/f'{i:03}.png' if k=='charge_release' and i>0 else p;all_actor_hashes.append(sha(actorp))
  fm={'frame':i,'start_ms':t,'duration_ms':d,'end_ms':t+d,'master':file(p),'approved_review':A[k]['approved_review_frames'][i],'layers':layers,'layer_order_back_to_front':order,'layer_transform_native':[1,0,0,0,1,0],'root_art_native_px':root,'foot_art_native_px':feet,'root_foot_status':method,'grip_art_native_px':grip,'weapon_axis':axis,'weapon_depth':behind,'native_to_preview':tr,'preview_translation_is_world_movement':False,'runtime_world_displacement':None,'runtime_socket_verified':False,'collision_verified':False,'runtime_event_verified':False,'hidden_body_fill_complete':False,'hidden_weapon_complete':False,'separate_layer_movement_safe':False,'source_art_metadata_record':{'inventory_file':'inventory.json','clip_key':k,'source_record_index':i}}
  if k=='charge_release' and i>0:fm['fx_back_front']=[file(D/k/'layers-native'/name/f'{i:03}.png') for name in ['fx_back','fx_front']];fm['actor_without_fx']=file(actorp)
  frames.append(fm);gaps.append({'clip':k,'frame':i,'actor_sha256':sha(actorp),'hidden_body_fill':'not drawn/verified','hidden_weapon_under_hand_or_torso':'not drawn/verified','independent_weapon_swap_safe':False,**hiddenflags});t+=d
 # Pixel-level loop endpoints are useful, not inferred seamless gameplay transitions.
 first=np.array(Image.open(D/k/'frames-approved-review'/'000.png').convert('RGB'));last=np.array(Image.open(D/k/'frames-approved-review'/f'{n-1:03}.png').convert('RGB'));endpoint=first.shape==last.shape and np.array_equal(first,last)
 events=[]
 def ev(name,f,origin):events.append({'name':name,'frame':f,'time_ms':sum(dur[:f]),'scope':'art-review marker only','basis':origin,'runtime_wired':False})
 if k in ['charge_hold','grab_hold']:ev('loop_boundary',n,'approved review endpoints equal' if endpoint else 'intended hold loop; endpoint pixels differ')
 else:ev('clip_end_recovery_boundary',n,'approved timing; engine next-state contract must remain existing')
 if k in {'light_1':9,'light_2':7,'air_light':13,'air_heavy':11}:ev('visual_landing',{'light_1':9,'light_2':7,'air_light':13,'air_heavy':11}[k],'approved step/jump artwork or authored boot-height curve; advisory landing marker')
 if k=='throw_reverse':ev('visual_left_hand_release',7,'approved sequence release midpoint');ev('recovery_to_sword_guard_start',9,'approved recovery sequence')
 if k=='throw_forward':ev('recovery_to_sword_guard_start',9,'approved reuse_grab_start recovery sequence')
 if k=='charge_release':
  for name,f in [('visual_fx_compression',19),('visual_fx_outward_impulse',20),('visual_fx_residual',22),('visual_fx_clear',23)]:ev(name,f,'original authored FX stage')
 clip={'key':k,'status':'approved artwork; layered extraction and metadata','frame_count':n,'duration_ms':sum(dur),'durations_ms':dur,'approved_preview':A[k]['preview'],'preview_only':True,'native_masters':'%s/frames-composite'%k,'representative':A[k]['representative'],'frames_manifest':f'{k}/delivery-frames.json','loop_contract':{'intended_hold_loop':k in ['charge_hold','grab_hold'],'first_last_approved_review_pixels_identical':bool(endpoint),'gif_loops_for_review_only':True,'do_not_infer_attack_last_to_first_is_state_transition':True},'art_events':events,'existing_art_markers_preserved':c['art_event_markers'],'layers_scope':'current approved appearance, visible-pixel ownership; hidden underlaps incomplete','grip_metadata_missing_frames':[f['frame'] for f in frames if not any(v is not None and v!=[] for v in f['grip_art_native_px'].values())],'coordinate_manifest':f'{k}/delivery-frames.json'}
 (D/k/'delivery-frames.json').write_text(json.dumps(frames,ensure_ascii=False,indent=2));manifest['clips'].append(clip)
 # Representative coordinate QA frame0 with root/sole labels.
 im=Image.open(D/k/'frames-composite'/'000.png').convert('RGBA');bg=Image.new('RGBA',im.size,(40,44,50,255));bg.alpha_composite(im);dr=ImageDraw.Draw(bg)
 for pt in frames[0]['foot_art_native_px']:
  if pt:xx,yy=pt;dr.ellipse((xx-12,yy-12,xx+12,yy+12),fill='lime')
 pt=frames[0]['root_art_native_px']
 if pt:xx,yy=pt;dr.line((xx-25,yy,xx+25,yy),fill='cyan',width=5);dr.line((xx,yy-25,xx,yy+25),fill='cyan',width=5)
 bg.thumbnail((400,360));xx=ci%4*400;yy=ci//4*400;footqa.paste(bg,(xx,yy+30));footdraw.text((xx+10,yy+7),k,fill='white')
manifest['hidden_fill_audit']={'play_frames':len(gaps),'unique_actor_masters':len(set(all_actor_hashes)),'meaning':'upper bound of unique actors needing underlap review, not count of required redraws','per_frame_file':'weapon-swap-gaps.json','approved_composites_unchanged':True,'new_weapon_work_policy':'Add hidden-fill alternatives only where a selected replacement weapon exposes missing body/weapon pixels; do not alter approved master or extend clipped approved art.'}
(D/'delivery-manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2));(D/'weapon-swap-gaps.json').write_text(json.dumps(gaps,indent=2));footqa.save(D/'qa'/'art-root-foot-reference.jpg',quality=94)
print('manifest',len(manifest['clips']),sum(x['frame_count'] for x in manifest['clips']),len(set(all_actor_hashes)))
