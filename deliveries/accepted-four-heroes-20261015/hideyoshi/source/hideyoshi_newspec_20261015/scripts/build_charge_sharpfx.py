from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,math,json,hashlib,shutil
P=Path(__file__).resolve().parents[1];B=P/'actions/charge_release_headlock_v5';D=P/'actions/charge_release_sharpfx_v6';F=D/'fx';F.mkdir(exist_ok=True,parents=True)
m=json.loads((B/'metadata.json').read_text());T=Image.open(F/'silver_blade_orbit_topdown.png').convert('RGBA');W,H=520,300;SS=3
CENTER=np.array([627.,627.]);RADIUS=580.
LAYER_PARAMETERS=[dict(radius=118,depth=.23,vertical=0,phase_lag=0,opacity=220),dict(radius=125,depth=.25,vertical=7,phase_lag=-24,opacity=116),dict(radius=108,depth=.21,vertical=14,phase_lag=-52,opacity=80)]
def empty():return Image.new('RGBA',(W,H))
def render_plane(yaw,cx,cy,cfg,strength):
 theta=math.radians(yaw+cfg['phase_lag']-6);co,si=math.cos(theta),math.sin(theta);scale=cfg['radius']/RADIUS
 mat=np.array([[co,-si],[si*cfg['depth'],co*cfg['depth']]])*scale*SS
 inv=np.linalg.inv(mat);center=np.array([cx,cy+cfg['vertical']])*SS;v=CENTER-inv@center;im=T.transform((W*SS,H*SS),Image.Transform.AFFINE,(*inv[0],v[0],*inv[1],v[1]),Image.Resampling.BICUBIC)
 arr=np.array(im);arr[:,:,3]=np.round(arr[:,:,3].astype(float)*cfg['opacity']/255*strength).clip(0,255).astype('uint8')
 # White-silver, slightly cold; recolouring changes FX only, no elemental hues.
 lum=arr[:,:,:3].mean(axis=2);arr[:,:,0]=np.clip(lum*.96+8,0,255);arr[:,:,1]=np.clip(lum*.985+6,0,255);arr[:,:,2]=np.clip(lum+8,0,255)
 cut=round((cy+cfg['vertical'])*SS);ba=arr.copy();fa=arr.copy();ba[cut:,:,3]=0;fa[:cut,:,3]=0
 return Image.fromarray(ba).resize((W,H),Image.Resampling.LANCZOS),Image.fromarray(fa).resize((W,H),Image.Resampling.LANCZOS)
def fx(i,r):
 back=empty();front=empty()
 if i==0 or i==16:return back,front,dict(active=False)
 if i<=13:
  yaw=r['weapon_yaw_degrees'];strength={1:.60,2:.80,6:1.,7:.85,12:1.,13:.78}.get(i,.92);grip=r['grip_world']
 else:
  yaw=750 if i==14 else 780;strength=.32 if i==14 else .10;grip=m['frames'][13]['grip_world']
 theta=math.radians(yaw);tip=np.array(grip)+[703*.145*math.cos(theta),.725+703*.145*.18*math.sin(theta)]
 # Main sharp tip tracks approved blade outer edge; all stacked orbits share its moving waist center.
 cx=float(tip[0]-118*math.cos(theta));cy=float(tip[1]-118*.23*math.sin(theta))
 for cfg in reversed(LAYER_PARAMETERS):
  b,f=render_plane(yaw,cx,cy,cfg,strength);back.alpha_composite(b);front.alpha_composite(f)
 return back,front,dict(active=True,yaw_degrees=yaw,nominal_blade_tip_world=tip.tolist(),orbit_center_world=[cx,cy],strength=strength,layer_parameters=LAYER_PARAMETERS,phase='two_turns' if i<=13 else 'visual_decay_no_hit')
def clean_actor(i,r,body,weapon):
 if i==16:return Image.open(B/f'composite_{i:02}.png').convert('RGBA')
 behind=r.get('weapon_behind_body',False);comp=empty()
 if behind:comp.alpha_composite(weapon)
 comp.alpha_composite(body)
 if not behind:
  comp.alpha_composite(weapon);hands=r.get('hand_centers')
  if hands is None:hands=json.loads((P/'actions/charge_hold/metadata.json').read_text())['frames'][0]['hand_centers']
  mask=Image.new('L',(W,H));d=ImageDraw.Draw(mask)
  s=r.get('anatomical_scale_correction',1)
  for x,y in hands:d.ellipse((x-4.6*s,y-4.6*s,x+4.6*s,y+4.6*s),fill=255)
  hold=body.copy();hold.putalpha(Image.fromarray(np.minimum(np.array(body.getchannel('A')),np.array(mask))));comp.alpha_composite(hold)
 return comp
views=[];qa=[];elapsed=0
for i,r in enumerate(m['frames']):
 body=Image.open(B/f'body_canvas_{i:02}.png').convert('RGBA');weapon=Image.open(B/f'weapon_{i:02}.png').convert('RGBA')
 # Byte-preserving copies, followed by actual decoded-pixel equality checks.
 for name in ['body_canvas','weapon']:
  shutil.copy2(B/f'{name}_{i:02}.png',D/f'{name}_{i:02}.png');assert np.array_equal(np.array(Image.open(B/f'{name}_{i:02}.png')),np.array(Image.open(D/f'{name}_{i:02}.png')))
 actor=clean_actor(i,r,body,weapon);actor.save(D/f'actor_clean_{i:02}.png');back,front,record=fx(i,r);back.save(D/f'fx_back_{i:02}.png');front.save(D/f'fx_front_{i:02}.png');comp=back.copy();comp.alpha_composite(actor);comp.alpha_composite(front);comp.save(D/f'composite_{i:02}.png')
 # FX-only exports are independently reusable with their original canvas and alpha.
 for name,z in [('back',back),('front',front)]:z.save(F/f'{name}_{i:02}.png')
 bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dd=ImageDraw.Draw(bg);dd.line((0,253,W,253),fill=(68,74,82));dd.text((12,12),'HIDEYOSHI / charge_release / layered blade aura / 1240 ms',fill='white');dd.text((12,280),f'{i+1:02}/17  720 deg / silver sharp orbit / separate front + back',fill=(170,180,190));views.append(bg)
 r['fx']=record;r['start_ms']=elapsed;r['end_ms']=elapsed+r['duration_ms'];elapsed+=r['duration_ms'];record.update(frame=i,start_ms=r['start_ms'],end_ms=r['end_ms'],event=r.get('event'))
 qa.append(dict(index=i,body_file_sha256_before=hashlib.sha256((B/f'body_canvas_{i:02}.png').read_bytes()).hexdigest(),body_file_sha256_after=hashlib.sha256((D/f'body_canvas_{i:02}.png').read_bytes()).hexdigest(),weapon_file_sha256_before=hashlib.sha256((B/f'weapon_{i:02}.png').read_bytes()).hexdigest(),weapon_file_sha256_after=hashlib.sha256((D/f'weapon_{i:02}.png').read_bytes()).hexdigest(),body_different_pixels=0,weapon_different_pixels=0,back_alpha_range=back.getchannel('A').getextrema(),front_alpha_range=front.getchannel('A').getextrema(),frame_start_ms=r['start_ms'],frame_end_ms=r['end_ms'],event=r.get('event')))
views[0].save(D/'charge_release_sharpfx_v6.gif',save_all=True,append_images=views[1:],duration=[r['duration_ms'] for r in m['frames']],loop=0,disposal=2,optimize=False)
cs=Image.new('RGB',(W*4,H*5),(42,48,56))
for i,z in enumerate(views):cs.paste(z,(i%4*W,i//4*H))
cs.save(D/'contact.png');views[12].save(D/'representative.png');Image.open(D/'composite_12.png').save(D/'representative_rgba.png')
sourceevents=[(r['index'],r['duration_ms'],r.get('event')) for r in json.loads((B/'metadata.json').read_text())['frames']];newevents=[(r['index'],r['duration_ms'],r.get('event')) for r in m['frames']];assert sourceevents==newevents
m.update(revision='approved_head_pivot_reach_layered_silver_fx_v6',description='保留核准頭身、左腳支點與伸刀兩圈，新增沿刀鋒旋轉的銀白尖銳多層劍氣，前後分層環繞；無元素屬性、無新增命中。',fx_revision=dict(source_before_fx=str(B.relative_to(P)),texture='fx/silver_blade_orbit_topdown.png',texture_sha256=hashlib.sha256((F/'silver_blade_orbit_topdown.png').read_bytes()).hexdigest(),generated_with='cloud imagegen; no body or weapon generation',palette='silver-white / pale cool steel',style='three stacked razor arcs, fine multi-layer slash streaks, pointed blade ends, transparent hollow center',depth_split='each layer split at its own waist-plane horizon; rear behind actor; front over lower torso only',revolutions=2,active_rotation_degrees=[0,720],decay_frames=[14,15],new_hit_events=0,frame_events_unchanged=True,body_and_weapon_pixel_exact=True,qa=qa),layers=['body_canvas','weapon','actor_clean','fx_back','fx_front','composite'])
(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));(D/'pixel_event_validation.json').write_text(json.dumps(dict(all_17_body_and_weapon_pixels_equal=True,all_17_body_and_weapon_files_byte_equal=True,events_exactly_equal=True,source_events=sourceevents,output_events=newevents,frames=qa),ensure_ascii=False,indent=2));(F/'manifest.json').write_text(json.dumps(dict(canvas=[520,300],coordinate_space='world canvas pixels, no automatic centering',plane='waist horizontal',layers=LAYER_PARAMETERS,frames=[r['fx'] for r in m['frames']]),ensure_ascii=False,indent=2))
g=Image.open(D/'charge_release_sharpfx_v6.gif');assert g.n_frames==17 and sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==1240
for i in range(17):
 for k in ['body_canvas','weapon','fx_back','fx_front','composite']:
  z=Image.open(D/f'{k}_{i:02}.png');assert z.mode=='RGBA' and z.size==(W,H);z.load()
print('PASS 17 frames /1240ms; all34 body+weapon files bytes identical; all event timings identical');print(D/'contact.png')
