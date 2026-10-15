from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
from scipy import ndimage
import numpy as np,json,hashlib,math,copy
from build_revision_actions import K
from build_airheavy_15f_v4 import cfg as prior
P=Path(__file__).parent;W,H=640,380;FLOOR=325
NAME='air_heavy_continuous_15f_v5'
cfg=copy.deepcopy(prior)
def registered(name,scale,origin,grips,event,root,feet=None,**kw):
 im=Image.open(P/NAME/(name+'-source.png'));ox,oy=origin
 return K(NAME+'/'+name+'-source.png',[0,0,im.width,im.height],[(root[0]-ox)/scale,(root[1]-oy)/scale],grips,event,scale=scale,dx=root[0]-286,air=325-root[1],feet=feet,new_pose=True,new_to_v5=True,**kw)
# Registration uses visible head/torso landmarks and actual soles, not alpha bounds.
cfg[3]=registered('rising-overhead-corrected',.155,[201.5,88.6],[[640,150],[970,123]],'rising_overhead_tucked_knee_bridge',[290,283],weapon_grip=[64,155])
cfg[5]=registered('descent-opening',.155,[203.5,105.4],[[716,126],[897,437]],'descending_arms_open_progressively',[301,293],weapon_grip=[64,170])
cfg[8]=registered('landing-aligned',.129,[222.74,172.91],[[702,578],[1182,890]],'landing_aligned_vertical_compression',[308,325],feet={'left':[170,1179],'right':[1159,1179]},landing=True,weapon_grip=[64,165])
# Candidate uses genuine local leg edit, preserving upper-body compression.
cfg[9]=registered('compression-foot-minimal',.13,[218.86,176.41],[[705,554],[1152,858]],'landing_compression_fixed_rear_foot',[308,325],feet={'left':[215,1143],'right':[1180,1143]},landing=True,weapon_grip=[64,153])
cfg[12]=registered('recovery-low',.133,[224.54,166.863],[[733,429],[1113,371]],'recover_raise_torso_gradual_hand_close',[308,325],feet={'left':[115,1189],'right':[1118,1189]},weapon_grip=[64,170])
cfg[13]=registered('recovery-rise-step',.133,[212,165.4],[[700,511],[739,385]],'recover_close_step_guard_transition',[308,325],feet={'left':[280,1200],'right':[970,1181]},weapon_grip=[64,178])
durations=[50,50,60,60,60,50,50,50,50,50,100,60,60,70,130]
sets={NAME:('air_heavy',cfg,durations,950)}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def clean(im,rect):
 a=np.array(im.crop(rect));lab,n=ndimage.label(a[:,:,3]>24);c=np.bincount(lab.ravel());c[0]=0;keep=ndimage.binary_dilation(lab==c.argmax(),iterations=2);a[:,:,3]=np.where(keep,a[:,:,3],0);return Image.fromarray(a)
def weapon_transform(im,piv,ang,grip):
 t=math.radians(ang);co,si=math.cos(t),math.sin(t);x,y=piv
 return im.transform((W,H),Image.Transform.AFFINE,(co,si,grip[0]-co*x-si*y,-si,co,grip[1]+si*x-co*y),Image.Resampling.BICUBIC)
def preview(im,act,event,idx):
 c=Image.new('RGB',(W,H),(37,43,52));c.paste(im,mask=im.getchannel('A'));d=ImageDraw.Draw(c);d.line((25,FLOOR,615,FLOOR),fill=(67,75,86));d.text((15,15),f'KENNYO 03 | {act} | 163 px equivalent',fill=(220,225,230));d.text((15,356),str(idx+1)+'  '+event,fill=(180,190,200));return c

def build(name):
 action,cfg,durs,target=sets[name];out=P/name;out.mkdir(exist_ok=True);frames=[];bodyonly=[];records=[];alternates={n:[] for n in ['long_staff','approved03_naginata']};comps=[]
 for i,f in enumerate(cfg):
  src=Image.open(P/f['source']).convert('RGBA');x0,y0,x1,y1=f['rect'];raw=clean(src,f['rect']);s=f['scale'];rx,ry=f['root_source'];root=[286+f.get('dx',0),FLOOR-f.get('air_height',0)];ox=root[0]-(rx-x0)*s;oy=root[1]-(ry-y0)*s
  if f.get('front_anchor'):
   fx,fy=f['front_anchor'];ox=f.get('front_world',388)-(fx-x0)*s;oy=FLOOR-(fy-y0)*s
  body=Image.new('RGBA',(W,H));body.alpha_composite(raw.resize((round(raw.width*s),round(raw.height*s)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
  grips=[[ox+(x-x0)*s,oy+(y-y0)*s] for x,y in f['grips']];angle=f.get('angle')
  if len(grips)>1:angle=math.degrees(math.atan2(grips[1][0]-grips[0][0],-(grips[1][1]-grips[0][1])))
  pivot=f.get('weapon_grip',[64,178]);hands=Image.new('RGBA',(W,H))
  for gx,gy in f['grips']:
   rad=max(11,round(5.2/s));patch=src.crop((gx-rad,gy-rad,gx+rad,gy+rad));mask=Image.new('L',patch.size);ImageDraw.Draw(mask).ellipse((1,1,2*rad-2,2*rad-2),fill=255);patch.putalpha(Image.fromarray(np.minimum(np.array(patch.getchannel('A')),np.array(mask))));patch=patch.resize((round(rad*2*s),round(rad*2*s)),Image.Resampling.LANCZOS);hands.alpha_composite(patch,(round(ox+(gx-rad-x0)*s),round(oy+(gy-rad-y0)*s)))
  fx=Image.new('RGBA',(W,H))
  if f.get('plant') or f.get('landing'):
   dust=Image.open(P/'fx_neutral/footstep_02.png').convert('RGBA');fx.alpha_composite(dust,(round(root[0]-32),FLOOR-44))
  for wn in ['ornate_shakujo','long_staff','approved03_naginata']:
   wi=Image.open(P/f'weapons/{wn}.png').convert('RGBA');weapon=weapon_transform(wi,grips[0],angle,pivot);back=Image.new('RGBA',(W,H));front=weapon.copy()
   if False: # Consistent front shaft, then actual palm masks.
    yy,xx=np.mgrid[0:H,0:W];t=math.radians(angle);sel=(xx-grips[0][0])*math.sin(t)-(yy-grips[0][1])*math.cos(t)>=-3;a=np.array(weapon);ba=a.copy();fa=a.copy();ba[:,:,3]=np.where(sel,0,a[:,:,3]);fa[:,:,3]=np.where(sel,a[:,:,3],0);back=Image.fromarray(ba);front=Image.fromarray(fa)
   co=Image.new('RGBA',(W,H));co.alpha_composite(back);co.alpha_composite(body);co.alpha_composite(front);co.alpha_composite(hands)
   if wn=='ornate_shakujo':
    comps.append(co);frames.append(preview(co,action,f['event'],i))
    for layer,im in [('body',raw),('body_canvas',body),('weapon',weapon),('weapon_back',back),('weapon_front',front),('hand_occlusion',hands),('effect',fx),('composite',co)]:im.save(out/f'{layer}_{i+1:02}.png')
   else:alternates[wn].append(preview(co,action,f['event'],i))
  bodyonly.append(preview(body,action,f['event'],i));t=math.radians(angle);tip=[grips[0][0]+math.sin(t)*(pivot[1]-31),grips[0][1]-math.cos(t)*(pivot[1]-31)]
  records.append(dict(f,frame=i+1,duration=durs[i],start_ms=sum(durs[:i]),source_sha256=sha(P/f['source']),source_crop_xyxy=f['rect'],uniform_source_scale=s,render_origin=[ox,oy],world_root=root,ground_root=[root[0],FLOOR],grip_world=grips,weapon_angle=angle,weapon_source_pivot=pivot,aux_grip_source=([64,pivot[1]-math.dist(grips[0],grips[1])] if len(grips)>1 else None),weapon_real_length_px=215,weapon_tip=tip,contact_point=tip if f.get('contact') else None,screen_feet={k:[ox+(p[0]-x0)*s,oy+(p[1]-y0)*s] for k,p in f.get('feet',{}).items()},weapon_spin_phase=None,weapon_projection=1))
 def gif(fn,ims,ds):ims[0].save(out/fn,save_all=True,append_images=ims[1:],duration=ds,disposal=2,optimize=False)
 gif('normal.gif',frames,durs);gif('slow.gif',frames,[v*3 for v in durs]);gif('body_only.gif',bodyonly,durs)
 for wn,ims in alternates.items():gif('alternate-'+wn+'.gif',ims,durs)
 gif('left-facing-qa.gif',[preview(ImageOps.mirror(c),action,cfg[i]['event'],i) for i,c in enumerate(comps)],durs)
 sheet=Image.new('RGB',(W*3,H*math.ceil(len(cfg)/3)),(37,43,52))
 for i,im in enumerate(frames):sheet.paste(im,((i%3)*W,(i//3)*H))
 sheet.save(out/'contact.png');ci=next(i for i,f in enumerate(cfg) if f.get('contact'));frames[ci].save(out/'poster.png')
 # Contact-only FX demonstration is separate from no-target game preview.
 contacts=[]
 for i,co in enumerate(comps):
  hit=Image.new('RGBA',(W,H))
  if i in [ci,ci+1]:
   burst=Image.open(P/f'fx_neutral/blunt_impact_{1 if i==ci else 3:02}.png').convert('RGBA');pt=records[ci]['weapon_tip'];hit.alpha_composite(burst,(round(pt[0]-32),round(pt[1]-32)))
  hit.save(out/f'contact_effect_{i+1:02}.png');cp=co.copy();cp.alpha_composite(hit);contacts.append(preview(cp,action,'contact FX only / '+cfg[i]['event'],i))
 gif('contact_preview.gif',contacts,durs)
 meta={'action':action,'version':name,'standing_equivalent_px':163,'preview_canvas':[W,H],'source_provenance':'Built-in image_gen authored anatomical poses. Deterministic cropping, fixed anatomical scale by source, registration and composition only. No optical flow or duplicate-frame padding.','scale_contract':'../identity/scale-contract.json','default_weapon':'../weapons/ornate_shakujo.png','weapon_physical_length_px':215,'weapon_length_fixed':True,'hand_grip_mode':'both hands near tail' if action in ['light_3','dash_heavy'] else 'measured two-hand staff grip','body_weapon_fx_hand_layers_separate':True,'runtime_integrated':False,'frames':records,'total_duration_ms':sum(durs),'frame_count':len(records),'motion_description':('Front three-quarter remains visible; small shoulder/waist rotation only. One upper-left to lower-right diagonal sweep; no back view, no full circle.' if action=='light_3' else 'Running straight forward thrust, both hands on tail segment, arms extend, front foot stays fixed through contact and recovery; no diagonal sweep.' if action=='dash_heavy' else 'Three newly generated distinct anatomical transition poses inserted; airborne root is separate from pose and body scale.'),'user_override_ids':(['Sentinel_8da189a409e881918219e65f31757be3','Sentinel_baa53fc1f6a08191be1c2472acc610b5'] if action=='light_3' else ['Sentinel_871e0cd3429c8191ac435e773964808e'] if action=='dash_heavy' else ['Sentinel_b08aef632a44819189f25fd3c3ead857'] if action=='air_light' else ['Sentinel_14b7d4340f94819196c2dcee5dc7311e'])}
 (out/'metadata.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
 dec=Image.open(out/'normal.gif');decoded=[]
 for j in range(dec.n_frames):dec.seek(j);decoded.append(dec.info['duration'])
 bounds=[]
 for i,c in enumerate(comps):
  a=np.array(c)[:,:,3];bounds.append({'frame':i+1,'edge_pixels':int((a[0]>16).sum()+(a[-1]>16).sum()+(a[:,0]>16).sum()+(a[:,-1]>16).sum()),'alpha':list(c.getchannel('A').getextrema())})
 qa={'requested_frames':len(cfg),'decoded_frames':dec.n_frames,'requested_duration_ms':target,'decoded_durations_ms':decoded,'decoded_total_ms':sum(decoded),'all_timing_quantized_10ms':all(d%10==0 for d in decoded),'timing_pass':len(cfg)==dec.n_frames and sum(decoded)==target,'bounds':bounds,'unique_composite_hashes':len(set(sha(out/f'composite_{i+1:02}.png') for i in range(len(cfg)))),'new_generated_transition_poses':sum(bool(f.get('new_pose')) for f in cfg),'no_spin_or_back_view':action=='light_3','full_staff_length_px':215,'standing_equivalent_px':163}
 (out/'qa.json').write_text(json.dumps(qa,indent=2));assert qa['timing_pass'];print(name,len(cfg),sum(decoded),'ms',len(set(sha(out/f'composite_{i+1:02}.png') for i in range(len(cfg)))),'unique')


if __name__=='__main__':
 build(NAME)
 out=P/NAME;m=json.loads((out/'metadata.json').read_text())
 m.update(user_override_ids=['Sentinel_af8c4959d8a08191b7e6d0702997c388','Sentinel_0eace63933688191921865af3484c86d'],previous_version='../air_heavy_deep_15f_v4',previous_library_version=2,motion_description='Fifteen anatomical keys, with targeted upper-air, downward-arm, planted-compression and recovery continuity corrections. Full215px shakujo follows both hands with one stable front/palm occlusion policy.',preview_playback='single pass; authored forward displacement retained, no loop-reset snap',ordinary_preview_layers=['body','weapon','hand_occlusion'],effects_previewed_by_default=False,new_to_previous_version_generated_pose_count=sum(bool(f.get('new_to_v5')) for f in cfg))
 for f in m['frames']:f['weapon_layer']='front_with_palm_occlusion';f['mirror_x']=False
 (out/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
