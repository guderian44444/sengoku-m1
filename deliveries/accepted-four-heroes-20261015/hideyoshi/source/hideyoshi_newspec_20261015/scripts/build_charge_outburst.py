from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,find_objects,binary_dilation
import numpy as np,math,json,hashlib,shutil
P=Path(__file__).resolve().parents[1];B=P/'actions/charge_release_sharpfx_v6';D=P/'actions/charge_release_outburst_v7';F=D/'fx';F.mkdir(parents=True,exist_ok=True)
# Reuse accepted sharp silver texture and the existing front/back plane projection.
ns={'__file__':str(P/'scripts/build_charge_sharpfx.py')};exec((P/'scripts/build_charge_sharpfx.py').read_text().split('views=[];qa=[]')[0],ns)
render_plane=ns['render_plane'];PARAM=ns['LAYER_PARAMETERS'];W,H=520,300
m=json.loads((B/'metadata.json').read_text());tex=Image.open(B/'fx/silver_blade_orbit_topdown.png').convert('RGBA');shutil.copy2(B/'fx/silver_blade_orbit_topdown.png',F/'silver_blade_orbit_topdown.png')
a=np.array(tex);labs,n=label(a[:,:,3]>100);obj=find_objects(labs);shards=[]
for outidx,ident in enumerate([1,16,28]):
 sl=obj[ident-1];x0=max(0,sl[1].start-3);y0=max(0,sl[0].start-3);x1=min(tex.width,sl[1].stop+3);y1=min(tex.height,sl[0].stop+3);m0=binary_dilation(labs==ident,iterations=2)[y0:y1,x0:x1];v=a[y0:y1,x0:x1].copy();v[:,:,3]=np.where(m0,v[:,:,3],0);z=Image.fromarray(v);z.save(F/f'silver_shard_{outidx}.png');shards.append(z)
DUR=[r['duration_ms'] for r in m['frames']]+[60,60,60,100]
PROFILE={13:(.08,.98),14:(.28,.87),15:(.52,.69),16:(.77,.44),17:(.90,.23),18:(1.,.10),19:(1.05,.025),20:(1.10,0.)}
def empty():return Image.new('RGBA',(W,H))
def burst(i):
 p,gain=PROFILE[i];back=empty();front=empty();cx=191.815+12*min(p*2,1);cy=170.4
 if gain==0:return back,front,dict(stage='finished',progress=p,strength=0,center=[cx,cy])
 for cfg in reversed(PARAM):
  c=cfg.copy();c['radius']*=1+.45*min(p,1);c['vertical']*=1+.4*p;c['phase_lag']-=12*p
  b,f=render_plane(720+35*p,cx,cy,c,gain);back.alpha_composite(b);front.alpha_composite(f)
 # A bounded radial burst of actual sharp silver shard pixels, not white bloom.
 shard_records=[]
 for j in range(18):
  theta=math.radians(j*20+(7 if j%2 else 0)+9*p);speed=.80+.20*(j%3)/2
  r=112+(64*min(p,1)*speed);x=cx+r*math.cos(theta);y=cy+r*.24*math.sin(theta)+(j%3-1)*5
  length=(18+8*(j%3))*(.85+.35*p);height=(3.1+1.4*(j%2));src=shards[j%3]
  # All shards are oriented radially away from the waist orbit and stretched into needle blades.
  z=src.resize((round(length*3),round(height*3)),Image.Resampling.LANCZOS);ang=math.degrees(math.atan2(.24*math.sin(theta),math.cos(theta)));z=z.rotate(-ang,Image.Resampling.BICUBIC,expand=True)
  z=z.resize((max(1,round(z.width/3)),max(1,round(z.height/3))),Image.Resampling.LANCZOS)
  aa=np.array(z);alpha=gain*min(1,p*4)*(.8+.2*(j%2));aa[:,:,3]=np.round(aa[:,:,3]*alpha).clip(0,255).astype('uint8');z=Image.fromarray(aa)
  target=front if math.sin(theta)>=0 else back;target.alpha_composite(z,(round(x-z.width/2),round(y-z.height/2)));shard_records.append(dict(angle_deg=math.degrees(theta),radius_px=r,center=[x,y],layer='front' if math.sin(theta)>=0 else 'back'))
 return back,front,dict(stage='outward_expansion_and_radial_shards',progress=p,strength=gain,center=[cx,cy],radius_multiplier=1+.45*min(p,1),shards=shard_records)
frames=[];views=[];timeline=[];qa=[];elapsed=0
for i,dur in enumerate(DUR):
 actor_index=min(i,16);actor=Image.open(B/f'actor_clean_{actor_index:02}.png').convert('RGBA')
 if i<17:
  for name in ['body_canvas','weapon','actor_clean']:shutil.copy2(B/f'{name}_{i:02}.png',D/f'{name}_{i:02}.png')
  if (B/f'head_edit_mask_{i:02}.png').exists():shutil.copy2(B/f'head_edit_mask_{i:02}.png',D/f'head_edit_mask_{i:02}.png')
 if i<=12:
  back=Image.open(B/f'fx_back_{i:02}.png').convert('RGBA');front=Image.open(B/f'fx_front_{i:02}.png').convert('RGBA');rec=dict(stage='approved_orbit_unchanged',yaw_degrees=m['frames'][i]['fx'].get('yaw_degrees'),strength=m['frames'][i]['fx'].get('strength',0))
 else:back,front,rec=burst(i)
 for name,z in [('fx_back',back),('fx_front',front)]:z.save(D/f'{name}_{i:02}.png');z.save(F/f'{name}_{i:02}.png')
 comp=back.copy();comp.alpha_composite(actor);comp.alpha_composite(front);comp.save(D/f'preview_composite_{i:02}.png')
 if i<17:comp.save(D/f'composite_{i:02}.png')
 bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dd=ImageDraw.Draw(bg);dd.line((0,253,W,253),fill=(68,74,82));dd.text((12,12),'HIDEYOSHI / charge_release / outward blade burst',fill='white');dd.text((12,280),f'{i+1:02}/21  actor 17f/1240ms | preview 1520ms'+(' | ready hold' if i>=17 else ''),fill=(170,180,190));views.append(bg);frames.append(comp)
 rec.update(preview_frame=i,actor_frame=actor_index,start_ms=elapsed,end_ms=elapsed+dur,duration_ms=dur,actor_ready_preview_hold=i>=17,event=m['frames'][i].get('event') if i<17 else None);timeline.append(rec);elapsed+=dur
 if i<17:
  m['frames'][i]['fx']=rec
  body0=np.array(Image.open(B/f'body_canvas_{i:02}.png'));body1=np.array(Image.open(D/f'body_canvas_{i:02}.png'));wp0=np.array(Image.open(B/f'weapon_{i:02}.png'));wp1=np.array(Image.open(D/f'weapon_{i:02}.png'));assert np.array_equal(body0,body1) and np.array_equal(wp0,wp1)
  row=dict(index=i,body_diff_pixels=int(np.any(body0!=body1,axis=2).sum()),weapon_diff_pixels=int(np.any(wp0!=wp1,axis=2).sum()))
  for name in ['body_canvas','weapon']:
   before=hashlib.sha256((B/f'{name}_{i:02}.png').read_bytes()).hexdigest();after=hashlib.sha256((D/f'{name}_{i:02}.png').read_bytes()).hexdigest();assert before==after;row[name+'_sha256_before']=before;row[name+'_sha256_after']=after
  qa.append(row)
views[0].save(D/'charge_release_outburst_v7.gif',save_all=True,append_images=views[1:],duration=DUR,loop=0,disposal=2,optimize=False);views[15].save(D/'representative.png');frames[15].save(D/'representative_rgba.png');cs=Image.new('RGB',(2080,1800),(42,48,56))
for i,z in enumerate(views):cs.paste(z,(i%4*520,i//4*300))
cs.save(D/'contact.png');original_events=[(r['index'],r['duration_ms'],r.get('event')) for r in json.loads((B/'metadata.json').read_text())['frames']];current_events=[(r['index'],r['duration_ms'],r.get('event')) for r in m['frames']];assert current_events==original_events
m.update(revision='approved_actor_silver_fx_outward_burst_v7',description='第二圈完成後銀白三層尖刃劍氣向外擴張，周圍刃片放射噴散淡出；核准人物與刀不變。',frame_count=17,duration_ms=1240,runtime_actor_frame_count=17,runtime_actor_duration_ms=1240,preview_frame_count=21,preview_duration_ms=1520,fx_duration_ms=1420,preview_hold_note='After the 1240ms actor action ends, preview repeats only final ready frame16 for280ms. This is not extra runtime actor motion or another hit.',fx_timeline=timeline,fx_outburst_revision=dict(source=str(B.relative_to(P)),starts_frame=13,starts_ms=810,fx_stops_ms=1420,fully_clear_preview_hold_ms=[1420,1520],radius_expansion_max=1.45,radial_shard_count=18,actor_and_weapon_unchanged=True,events_unchanged=True,qa=qa));(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2));(D/'pixel_event_validation.json').write_text(json.dumps(dict(actor_frames=17,actor_duration_ms=1240,preview_frames=21,preview_duration_ms=1520,fx_stop_ms=1420,body_and_weapon_pixel_equal=True,body_and_weapon_file_hash_equal=True,events_equal=True,source_events=original_events,output_events=current_events,qa=qa),ensure_ascii=False,indent=2));(F/'manifest.json').write_text(json.dumps(dict(canvas=[520,300],fx_stop_ms=1420,frames=timeline,body_baked_into_fx=False,depth_split='each waist-plane rear behind actor, near plane in front; radial shards split by depth angle'),ensure_ascii=False,indent=2))
g=Image.open(D/'charge_release_outburst_v7.gif');assert g.n_frames==21;assert sum((g.seek(i) or g.info['duration']) for i in range(21))==1520;assert sum(r['duration_ms'] for r in m['frames'])==1240
for i in range(21):
 for name in ['fx_back','fx_front']:
  z=Image.open(D/f'{name}_{i:02}.png');assert z.mode=='RGBA' and z.size==(520,300);z.load()
print('PASS actor17/1240 + preview21/1520 + FX stop1420; all body/weapon pixels+bytes unchanged; events unchanged');print(D/'contact.png')
