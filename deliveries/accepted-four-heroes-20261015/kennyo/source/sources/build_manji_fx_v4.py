from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
import shutil,json,math,hashlib
P=Path(__file__).parent;S=P/'charge_release_v3';D=P/'charge_release_v4';D.mkdir(exist_ok=True)
# Preserve approved body and flexible-chain layers byte-for-byte. Only effect and composites change.
for f in S.iterdir():
 if f.is_file() and not (f.name.startswith('effect_') or f.name.startswith('composite_') or f.suffix in ['.gif','.jpg']):shutil.copy(f,D/f.name)
meta=json.loads((S/'metadata.json').read_text());W,H=800,400;particles=[];frames=[];font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',20)
tile=Image.new('RGBA',(30,30));ImageDraw.Draw(tile).text((3,1),'卍',font=font,fill=(255,213,101,255),stroke_width=1,stroke_fill=(142,84,20,255));tile.save(D/'buddhist-manji-u534d.png')
for i,f in enumerate(meta['frames']):
 now=f['start_ms'];fx=Image.new('RGBA',(W,H));draw=ImageDraw.Draw(fx)
 if f['impact']:
  direction=1 if 'right strike' in f['event'] else -1
  for k in range(3):particles.append({'x':f['grip'][0]+direction*(32+k*21),'y':f['grip'][1]-23+k*16,'vx':direction*(530+k*65),'vy':[-35,0,32][k],'born':now,'direction':direction,'round':f['round']})
 for p in particles:
  age=(now-p['born'])/1000
  if not 0<=age<.30:continue
  t=min(age,.22);x=p['x']+p['vx']*t;y=p['y']+p['vy']*t+25*t*t
  if age<.22:
   alpha=255 if age<.16 else round(255*(.22-age)/.06)
   # Short impact-direction streak, fixed upright Buddhist glyph with no spinning.
   draw.line((x-p['direction']*24,y+14,x-p['direction']*4,y+14),fill=(242,174,59,round(alpha*.7)),width=3)
   glyph=tile.copy();glyph.putalpha(glyph.getchannel('A').point(lambda a:int(a*alpha/255)));fx.alpha_composite(glyph,(round(x),round(y)))
  else:
   # Small burst at independent particle endpoint; optional contact FX for reuse.
   life=(age-.22)/.08;alpha=round(230*(1-life));cx=x+15;cy=y+14
   for k in range(7):
    a=k*math.tau/7;r0=3+life*8;r1=r0+7
    draw.line((cx+math.cos(a)*r0,cy+math.sin(a)*r0,cx+math.cos(a)*r1,cy+math.sin(a)*r1),fill=(255,219,128,alpha),width=2)
 fx.save(D/f'effect_{i+1:02}.png')
 base=Image.open(S/f'composite_no_fx_{i+1:02}.png').convert('RGBA');shutil.copy(S/f'composite_no_fx_{i+1:02}.png',D/f'composite_no_fx_{i+1:02}.png');base.alpha_composite(fx);base.save(D/f'composite_{i+1:02}.png')
 bg=Image.new('RGB',(W,H),(40,44,48));bg.paste(base,mask=base.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((20,320,780,320),fill=(75,80,85));dr.text((15,14),'KENNYO03 | overhead beads | Buddhist manji impact pulses',fill=(230,232,234));dr.text((15,375),f['event'],fill=(185,192,200));frames.append(bg)
durs=meta['gif_decoded_durations_ms'];assert len(durs)==38 and sum(durs)==3170
for name,mult in [('normal',1),('slow',3)]:frames[0].save(D/f'{name}.gif',save_all=True,append_images=frames[1:],duration=[v*mult for v in durs],loop=0,disposal=2)
frames[9].save(D/'poster.png');shutil.copy(D/'normal.gif',D/'kennyo03_bead_manji_impact_v4.gif')
meta['buddha_particles']='U+534D upright manji: 3 independent projectiles per6 strike events;220ms flight +80ms scatter';meta['fx_projectiles_per_pulse']=3;meta['fx_speed_px_per_sec']=[530,595,660];meta['fx_lifetime_ms']=300;meta['fx_symbol_file']='buddhist-manji-u534d.png';meta['fx_symbol_rotation_degrees']=0;meta['glyph_text']='卍';meta['glyph_unicode']='U+534D Buddhist manji upright, no rotation';meta['fx_revision']='v4: three fast heavy straight projectiles per six strike pulses, short trailing streak, terminal light scatter, independent velocity and lifetime';meta['approved_body_and_bead_layers_unchanged']=True;meta['fx_contact_note']='terminal scatter is a visual burst; runtime may gate/reposition it on actual collision; no new damage/status inferred';meta['user_fx_override']='Sentinel_aec5b6cb114c8191af8a073aba939c3f';(D/'metadata.json').write_text(json.dumps(meta,indent=2))
unchanged=[]
for glob in ['body_*.png','beads_back_*.png','beads_front_*.png','weapon_back_*.png','hand_occlusion_*.png']:
 for f in S.glob(glob):assert f.read_bytes()==(D/f.name).read_bytes();unchanged.append(f.name)
im=Image.open(D/'normal.gif');actual=[]
for i in range(im.n_frames):im.seek(i);actual.append(im.info['duration'])
assert actual==durs
(D/'FX_QA.json').write_text(json.dumps({'unchanged_layer_files':unchanged,'actual_frames':im.n_frames,'durations':actual,'total_ms':sum(actual),'strike_pulses':len(meta['strike_events']),'only_fx_changed':True},indent=2))
print(len(unchanged),im.n_frames,sum(actual))
