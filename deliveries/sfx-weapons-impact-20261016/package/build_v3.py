import pathlib,json,numpy as np,subprocess as sp,csv
from scipy.signal import butter,sosfilt
from scipy.io import wavfile
P=pathlib.Path(__file__).parent;SR=48000;rng=np.random.default_rng(16102603)
records=json.loads((P/'manifest.json').read_text()); old={r['id']:r for r in records}
def rd(p):return np.frombuffer(sp.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','1','-ar',str(SR),'-']),dtype='<f4').astype(float)
def raw(rel):
 x=rd(P/'originals'/rel);ix=np.flatnonzero(abs(x)>.003)
 if len(ix):x=x[max(0,ix[0]-48):ix[-1]+1]
 return x/max(max(abs(x)),1e-9)
def f(x,h,t='lowpass'):return sosfilt(butter(2,h,fs=SR,btype=t,output='sos'),x)
def rate(x,r):return np.interp(np.arange(0,len(x),r),np.arange(len(x)),x)
def mx(*xs):
 y=np.zeros(max(map(len,xs)))
 for x in xs:y[:len(x)]+=x
 return y
def noise(d,band=(80,7000),decay=9):
 t=np.arange(int(d*SR))/SR;return f(rng.normal(size=len(t)),band,'bandpass')*np.exp(-t*decay)
def add(dst,x,t,g=1):
 i=int(t*SR);n=min(len(x),len(dst)-i)
 if n>0:dst[i:i+n]+=x[:n]*g
new=[]
def save(n,x,src,mods,peak=-5,loop=False):
 x=f(x-np.mean(x),35,'highpass');x=np.tanh(x*1.1);k=min(96,len(x)//2);x[:k]*=np.linspace(0,1,k);x[-k:]*=np.linspace(1,0,k);x*=10**(peak/20)/max(abs(x))
 wavfile.write(P/'processed/wav'/f'{n}.wav',SR,np.round(x*32767).astype(np.int16))
 sp.run(['ffmpeg','-v','error','-y','-i',str(P/'processed/wav'/f'{n}.wav'),'-c:a','libvorbis','-q:a','5',str(P/'processed/ogg'/f'{n}.ogg')],check=True)
 records.append(dict(id=n,seconds=len(x)/SR,sample_rate=SR,channels=1,peak_dbfs=peak,rms_dbfs=20*np.log10(np.sqrt(np.mean(x*x))),loop=loop,source_files=src,modifications=mods,revision='v3'));new.append(n)
for v in range(3):
 z=f'{v+1:02}';pu=f'impact/Audio/impactPunch_heavy_{v:03}.ogg';wo=f'impact/Audio/impactWood_heavy_{v:03}.ogg';so=f'impact/Audio/impactSoft_heavy_{v:03}.ogg';sw=f'battle/battle_sound_effects/swish_{v+2}.wav';me=f'weapons/sfx/sword-knife-clash-{v+1:02}.wav'
 a=raw(sw);p=raw(pu);w=raw(wo);s=raw(so);m=raw(me)
 for name,x,src,desc,pk in [
 ('spear_thrust',rate(a,1.6),[sw],'Short focused swish for spear thrust',-9),
 ('polearm_sweep',rate(a,.85),[sw],'Lower broad polearm/naginata swing',-8),
 ('spear_hit_flesh',mx(rate(p,1.15)*.8,noise(.07)*.2),[pu],'Designed piercing-body hit from punch Foley and noise',-4),
 ('polearm_hit_flesh',mx(p*.8,f(s,1200)*.45),[pu,so],'Heavy blade/body Foley',-3),
 ('staff_hit_armor',mx(w*.6,m*.6),[wo,me],'Wood and metal impact',-4),
 ('knife_throw',rate(a,2.0),[sw],'Fast throw swish',-10),
 ('knife_hit_flesh',mx(rate(p,1.45)*.8,noise(.04)*.15),[pu],'Short knife/body impact interpretation',-5),
 ('knife_hit_armor',rate(m,1.3),[me],'Light metallic strike',-6),
 ('punch_hit',mx(p*.9,f(s,1200)*.25),[pu,so],'Fist impact Foley',-4),
 ('headbutt_hit',mx(rate(p,.9)*.8,f(w,900)*.3),[pu,wo],'Heavy headbutt interpretation',-4),
 ('knee_hit',mx(p*.7,f(s,1600)*.7),[pu,so],'Knee/body blunt impact',-4),
 ('throw_swing',rate(a,.72),[sw],'Body throw release swish',-9),
 ('body_land',mx(rate(s,.8)*.8,p*.5,w*.15),[so,pu,wo],'Heavy landing body and floor Foley',-4),
 ('shield_block',mx(m*.6,w*.6),[me,wo],'Shield block interpretation',-5),
 ('musket_hit_body',mx(rate(p,1.4),noise(.045)*.25),[pu],'Designed bullet/body impact, not firearm recording',-5),
 ('musket_hit_armor',mx(rate(m,1.5),noise(.05)*.15),[me],'Designed bullet/metal impact',-5)]:
  save(name+'_'+z,x,src,desc,pk)
 # Sound-design explosion, not a recording of a historical firearm.
 shot=mx(noise(.07,(700,11000),75)*.6,noise(.5,(45,1100),12)*1.4,noise(.8,(200,4500),7)*.16)
 save('musket_player_shot_'+z,shot,[],'Original filtered-noise crack+low boom+smoke tail; designed musket interpretation, no actual gun recording',-3)
 save('musket_enemy_shot_'+z,rate(shot,1.12)*.7,[],'Original same shot family, faster envelope and -8dBFS ceiling; distinct enemy profile',-8)
# nonvariant foley and phase events
for n,rel,pk in [('sword_draw','weapons/sfx/seax-unsheathe-03.wav',-8),('sword_sheathe','weapons/sfx/seax-sheathe-03.wav',-10),('grab_contact','weapons/sfx/quiver-leather-squeeze-06.wav',-10),('musket_reload','weapons/sfx/sheath-buckle-01.wav',-11)]:
 x=raw(rel)
 if n=='musket_reload':
  a=x;x=np.zeros(int(1.5*SR));add(x,a,0,.6);add(x,rate(a,.8),.48,.5);add(x,a,1.1,.7)
 save(n,x,[rel],'Edited source Foley; game event interpretation. Reload is 1.5s mechanical placeholder, not historically authentic reload',pk)
# Elemental supplemental layers, kept separate from weapon hit sounds.
for element in ['fire','ice','wind','lightning']:
 if element=='fire':
  hit=mx(noise(.45,(50,1500),10),noise(.15,(1800,9000),25)*.25);loop=noise(1.98,(70,4000),0)*.2
  for t in [.11,.31,.72,1.07,1.53,1.82]:add(loop,noise(.04,(1800,9000),80),t,.25)
 elif element=='ice':
  rel='weapons/sfx/sword-knife-clash-03.wav';a=rate(raw(rel),1.8);hit=mx(a*.4,noise(.08,(1800,11000),50)*.4);loop=np.zeros(int(1.98*SR))
  for t in [0,.43,.91,1.47]:add(loop,a,t,.2)
 elif element=='wind':hit=noise(.5,(150,5500),6);loop=noise(1.98,(120,3500),0)*.3
 else:
  hit=mx(noise(.09,(500,11000),35),noise(.3,(45,600),14)*.4);loop=np.zeros(int(1.98*SR))
  for t in [0,.16,.47,.73,1.1,1.38,1.77]:add(loop,noise(.05,(600,9000),60),t,.2)
 src=['weapons/sfx/sword-knife-clash-03.wav'] if element=='ice' else []
 save('element_'+element+'_hit',hit,src,'Original designed elemental layer; noise synthesis'+(' and pitched metal Foley' if src else ''),-8)
 save('element_'+element+'_loop',loop,src,'Original designed elemental loop candidate; runtime 20ms overlap crossfade; no subjective seamless-loop validation',-14,True)
(P/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
# Full event map. Gains conservative: actual asset peaks already shaped.
rows=[]
for r in records:
 n=r['id'];loop=r['loop'];is_hit=any(k in n for k in ['hit','collision','land','block']);group=n[:-3] if n[-3]=='_' and n[-2:].isdigit() else n
 gain=.65 if is_hit else (.45 if loop else .60)
 if 'musket_enemy' in n:gain=.55
 rows.append(dict(event_id=group,variant_id=n,wav='processed/wav/'+n+'.wav',ogg='processed/ogg/'+n+'.ogg',gain_linear=gain,loop=loop,trigger='loop-state-enter' if loop else ('confirmed-contact' if is_hit else 'animation-event'),dedupe='one loop per actor' if loop else ('attackId+targetId+eventId; max 3 simultaneous hits' if is_hit else 'one per attack/event'),crossfade_ms=20 if loop else 0))
with (P/'docs/event-map.csv').open('w') as fh:
 dw=csv.DictWriter(fh,rows[0]);dw.writeheader();dw.writerows(rows)
(P/'docs/event-map.json').write_text(json.dumps(rows,indent=2))
# Concise complete-family listening reel, one variation per family.
preview=[];index=[];pos=0
for r in records:
 n=r['id']
 if n[-2:].isdigit() and not n.endswith('_01'):continue
 x=rd(P/'processed/wav'/f'{n}.wav');index.append(dict(at_seconds=round(pos/SR,3),id=n));preview.extend([x,np.zeros(int(.45*SR))]);pos+=len(x)+int(.45*SR)
x=np.concatenate(preview);wavfile.write(P/'preview.wav',SR,np.round(x*32767).astype(np.int16));sp.run(['ffmpeg','-v','error','-y','-i',str(P/'preview.wav'),'-c:a','libmp3lame','-b:a','192k',str(P/'Sengoku_All_Weapons_Preview_v3.mp3')],check=True)
(P/'docs/preview-index.json').write_text(json.dumps(index,indent=2));print(len(records),'events',len(index),'preview groups',len(x)/SR,'seconds')
