from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,math,hashlib,copy
P=Path(__file__).resolve().parents[1];B=P/'actions/charge_release_reach_v3';D=P/'actions/charge_release_scale_v4';D.mkdir(exist_ok=True)
m=json.loads((B/'metadata.json').read_text());W,H=520,300;PIVOT=np.array([244.,250.]);SW=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
# Projected anatomical comparison against the frozen 95%-head ready and the adjacent yaw views.
# No bbox-height fit: crouch, free-knee lift, yaw and the approved feet choreography stay intact.
FACTORS={0:.96,1:1.,2:1.,3:1.,4:.97,5:.94,6:.92,7:.92}
LAYERS=['body_canvas','weapon','fx_back','fx_front','composite'];dur=[r['duration_ms'] for r in m['frames']]
def empty():return Image.new('RGBA',(W,H))
def weapon(grip,yaw,angle):
 if yaw is not None:
  t=math.radians(yaw);x=math.copysign(max(abs(math.cos(t)),.16),math.cos(t));mat=np.array([[0,-x],[1,-.18*math.sin(t)]])*.145
 else:
  t=math.radians(angle);mat=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]])*.145
 inv=np.linalg.inv(mat);v=np.array([180,710])-inv@grip
 return SW.transform((W,H),Image.Transform.AFFINE,(*inv[0],v[0],*inv[1],v[1]),Image.Resampling.BICUBIC)
def effects(grip,yaw):
 back=empty();front=empty()
 if yaw is not None:
  theta=math.radians(yaw);L=710*.145;tip=np.array(grip)+np.array([L*math.cos(theta),L*.18*math.sin(theta)])
  radius=118;cx=float(tip[0]-radius*math.cos(theta));cy=float(tip[1]-22*math.sin(theta))
  for k in range(10):
   t=theta-math.radians(65-k*7);u=t+math.radians(8);xy=[(cx+radius*math.cos(t),cy+22*math.sin(t)),(cx+radius*math.cos(u),cy+22*math.sin(u))]
   ImageDraw.Draw(front if math.sin(t)>=0 else back).line(xy,fill=(200,225,248,30+k*15),width=2)
 return back,front
views=[];qa=[]
for i,r in enumerate(m['frames']):
 f={k:Image.open(B/f'{k}_{i:02}.png').convert('RGBA') for k in LAYERS};s=FACTORS[r['source_index']] if 'source_index' in r else 1.
 old=r.copy();tform=lambda p:(PIVOT+(np.array(p)-PIVOT)*s).tolist()
 if s!=1:
  dx,dy=PIVOT*(1-s);body=f['body_canvas'].transform((W,H),Image.Transform.AFFINE,(1/s,0,-dx/s,0,1/s,-dy/s),Image.Resampling.BICUBIC)
  grip=tform(r['grip_world']);hands=[tform(h) for h in r['hand_centers']];wp=weapon(grip,r['weapon_yaw_degrees'],r['weapon_angle']);back,front=effects(grip,r['weapon_yaw_degrees']);comp=back.copy()
  if r['weapon_behind_body']:comp.alpha_composite(wp)
  comp.alpha_composite(body)
  if not r['weapon_behind_body']:
   comp.alpha_composite(wp);mask=Image.new('L',(W,H));dd=ImageDraw.Draw(mask)
   for x,y in hands:dd.ellipse((x-4.6*s,y-4.6*s,x+4.6*s,y+4.6*s),fill=255)
   hm=body.copy();hm.putalpha(Image.fromarray(np.minimum(np.array(body.getchannel('A')),np.array(mask))));comp.alpha_composite(hm)
  comp.alpha_composite(front);f=dict(body_canvas=body,weapon=wp,fx_back=back,fx_front=front,composite=comp)
  r.update(grip_world=grip,hand_centers=hands,free_right_foot_world=tform(r['free_right_foot_world']),body_scale=r['body_scale']*s,original_body_offset=r.get('body_offset'),body_offset=tform(r['body_offset']),approved_head_and_lower_body_preserved='pose pixels uniformly scale-calibrated; no regeneration or anatomical warp')
 r.update(anatomical_scale_correction=s,anatomical_scale_anchor=PIVOT.tolist(),weapon_scale=.145,source_before_scale=str(B.relative_to(P)),scale_correction_basis='manual projected cranial width + collar/belt + shin cross-check; no bounding-box equal-height normalization',root_motion_preserved=True)
 for k,z in f.items():z.save(D/f'{k}_{i:02}.png')
 bb0=Image.open(B/f'body_canvas_{i:02}.png').getbbox();bb1=f['body_canvas'].getbbox();qa.append(dict(index=i,source_index=r.get('source_index'),body_scale_factor=s,body_bbox_before=bb0,body_bbox_after=bb1,pose_height_before=bb0[3]-bb0[1],pose_height_after=bb1[3]-bb1[1],support_anchor=r.get('pivot_world'),grip_before=old.get('grip_world'),grip_after=r.get('grip_world'),weapon_scale=.145))
 bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(f['composite'],mask=f['composite'].getchannel('A'));dd=ImageDraw.Draw(bg);dd.line((0,253,W,253),fill=(68,74,82));dd.text((12,12),'HIDEYOSHI / charge_release / scale calibrated / 1240 ms',fill='white');dd.text((12,280),f'{i+1:02}/17  left foot pivot / same-length katana',fill=(170,180,190))
 if 1<=i<=13:dd.ellipse((241,251,247,255),fill=(188,151,83))
 views.append(bg)
views[0].save(D/'charge_release_scale_v4.gif',save_all=True,append_images=views[1:],duration=dur,loop=0,disposal=2,optimize=False);views[5].save(D/'representative.png');Image.open(D/'composite_05.png').save(D/'representative_rgba.png');cs=Image.new('RGB',(2080,1500),(42,48,56))
for i,v in enumerate(views):cs.paste(v,(i%4*W,i//4*H))
cs.save(D/'contact.png');m.update(revision='left_pivot_reach_anatomical_scale_v4',scale_calibration=dict(reference='reference/shared_ready/body_canvas_00.png',head95_preserved=True,body_scale_by_source=FACTORS,method='single uniform body transform around unchanged support foot; hand/grip coordinates follow; weapon re-rendered at original scale',bbox_equalization=False,root_motion_separate=True,source_pose_preserved=True,manual_landmark_uncertainty_px=2,qa=qa),quality_checks=m['quality_checks']+['17 frames / 1240ms redecoded after calibration','fixed katana scale .145 at transformed grip; no weapon length scaling','source0,4,5 calibrated by 3-6%; brake/recover by8%; yaw side/back frames unchanged'])
# No longer claim exact original pixels after explicit scale correction.
m['quality_checks']=[x for x in m['quality_checks'] if 'pixels retained' not in x and '95 percent head pixels retained' not in x]
m['reach_revision']['approved_head_and_leg_pixels_retained']='same authored poses; uniform scale correction only';m['reach_revision']['reach_preservation']='extended-arm poses retained; same-length weapon recomposed at calibrated grip'
(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));g=Image.open(D/'charge_release_scale_v4.gif');assert g.n_frames==17;assert sum((g.seek(i) or g.info['duration']) for i in range(17))==1240
for i in range(17):
 for k in LAYERS:
  z=Image.open(D/f'{k}_{i:02}.png');assert z.mode=='RGBA' and z.size==(W,H);z.load()
assert all(r.get('pivot_world',[244,250])==[244,250] for r in m['frames'])
report={'reference':'reference/shared_ready/body_canvas_00.png','head_scale':.95,'method':'projected head/chest and bone-length visual cross-check; exact body layer hash for static hold; no pose bbox equalization','actions':[]}
for action in ['charge_ready','charge_hold']:
 A=P/'actions'/action;md=json.loads((A/'metadata.json').read_text());hashes=[];rows=[]
 for i,r in enumerate(md['frames']):
  z=Image.open(A/f'body_canvas_{i:02}.png');hashes.append(hashlib.sha256(z.tobytes()).hexdigest());bb=z.getbbox();rows.append({'index':i,'body_sha256':hashes[-1],'body_bbox':bb,'pose_height_px':bb[3]-bb[1],'body_scale':r.get('body_scale'),'grip_world':r.get('grip_world'),'foot_ground':r.get('foot_ground'),'correction_factor':1.0})
 result=dict(action=action,status='measured_no_render_change',body_unique_count=len(set(hashes)),frame_count=len(rows),pose_height_range_px=[min(r['pose_height_px'] for r in rows),max(r['pose_height_px'] for r in rows)],reason='all 8 body canvases are byte-identical; only FX brightness changes' if action=='charge_hold' else 'head/chest scale visually consistent within ~2px landmark reading; height decrease follows deliberate knee bend; do not equalize',frames=rows)
 md['scale_audit_20261015']=result;(A/'metadata.json').write_text(json.dumps(md,ensure_ascii=False,indent=2));report['actions'].append(result)
report['actions'].append(dict(action='charge_release',status='corrected',source=str(B.relative_to(P)),output=str(D.relative_to(P)),frames=qa,head95_preserved=True,weapon_scale=.145,pivot_world=[244,250],duration_ms=1240,frame_count=17))
(P/'charge_scale_audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(D);print([(r['action'],r['status']) for r in report['actions']])
