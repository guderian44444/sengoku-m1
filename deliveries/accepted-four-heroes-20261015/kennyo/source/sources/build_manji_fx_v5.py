from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import shutil,json,math,hashlib,random
import numpy as np
P=Path(__file__).parent;S=P/'charge_release_v4';D=P/'charge_release_v5';D.mkdir(exist_ok=True)
# Preserve approved body and flexible-chain layers byte-for-byte. Only effect and composites change.
for f in S.iterdir():
 if f.is_file() and not (f.name.startswith('effect_') or f.name.startswith('composite_') or f.suffix in ['.gif','.jpg']):shutil.copy(f,D/f.name)
meta=json.loads((S/'metadata.json').read_text());W,H=800,400;particles=[];frames=[];font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',20)
tile=Image.new('RGBA',(30,30));ImageDraw.Draw(tile).text((3,1),'卍',font=font,fill=(255,213,101,255),stroke_width=1,stroke_fill=(142,84,20,255));tile.save(D/'buddhist-manji-u534d.png')
SEED=202610150409;rng=random.Random(SEED);emissions=[]
for i,f in enumerate(meta['frames']):
 now=f['start_ms'];fx=Image.new('RGBA',(W,H));draw=ImageDraw.Draw(fx)
 if f['impact']:
  direction=1 if 'right strike' in f['event'] else -1
  pulse=[]
  for low,high in [(-82,-61),(-60,-36),(-35,-10),(-8,20),(-69,-18)]:
   angle=math.radians(rng.uniform(low,high));speed=rng.uniform(360,550)
   p={'x':f['grip'][0]+direction*rng.uniform(25,57),'y':f['grip'][1]+rng.uniform(-25,16),'vx':direction*speed*math.cos(angle),'vy':speed*math.sin(angle),'gravity':rng.uniform(1250,1700),'born':now,'direction':direction,'round':f['round'],'life':rng.uniform(.35,.44),'size':rng.randint(21,29)}
   # Fixed-seed rejection-free bounded trajectories: life capped before any edge approach.
   while any(not(25<=p['x']+p['vx']*t<=W-55 and 25<=p['y']+p['vy']*t+.5*p['gravity']*t*t<=H-55) for t in np.linspace(0,p['life'],50)):
    p['life']-=.01
    assert p['life']>.15
   particles.append(p);pulse.append(p.copy())
  emissions.append({'frame':i+1,'start_ms':now,'event':f['event'],'particles':pulse})
 for p in particles:
  age=(now-p['born'])/1000
  if not 0<=age<p['life']:continue
  x=p['x']+p['vx']*age;y=p['y']+p['vy']*age+.5*p['gravity']*age*age
  prev=max(0,age-.032);px=p['x']+p['vx']*prev;py=p['y']+p['vy']*prev+.5*p['gravity']*prev*prev
  fade=min(1,(p['life']-age)/.075);alpha=round(255*fade);half=p['size']/2
  # Short tangent trail follows each independent ballistic path, never the necklace.
  draw.line((px+half,py+half,x+half,y+half),fill=(242,174,59,round(alpha*.65)),width=3)
  glyph=tile.resize((p['size'],p['size']),Image.Resampling.LANCZOS);glyph.putalpha(glyph.getchannel('A').point(lambda a:int(a*alpha/255)));fx.alpha_composite(glyph,(round(x),round(y)))
 fx.save(D/f'effect_{i+1:02}.png')
 base=Image.open(S/f'composite_no_fx_{i+1:02}.png').convert('RGBA');shutil.copy(S/f'composite_no_fx_{i+1:02}.png',D/f'composite_no_fx_{i+1:02}.png');base.alpha_composite(fx);base.save(D/f'composite_{i+1:02}.png')
 bg=Image.new('RGB',(W,H),(40,44,48));bg.paste(base,mask=base.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((20,320,780,320),fill=(75,80,85));dr.text((15,14),'KENNYO03 | overhead beads | Buddhist manji impact pulses',fill=(230,232,234));dr.text((15,375),f['event'],fill=(185,192,200));frames.append(bg)
durs=meta['gif_decoded_durations_ms'];assert len(durs)==38 and sum(durs)==3170
for name,mult in [('normal',1),('slow',3)]:frames[0].save(D/f'{name}.gif',save_all=True,append_images=frames[1:],duration=[v*mult for v in durs],loop=0,disposal=2)
frames[9].save(D/'poster.png');shutil.copy(D/'normal.gif',D/'kennyo03_bead_manji_scatter_v5.gif')
meta['buddha_particles']='U+534D upright manji; fixed-seed irregular outward/upward ballistic bursts with strong initial velocity, gravity and short tangent trails'
meta['fx_revision']='v5 outward and upward irregular scatter only; approved body, beads, staff,38 keys and3170ms unchanged'
meta['fx_seed']=SEED;meta['fx_projectiles_per_pulse']=5;meta['fx_emissions']=emissions;meta['fx_speed_px_per_sec_range']=[360,550];meta['fx_gravity_px_per_sec2_range']=[1250,1700]
meta.pop('fx_speed_px_per_sec',None);meta.pop('fx_lifetime_ms',None)
meta['fx_contact_note']='Each attack pulse emits independent ballistic manji particles; no enemy collision or additional damage/status is inferred.'
meta['user_fx_override']='Sentinel_9adee52fca148191a0ab35b731c0f49f'
(D/'metadata.json').write_text(json.dumps(meta,indent=2))
unchanged=[]
for glob in ['body_*.png','beads_back_*.png','beads_front_*.png','weapon_back_*.png','hand_occlusion_*.png']:
 for f in S.glob(glob):assert f.read_bytes()==(D/f.name).read_bytes();unchanged.append(f.name)
im=Image.open(D/'normal.gif');actual=[]
for i in range(im.n_frames):im.seek(i);actual.append(im.info['duration'])
assert actual==durs
(D/'FX_QA.json').write_text(json.dumps({'unchanged_layer_files':unchanged,'actual_frames':im.n_frames,'durations':actual,'total_ms':sum(actual),'strike_pulses':len(meta['strike_events']),'only_fx_changed':True},indent=2))
edges=[]
for f in D.glob('effect_*.png'):
 a=np.array(Image.open(f).getchannel('A'));edges.append(int(max(a[0].max(),a[-1].max(),a[:,0].max(),a[:,-1].max())))
assert max(edges)==0
print(len(unchanged),im.n_frames,sum(actual),'edge max',max(edges),'pulses',len(emissions))
