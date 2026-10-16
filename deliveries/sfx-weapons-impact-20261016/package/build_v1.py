import numpy as np, subprocess as sp, pathlib,json,hashlib, shutil
from scipy.signal import butter,sosfilt,resample_poly
from scipy.io import wavfile
P=pathlib.Path(__file__).parent; SR=48000; rng=np.random.default_rng(161026)
for d in ['processed/wav','processed/ogg','docs']: (P/d).mkdir(parents=True,exist_ok=True)
def read(rel,rate=1):
 b=sp.check_output(['ffmpeg','-v','error','-i',str(P/'originals'/rel),'-f','f32le','-ac','1','-ar',str(SR),'-']);x=np.frombuffer(b,dtype='<f4').astype(float)
 ix=np.flatnonzero(abs(x)>.004)
 if len(ix):x=x[max(0,ix[0]-96):min(len(x),ix[-1]+2400)]
 if rate!=1:x=np.interp(np.arange(0,len(x),rate),np.arange(len(x)),x)
 return x/max(np.max(abs(x)),1e-9)
def filt(x,f,typ='lowpass'):return sosfilt(butter(2,f,fs=SR,btype=typ,output='sos'),x)
def mix(*xs):
 y=np.zeros(max(map(len,xs)))
 for x in xs:y[:len(x)]+=x
 return y
def sub(d=.25,f=95):
 t=np.arange(int(d*SR))/SR;return np.sin(2*np.pi*(f*t-45*t*t))*np.exp(-t*22)
def air(d=.4):
 t=np.arange(int(d*SR))/SR;return filt(rng.normal(0,1,len(t)),[250,5000],'bandpass')*np.sin(np.pi*np.arange(len(t))/len(t))**1.4
records=[];buf={}
def save(n,x,src,mods,loop=False):
 x=x-np.mean(x);x=filt(x,35,'highpass');x=np.tanh(x*1.15)
 if loop:
  # explicit zero crossings plus periodic loop crossfade is required by consumer
  k=960;tail=x[-k:].copy(); x[:k]=tail*(1-np.arange(k)/k)+x[:k]*(np.arange(k)/k);x=x[:-k]
 else:
  k=min(96,len(x)//2);x[:k]*=np.linspace(0,1,k);k=min(960,len(x)//2);x[-k:]*=np.linspace(1,0,k)
 x*=10**(-3/20)/max(abs(x));wavfile.write(P/'processed/wav'/f'{n}.wav',SR,(x*32767).astype(np.int16))
 sp.run(['ffmpeg','-v','error','-y','-i',str(P/'processed/wav'/f'{n}.wav'),'-c:a','libvorbis','-q:a','5',str(P/'processed/ogg'/f'{n}.ogg')],check=True)
 records.append(dict(id=n,seconds=round(len(x)/SR,5),sample_rate=SR,channels=1,peak_dbfs=round(20*np.log10(max(abs(x))),2),rms_dbfs=round(20*np.log10(np.sqrt(np.mean(x*x))),2),loop=loop,source_files=src,modifications=mods));buf[n]=x
for v in range(3):
 idx=f'{v:03}';s=f'battle/battle_sound_effects/swish_{v+2}.wav';p=f'impact/Audio/impactPunch_heavy_{idx}.ogg';w=f'impact/Audio/impactWood_heavy_{idx}.ogg';m=f'weapons/sfx/sword-knife-clash-{v+1:02}.wav';soft=f'impact/Audio/impactSoft_heavy_{idx}.ogg';bow='battle/battle_sound_effects/Bow.wav'
 sw=read(s);pu=read(p);wo=read(w);me=read(m);so=read(soft)
 save(f'sword_swing_{v+1:02}',mix(sw*.8,air(.32)*.25),[s],'Trim, added synthesized airy transient, soft saturation, -3 dBFS peak')
 save(f'sword_hit_flesh_{v+1:02}',mix(pu*.7,filt(so,1400)*.4,sub()*.4,air(.09)*.2),[p,soft],'Designed flesh hit (punch/soft Foley, not actual blade cut); low-end transient + short noise attack')
 save(f'sword_hit_armor_{v+1:02}',mix(me*.7,pu*.3,sub(.16,140)*.2),[m,p],'Real metal clash layered with body impact; generic armor interpretation, not historical armor recording')
 save(f'bow_release_{v+1:02}',mix(read(bow,1+v*.025)*.8,air(.12)*.15),[bow],'Bow release slight pitch variation and air layer; launch only')
 save(f'arrow_hit_body_{v+1:02}',mix(read(p,1.25)*.6,sub(.12,150)*.2,air(.05)*.12),[p],'Designed short projectile/body impact, not recorded arrow strike')
 save(f'arrow_hit_wood_{v+1:02}',mix(read(w,1.2)*.65,air(.05)*.12),[w],'Wood impact shortened via resample, transient air')
 save(f'staff_swing_{v+1:02}',mix(read(s,.78)*.75,filt(air(.4),1800)*.6),[s],'Slower lower swish + band-limited air; staff interpretation')
 save(f'staff_hit_{v+1:02}',mix(wo*.45,pu*.6,sub(.3,85)*.5),[w,p],'Wood+punch+descending sub transient; soft saturation')
 save(f'body_collision_{v+1:02}',mix(so*.7,pu*.4,sub(.4,70)*.6),[soft,p],'Soft body+punch+low-frequency slam; no gain-only enhancement')
t=np.arange(SR*2)/SR
charge=(np.sin(2*np.pi*(90*t+50*t*t))*.25+filt(rng.normal(0,1,len(t)),[150,1700],'bandpass')*.12)*(t/2)**1.3
save('charge_start',charge,[],'Original deterministic synthesized rising tone/filtered noise')
t=np.arange(SR*2)/SR
hold=(np.sin(2*np.pi*120*t)*.22+np.sin(2*np.pi*180*t)*.1+filt(rng.normal(0,1,len(t)),[250,1700],'bandpass')*.15)*(1+.2*np.sin(2*np.pi*4*t))
save('charge_hold_loop',hold,[],'Original synthesized sustained charge; overlap boundary blend; use 20ms crossfade at runtime',True)
save('charge_release',mix(air(.5)*.9,sub(.55,90)*.7,buf['sword_hit_armor_01']*.35),['weapons/sfx/sword-knife-clash-01.wav','impact/Audio/impactPunch_heavy_000.ogg'],'Synthesized burst + metal/body processed layer')
x=np.zeros(SR*2)
for start in [0,.5,1,1.5]:
 a=air(.46);i=int(start*SR);x[i:i+len(a)]+=a
save('spin_swing_loop',mix(x,hold*.3),[],'Original synthesized four accelerating-feel air swells over tonal bed; 20ms crossfade recommended',True)
save('spin_finish',mix(air(.65),sub(.5,70)*.7,buf['staff_hit_01']*.5),['impact/Audio/impactWood_heavy_000.ogg','impact/Audio/impactPunch_heavy_000.ogg'],'Synthesized final air sweep+processed staff impact; only trigger hit layer if actual collision')
(P/'manifest.json').write_text(json.dumps(records,ensure_ascii=False,indent=2))
# generous silence separates demonstrations; first variation only
preview=[];index=[];pos=0
names=[r['id'] for r in records if r['id'].endswith('_01') or not r['id'][-2:].isdigit()]
for n in names:
 x=buf[n];xx=np.tile(x,2) if 'loop' in n else np.concatenate([x,np.zeros(int(SR*.25)),x])
 index.append({'at_seconds':round(pos/SR,3),'id':n,'demonstration':'loop twice' if 'loop' in n else 'one-shot twice'});preview.extend([xx,np.zeros(SR)]);pos+=len(xx)+SR
x=np.concatenate(preview);wavfile.write(P/'preview.wav',SR,(x*32767).astype(np.int16));sp.run(['ffmpeg','-v','error','-y','-i',str(P/'preview.wav'),'-codec:a','libmp3lame','-b:a','192k',str(P/'Sengoku_Weapon_SFX_Preview_v1.mp3')],check=True)
(P/'docs/preview-index.json').write_text(json.dumps(index,indent=2));print(json.dumps(index));print('sounds',len(records),'seconds',len(x)/SR)
