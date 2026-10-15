from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
from scipy import ndimage
import numpy as np,json,hashlib,math,copy
from build_air_dash import configs as original
P=Path(__file__).parent;W,H=640,380;FLOOR=325

def K(src,rect,root,grips,event,scale=.337,dx=0,air=0,feet=None,**kw):return dict(source=src,rect=rect,root_source=root,grips=grips,event=event,scale=scale,dx=dx,air_height=air,feet=feet or {},**kw)
guard=K('light_1/source.png',[0,0,512,512],[278,498],[[278,209],[257,175]],'settled_guard',feet={'left':[101,501],'right':[385,498]})
L='light_3_diagonal_v2/source.png'
l3=[dict(guard,event='ready'),
 K(L,[0,0,430,398],[240,375],[[188,77],[171,59]],'load_upper_left',scale=.437,front_anchor=[360,375],front_world=322.059,dx=3,feet={'left':[103,374],'right':[360,375]}),
 K(L,[430,0,875,398],[650,378],[[581,67],[568,43]],'rear_foot_lifts_small_turn',scale=.437,front_anchor=[790,377],front_world=322.059,dx=7,feet={'left':[592,359],'right':[790,377]}),
 K(L,[875,0,1294,398],[1100,380],[[1035,56],[1029,32]],'rear_foot_plants_high_left',scale=.437,front_anchor=[1218,378],front_world=322.059,dx=12,plant=True,feet={'left':[987,365],'right':[1218,378]}),
 K('light_3_diagonal_v2/mid-sweep-source.png',[0,0,1272,1236],[640,1190],[[750,375],[1050,200]],'front_facing_diagonal_mid_swing',scale=.1444,front_anchor=[1040,1185],front_world=322.059,dx=18,feet={'left':[210,1190],'right':[1040,1185]}),
 K(L,[440,398,875,802],[680,785],[[712,490],[790,546]],'upper_left_to_lower_right_strike',scale=.437,front_anchor=[795,784],front_world=322.059,dx=18,feet={'left':[549,782],'right':[795,784]}),
 K(L,[875,398,1294,802],[1100,786],[[1127,524],[1256,600]],'diagonal_contact_launch',scale=.437,front_anchor=[1235,785],front_world=322.059,dx=18,contact=True,feet={'left':[947,781],'right':[1235,785]}),
 K(L,[0,802,470,1216],[265,1177],[[274,928],[404,1000]],'lower_right_followthrough_front_view',scale=.437,front_anchor=[419,1172],front_world=322.059,dx=18,feet={'left':[95,1174],'right':[419,1172]}),
 K(L,[475,802,900,1216],[700,1183],[[684,970],[715,990]],'brake_and_draw_back',scale=.437,front_anchor=[828,1181],front_world=330.059,dx=18,feet={'left':[558,1182],'right':[828,1181]}),
 K(L,[900,802,1294,1216],[1100,1187],[[1084,967],[1130,905]],'recover_front_guard',scale=.437,front_anchor=[1215,1187],front_world=340.059,dx=18,feet={'left':[988,1187],'right':[1215,1187]}),
 dict(guard,dx=18,event='settled_guard')]
for i,f in enumerate(l3):
 f['weapon_grip']=[64,234]
 if 0<i<10:f['new_pose']=True
l3[3]['weapon_grip']=[64,210] # Raised phase slides 24 px forward, both hands remain in tail third; keeps full finial in frame.
l3[8]['weapon_grip']=[64,200] # Recoil grip slides forward within tail third so the full head remains above ground.
# Exact eleven authored key poses; the existing six action poses and common guard are retained and three new drawings inserted.
al=copy.deepcopy(original['air_light'])
for f in al:f['scale']=.337 if f['scale']==.334 else f['scale']
a1=K('air_light_11f_v2/extra-source.png',[0,0,650,821],[320,820],[[250,245],[600,45]],'new_takeoff_extension',scale=.217,dx=2,air=16,feet={'left':[68,795],'right':[302,630]},new_pose=True)
a2=K('air_light_11f_v2/extra-source.png',[645,0,1250,821],[980,830],[[1033,234],[1141,187]],'new_airborne_swing_transition',scale=.217,dx=8,air=44,feet={'left':[850,682],'right':[880,614]},new_pose=True)
a3=K('air_light_11f_v2/extra-source.png',[1250,0,1915,821],[1600,815],[[1480,342],[1858,201]],'new_extend_legs_before_landing',scale=.217,dx=21,air=10,feet={'left':[1648,743],'right':[1832,796]},new_pose=True)
airlight=[al[0],al[1],a1,al[2],a2,al[3],al[4],al[5],a3,al[6],al[7]]
ah=copy.deepcopy(original['air_heavy'])
for f in ah:f['scale']=.337 if f['scale']==.334 else .129 if f['scale']==.128 else f['scale']
h1=K('air_heavy_11f_v2/extra-source.png',[0,0,715,788],[380,775],[[607,164],[465,36]],'new_takeoff_staff_lift',scale=.238,air=12,feet={'left':[148,770],'right':[420,648]},new_pose=True)
h2=K('air_heavy_11f_v2/extra-source.png',[715,0,1318,788],[1050,780],[[1140,32],[1180,78]],'new_descending_overhand_transition',scale=.238,dx=18,air=32,feet={'left':[1020,717],'right':[1087,654]},new_pose=True)
h3=K('air_heavy_11f_v2/extra-source.png',[1318,0,1996,788],[1660,770],[[1634,385],[1873,543]],'new_deep_landing_absorption',scale=.238,dx=22,feet={'left':[1377,770],'right':[1930,770]},new_pose=True,landing=True)
ah[3]['event']='rising_high_guard_transition';ah[3]['air_height']=42
heavy=[ah[0],h1,ah[1],ah[3],ah[2],h2,ah[4],h3,ah[5],ah[6],ah[7]]
# Thrust replacement: unchanged running setup, three newly authored horizontal-grip thrust poses, then recovery.
da=copy.deepcopy(original['dash_heavy']);[f.update(scale=.337) for f in da if f['scale']==.334]
D='dash_heavy_thrust_v3/thrust-source.png'
thrust=[da[0],da[1],
 K(D,[0,0,810,724],[400,690],[[407,229],[770,227]],'plant_and_extend_horizontal_thrust',scale=.248,dx=36,front_anchor=[565,685],front_world=388,plant=True,feet={'left':[55,656],'right':[565,685]}),
 K(D,[620,0,1535,724],[1110,690],[[1307,226],[1472,224]],'full_forward_poke_contact',scale=.248,dx=58,front_anchor=[1370,687],front_world=388,contact=True,feet={'left':[709,664],'right':[1370,687]}),
 K(D,[1430,0,2172,724],[1800,690],[[1875,233],[2023,230]],'withdraw_with_front_foot_fixed',scale=.248,dx=58,front_anchor=[2104,685],front_world=388,feet={'left':[1490,668],'right':[2104,685]}),
 da[5],dict(guard,dx=58,front_anchor=[385,498],front_world=388)]
for i,f in enumerate(thrust):
 f['weapon_grip']=[64,234]
 if 2<=i<=4:f['new_pose']=True
thrust[5]['front_world']=388
sets={'light_3_diagonal_v2':('light_3',l3,[110,90,90,70,60,60,60,60,90,110,150],950),'air_light_11f_v2':('air_light',airlight,[60,60,50,70,50,50,50,60,50,70,200],770),'air_heavy_11f_v2':('air_heavy',heavy,[70,80,90,100,70,70,60,70,80,100,160],950),'dash_heavy_thrust_v3':('dash_heavy',thrust,[90,90,70,80,90,110,200],730)}

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
   if f.get('contact') and pivot[1]<200:
    yy,xx=np.mgrid[0:H,0:W];t=math.radians(angle);sel=(xx-grips[0][0])*math.sin(t)-(yy-grips[0][1])*math.cos(t)>=-3;a=np.array(weapon);ba=a.copy();fa=a.copy();ba[:,:,3]=np.where(sel,0,a[:,:,3]);fa[:,:,3]=np.where(sel,a[:,:,3],0);back=Image.fromarray(ba);front=Image.fromarray(fa)
   co=Image.new('RGBA',(W,H));co.alpha_composite(back);co.alpha_composite(body);co.alpha_composite(front);co.alpha_composite(hands);co.alpha_composite(fx)
   if wn=='ornate_shakujo':
    comps.append(co);frames.append(preview(co,action,f['event'],i))
    for layer,im in [('body',raw),('body_canvas',body),('weapon',weapon),('weapon_back',back),('weapon_front',front),('hand_occlusion',hands),('effect',fx),('composite',co)]:im.save(out/f'{layer}_{i+1:02}.png')
   else:alternates[wn].append(preview(co,action,f['event'],i))
  bodyonly.append(preview(body,action,f['event'],i));t=math.radians(angle);tip=[grips[0][0]+math.sin(t)*(pivot[1]-31),grips[0][1]-math.cos(t)*(pivot[1]-31)]
  records.append(dict(f,frame=i+1,duration=durs[i],start_ms=sum(durs[:i]),source_sha256=sha(P/f['source']),source_crop_xyxy=f['rect'],uniform_source_scale=s,render_origin=[ox,oy],world_root=root,ground_root=[root[0],FLOOR],grip_world=grips,weapon_angle=angle,weapon_source_pivot=pivot,aux_grip_source=([64,pivot[1]-math.dist(grips[0],grips[1])] if len(grips)>1 else None),weapon_real_length_px=215,weapon_tip=tip,contact_point=tip if f.get('contact') else None,screen_feet={k:[ox+(p[0]-x0)*s,oy+(p[1]-y0)*s] for k,p in f.get('feet',{}).items()},weapon_spin_phase=None,weapon_projection=1))
 def gif(fn,ims,ds):ims[0].save(out/fn,save_all=True,append_images=ims[1:],duration=ds,loop=0,disposal=2,optimize=False)
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
 import sys
 for name in sys.argv[1:] or sets:build(name)
