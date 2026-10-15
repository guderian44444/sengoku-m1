from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np, math, json, hashlib, shutil, bisect

P=Path(__file__).resolve().parents[1]
B=P/'actions/charge_release_outburst_v7'
ORB=P/'actions/charge_release_sharpfx_v6'
D=P/'actions/charge_release_fastburst_v8'
F=D/'fx'; E=D/'preview_enemy'
F.mkdir(parents=True,exist_ok=True);E.mkdir(parents=True,exist_ok=True)
W,H=520,300;SS=3
ns={'__file__':str(P/'scripts/build_charge_sharpfx.py')}
exec((P/'scripts/build_charge_sharpfx.py').read_text().split('views=[];qa=[]')[0],ns)
render_plane=ns['render_plane'];PARAM=ns['LAYER_PARAMETERS']
m=json.loads((B/'metadata.json').read_text());om=json.loads((ORB/'metadata.json').read_text())
for name in ['silver_blade_orbit_topdown.png','silver_shard_0.png','silver_shard_1.png','silver_shard_2.png']:
 shutil.copy2(B/'fx'/name,F/name)
starts=[r['start_ms'] for r in m['frames']]
# Exact original actor boundaries plus independent higher temporal resolution for the FX impulse.
TIMES=sorted(set(starts+[770,810,830,850,870,890,910,950,990,1040,1100,1170,1240,1300,1340,1440]))
DUR=[b-a for a,b in zip(TIMES,TIMES[1:])]
assert TIMES[-1]==1440 and min(DUR)>=20

def empty():return Image.new('RGBA',(W,H))
def ease(u):return (1-math.exp(-4*max(0,min(1,u))))/(1-math.exp(-4))
def burst(t,actoridx):
 if t<770:
  return Image.open(ORB/f'fx_back_{actoridx:02}.png').convert('RGBA'),Image.open(ORB/f'fx_front_{actoridx:02}.png').convert('RGBA'),dict(stage='approved_orbit_unchanged')
 back=empty();front=empty()
 if t>=1340:return back,front,dict(stage='clear',strength=0)
 if t<810:
  cx,cy=om['frames'][12]['fx']['orbit_center_world'];scale=.87
  for cfg in reversed(PARAM):
   c=cfg.copy();c['radius']*=scale;c['phase_lag']-=7
   b,f=render_plane(660,cx,cy,c,.96);back.alpha_composite(b);front.alpha_composite(f)
  return back,front,dict(stage='brief_compression',compression_start_ms=770,compression_duration_ms=40,radius_multiplier=scale,center=[cx,cy])
 u=(t-810)/100;q=ease(u);cx=191.815+12*q;cy=170.421
 # Complete visible travel in100ms, then fade at essentially fixed radius.
 gain=1 if t<=890 else max(0,1-(t-890)/450)**1.6
 ringgain=max(0,1-(t-810)/190)**2
 for cfg in reversed(PARAM):
  c=cfg.copy();c['radius']*=.90+.55*q;c['vertical']*=1+.4*q;c['phase_lag']-=12*q
  b,f=render_plane(720+24*q,cx,cy,c,ringgain);back.alpha_composite(b);front.alpha_composite(f)
 # Independent pointed needles and long directional trails. Tips never extend beyond the measured radius.
 bs=Image.new('RGBA',(W*SS,H*SS));fs=bs.copy();bd=ImageDraw.Draw(bs);fd=ImageDraw.Draw(fs);records=[]
 for j in range(18):
  th=math.radians(j*20+(7 if j%2 else 0)+8)
  speed=.86+.14*(j%3)/2;tipr=105+76*q*speed
  length=(50+9*(j%3))*(.78+.22*q)
  dep=.24;vx=math.cos(th);vy=dep*math.sin(th)
  # Drawing in projected waist plane keeps every blade oriented away from the body.
  tip=np.array([cx+tipr*vx,cy+tipr*vy+(j%3-1)*4])
  tail=np.array([cx+(tipr-length)*vx,cy+(tipr-length)*vy+(j%3-1)*4])
  vec=tip-tail;norm=vec/np.linalg.norm(vec);perp=np.array([-norm[1],norm[0]])
  shoulder=tip-vec*.33;alpha=round(235*gain*(.83+.17*(j%2)))
  d=fd if math.sin(th)>=0 else bd
  def poly(points,color):d.polygon([tuple(np.round(p*SS).astype(int)) for p in points],fill=color)
  poly([tip,shoulder+perp*(1.6+.3*(j%3)),tail,shoulder-perp*(1.2+.2*(j%2))],(211,229,242,alpha))
  poly([tip,shoulder+perp*.4,tail+vec*.12,shoulder-perp*.4],(248,252,255,round(alpha*.95)))
  for off in [-2.5,2.5]:
   # Two thin, unequal trailing speed lines. They fade behind, never ahead of the blade tip.
   a=tail-vec*.10+perp*off;b=tip-vec*(.25 if off<0 else .42)+perp*off
   d.line([tuple(np.round(a*SS).astype(int)),tuple(np.round(b*SS).astype(int))],fill=(174,202,223,round(alpha*.38)),width=1)
  records.append(dict(angle_deg=round(math.degrees(th),3),tip_radius_px=round(tipr,4),length_px=round(length,4),tip_world=tip.tolist(),depth='front' if math.sin(th)>=0 else 'back'))
 back.alpha_composite(bs.resize((W,H),Image.Resampling.LANCZOS));front.alpha_composite(fs.resize((W,H),Image.Resampling.LANCZOS))
 return back,front,dict(stage='fast_radial_burst' if t<910 else 'stationary_radius_decay',burst_progress=q,strength=gain,center=[cx,cy],radius_multiplier=.90+.55*q,ring_strength=ringgain,shards=records)

def dummy(side,t):
 # Diagram-only articulated gray dummy. It is a separate, switchable preview layer.
 x0=125 if side<0 else 354;y0=208
 flying=t>=810
 u=max(0,(t-810)/100);q=ease(u)
 dt=max(0,t-910)/1000
 dx=(45 if side<0 else 76)*q + min(10 if side<0 else 18,dt*43)
 lift=47*q+max(0,25*min(dt/.26,1)-15*max(0,(dt-.26)/.17))
 rot=side*(70*q+min(45,dt*110))
 alpha=170 if t<1170 else round(170*max(0,(1340-t)/170))
 if t>=1340:return empty(),dict(side=side,visible=False)
 cx=x0+side*dx;cy=y0-lift
 angle=math.radians(rot);c,s=math.cos(angle),math.sin(angle)
 # Point coordinates centered on waist. Neck, chest, hip, bent arms and legs are distinct.
 if not flying: pts={'head':(0,-48),'neck':(0,-39),'shoulder_l':(-10,-34),'shoulder_r':(10,-34),'hip_l':(-7,-10),'hip_r':(7,-10),'elbow_l':(-16,-18),'elbow_r':(16,-18),'hand_l':(-14,-3),'hand_r':(14,-3),'knee_l':(-11,10),'knee_r':(11,10),'foot_l':(-14,32),'foot_r':(16,32)}
 else: pts={'head':(0,-48),'neck':(0,-39),'shoulder_l':(-10,-34),'shoulder_r':(10,-34),'hip_l':(-7,-10),'hip_r':(7,-10),'elbow_l':(-23,-40),'elbow_r':(22,-21),'hand_l':(-32,-30),'hand_r':(34,-34),'knee_l':(-21,6),'knee_r':(12,16),'foot_l':(-10,24),'foot_r':(31,27)}
 def p(key):
  x,y=pts[key];return np.array([cx+c*x-s*y,cy+s*x+c*y])*SS
 z=Image.new('RGBA',(W*SS,H*SS));d=ImageDraw.Draw(z);color=(156,163,171,alpha)
 d.polygon([tuple(p(k)) for k in ['shoulder_l','shoulder_r','hip_r','hip_l']],fill=color)
 h=p('head');r=7.2*SS;d.ellipse((h[0]-r,h[1]-r,h[0]+r,h[1]+r),fill=color)
 for keys,width in [(['neck','head'],6),(['shoulder_l','elbow_l','hand_l'],6),(['shoulder_r','elbow_r','hand_r'],6),(['hip_l','knee_l','foot_l'],8),(['hip_r','knee_r','foot_r'],8)]:
  d.line([tuple(p(k)) for k in keys],fill=color,width=round(width*SS),joint='curve')
 return z.resize((W,H),Image.Resampling.LANCZOS),dict(side=side,visible=True,center=[cx,cy],outward_displacement_px=dx,lift_px=lift,rotation_deg=rot,alpha=alpha,trigger_event='contact_launch_turn_2',event_time_ms=750,visual_start_ms=810,visual_delay_ms=60,runtime=False)

qa=[]
for i in range(17):
 row={'index':i}
 for name in ['body_canvas','weapon','actor_clean']:
  src=B/f'{name}_{i:02}.png';dst=D/f'{name}_{i:02}.png';shutil.copy2(src,dst)
  aa=np.array(Image.open(src));bb=np.array(Image.open(dst));assert np.array_equal(aa,bb)
  a=hashlib.sha256(src.read_bytes()).hexdigest();b=hashlib.sha256(dst.read_bytes()).hexdigest();assert a==b
  row[name]={'sha256_before':a,'sha256_after':b,'different_pixels':0}
 if (B/f'head_edit_mask_{i:02}.png').exists():shutil.copy2(B/f'head_edit_mask_{i:02}.png',D/f'head_edit_mask_{i:02}.png')
 qa.append(row)

views=[];cleanviews=[];timeline=[];bounds=[]
for k,(t,dur) in enumerate(zip(TIMES,DUR)):
 ai=min(16,bisect.bisect_right(starts,t)-1);actor=Image.open(D/f'actor_clean_{ai:02}.png').convert('RGBA')
 back,front,rec=burst(t,ai);enemy=empty();enemyrec=[]
 for side in [-1,1]:
  z,r=dummy(side,t);enemy.alpha_composite(z);enemyrec.append(r)
 for name,z in [('fx_back',back),('fx_front',front)]:
  z.save(F/f'{name}_{k:02}.png');z.save(D/f'{name}_{k:02}.png')
  a=np.array(z.getchannel('A'));bbox=z.getchannel('A').getbbox();edge=int(np.count_nonzero(a[0])+np.count_nonzero(a[-1])+np.count_nonzero(a[:,0])+np.count_nonzero(a[:,-1]))
  margin=min(bbox[0],bbox[1],W-bbox[2],H-bbox[3]) if bbox else None
  assert edge==0,(name,k,t,bbox)
  bounds.append(dict(file=f'{name}_{k:02}.png',bbox=bbox,edge_nonzero_pixels=edge,min_margin_px=margin))
 enemy.save(E/f'enemy_{k:02}.png');a=np.array(enemy.getchannel('A'));assert not(np.any(a[0]) or np.any(a[-1]) or np.any(a[:,0]) or np.any(a[:,-1])),(k,t,enemy.getbbox())
 clean=back.copy();clean.alpha_composite(actor);clean.alpha_composite(front);clean.save(D/f'preview_composite_{k:02}.png')
 demo=enemy.copy();demo.alpha_composite(back);demo.alpha_composite(actor);demo.alpha_composite(front);demo.save(D/f'preview_demo_{k:02}.png')
 def view(comp,showdemo):
  bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));d=ImageDraw.Draw(bg);d.line((0,253,W,253),fill=(68,74,82));d.text((12,10),'HIDEYOSHI / charge_release / fast blade burst',fill='white')
  d.text((12,25),'GRAY TARGETS: KNOCKBACK DEMO ONLY' if showdemo else 'CLEAN FX PREVIEW / NO DEMO TARGETS',fill=(155,164,174))
  label='40ms COMPRESS' if 770<=t<810 else ('FAST BURST + LAUNCH' if 810<=t<910 else ('DECAY / NO NEW HIT' if 910<=t<1340 else ('CLEAR' if t>=1340 else '720 DEG ORBIT')))
  d.text((12,267),f'{k+1:02}/{len(DUR)}  {t:04}ms | {label}',fill=(200,211,220));d.text((12,281),'actor17f/1240ms | preview1440ms | launch event750ms',fill=(152,163,174));return bg
 views.append(view(demo,True));cleanviews.append(view(clean,False))
 rec.update(preview_frame=k,actor_frame=ai,start_ms=t,end_ms=t+dur,duration_ms=dur,actor_ready_preview_hold=t>=1240,event=m['frames'][ai].get('event') if t==starts[ai] else None,enemy_demo=enemyrec)
 timeline.append(rec)
# Conventional actor-index composites remain17 entries, sampled at original exact actor times.
for i,t in enumerate(starts):
 k=TIMES.index(t);shutil.copy2(D/f'preview_composite_{k:02}.png',D/f'composite_{i:02}.png');m['frames'][i]['fx']=dict(fx_timeline_frame=k,fx_sample_time_ms=t)
views[0].save(D/'charge_release_fastburst_v8.gif',save_all=True,append_images=views[1:],duration=DUR,loop=0,disposal=2,optimize=False)
cleanviews[0].save(D/'charge_release_fastburst_clean.gif',save_all=True,append_images=cleanviews[1:],duration=DUR,loop=0,disposal=2,optimize=False)
ri=TIMES.index(850);views[ri].save(D/'representative.png');Image.open(D/f'preview_demo_{ri:02}.png').save(D/'representative_rgba.png');cleanviews[ri].save(D/'representative_clean.png')
cs=Image.new('RGB',(W*4,H*math.ceil(len(views)/4)),(42,48,56))
for i,z in enumerate(views):cs.paste(z,(i%4*W,i//4*H))
cs.save(D/'contact.png')
keytimes=[750,770,810,830,850,870,890,910,990,1100,1240,1340]
cs=Image.new('RGB',(W*4,H*3),(42,48,56))
for i,t in enumerate(keytimes):cs.paste(views[TIMES.index(t)],(i%4*W,i//4*H))
cs.save(D/'burst_contact.png')
source_events=[(r['index'],r['start_ms'],r['end_ms'],r['duration_ms'],r.get('event')) for r in json.loads((B/'metadata.json').read_text())['frames']]
out_events=[(r['index'],r['start_ms'],r['end_ms'],r['duration_ms'],r.get('event')) for r in m['frames']]
assert source_events==out_events
assert sum(r['duration_ms'] for r in m['frames'])==1240
# Explicit independent visual timeline prevents a second or third damage trigger from preview repeats.
revision=dict(source=str(B.relative_to(P)),compression_start_ms=770,compression_duration_ms=40,fx_burst_start_ms=810,burst_travel_duration_ms=100,burst_travel_end_ms=910,visual_delay_ms=60,trigger_event='contact_launch_turn_2',trigger_event_time_ms=750,damage_events_added=0,enemy_demo_runtime=False,actor_hitstop_added=False,fx_stop_ms=1340,clear_hold_ms=[1340,1440],max_radius_multiplier=1.45,needle_count=18,tip_radius_max_px=181,body_and_weapon_unchanged=True,events_unchanged=True)
for obsolete in ['fx_outburst_revision'] :m.pop(obsolete,None)
m.update(revision='approved_actor_silver_fastburst_enemy_demo_v8',description='末段40ms短蓄縮後100ms尖長銀刃爆射；灰色示意敵人60ms視覺延遲後離心仰翻擊飛。保留原兩次命中、核准人物與刀。',frame_count=17,duration_ms=1240,runtime_actor_frame_count=17,runtime_actor_duration_ms=1240,preview_frame_count=len(DUR),preview_duration_ms=1440,fx_duration_ms=1340,preview_hold_note='After actor ends1240ms, preview holds final ready frame16 for200ms; last100ms FX and demo are transparent. Preview subdivision does not resample or retime the actor.',fx_timeline=timeline,fx_fastburst_revision=revision,preview_enemy=dict(enabled_by_default=True,runtime=False,layer_directory='preview_enemy',toggle='Omit preview_enemy/enemy_XX.png or use charge_release_fastburst_clean.gif / preview_composite_XX.png.',composite_order=['preview_enemy','fx_back','actor_clean','fx_front'],events_reused=['contact_launch_turn_2'],new_hit_events=0))
(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
(F/'manifest.json').write_text(json.dumps(dict(canvas=[W,H],runtime_actor_frames=17,runtime_actor_duration_ms=1240,fx_stop_ms=1340,frames=timeline,body_baked_into_fx=False,enemy_baked_into_fx=False,revision=revision),ensure_ascii=False,indent=2))
(E/'manifest.json').write_text(json.dumps(dict(runtime=False,default_preview_enabled=True,disable='Omit this independent layer. Clean preview_composite_XX.png and clean GIF are included.',event_time_ms=750,visual_delay_ms=60,launch_start_ms=810,frames=[dict(frame=r['preview_frame'],start_ms=r['start_ms'],end_ms=r['end_ms'],targets=r['enemy_demo']) for r in timeline]),ensure_ascii=False,indent=2))
checks={}
for filename in ['charge_release_fastburst_v8.gif','charge_release_fastburst_clean.gif']:
 g=Image.open(D/filename);dur=[]
 for i in range(g.n_frames):g.seek(i);g.convert('RGBA').load();dur.append(g.info['duration'])
 assert g.n_frames==len(DUR) and dur==DUR and sum(dur)==1440
 checks[filename]=dict(frames=g.n_frames,duration_ms=sum(dur),all_frames_decoded=True)
for name in ['fx_back','fx_front']:
 assert Image.open(F/f'{name}_{len(DUR)-1:02}.png').getchannel('A').getextrema()==(0,0)
result=dict(actor_frames=17,actor_duration_ms=1240,preview_frames=len(DUR),preview_duration_ms=1440,fx_stop_ms=1340,body_and_weapon_pixel_equal=True,body_and_weapon_file_hash_equal=True,actor_clean_byte_equal=True,events_equal=True,source_events=source_events,output_events=out_events,actor_qa=qa,fx_bounds=bounds,fx_min_margin_px=min(r['min_margin_px'] for r in bounds if r['min_margin_px'] is not None),gif_decode=checks,burst=revision)
(D/'pixel_event_validation.json').write_text(json.dumps(result,ensure_ascii=False,indent=2))
print(json.dumps({k:v for k,v in result.items() if k not in ['actor_qa','fx_bounds','source_events','output_events']},indent=2));print(D/'burst_contact.png')
