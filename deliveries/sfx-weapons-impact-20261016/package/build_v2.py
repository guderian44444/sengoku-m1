import pathlib, json, numpy as np, subprocess as sp, shutil
from scipy.signal import butter,sosfilt
from scipy.io import wavfile
P=pathlib.Path(__file__).parent; V1=P.parent/'weapon_sfx_v1'; SR=48000
rng=np.random.default_rng(16102602)
records=json.loads((V1/'manifest.json').read_text()); by={r['id']:dict(r) for r in records}; original_by={r['id']:dict(r) for r in records}
def read(p):
 return np.frombuffer(sp.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ac','1','-ar',str(SR),'-']),dtype='<f4').astype(float)
def filt(x,f,t='lowpass'):return sosfilt(butter(2,f,fs=SR,btype=t,output='sos'),x)
def mix(*xs):
 y=np.zeros(max(map(len,xs)))
 for x in xs:y[:len(x)]+=x
 return y
def source(rel):
 x=read(P/'originals'/rel);ix=np.flatnonzero(abs(x)>.004);x=x[max(0,ix[0]-48):ix[-1]+1];return x/max(abs(x))
def save(n,x,src,mods,peak=-3,loop=False):
 x=filt(x-np.mean(x),35,'highpass');k=min(144,len(x)//2);x[:k]*=np.linspace(0,1,k);x[-k:]*=np.linspace(1,0,k)
 x=x/max(abs(x))*10**(peak/20);wavfile.write(P/'processed/wav'/f'{n}.wav',SR,np.round(x*32767).astype(np.int16))
 sp.run(['ffmpeg','-v','error','-y','-i',str(P/'processed/wav'/f'{n}.wav'),'-c:a','libvorbis','-q:a','5',str(P/'processed/ogg'/f'{n}.ogg')],check=True)
 by[n].update(seconds=round(len(x)/SR,5),peak_dbfs=peak,rms_dbfs=round(20*np.log10(np.sqrt(np.mean(x*x))),2),source_files=src,modifications=mods,loop=loop,revision='v2')
for i in range(1,4):
 n=f'sword_swing_{i:02}';x=read(V1/'processed/wav'/f'{n}.wav');x=x[:int(len(x)*.76)];k=min(len(x)//3,2400);x[-k:]*=np.linspace(1,0,k)
 save(n,x,by[n]['source_files'],'v2: v1 swing shortened to 76%, 50ms tail taper, peak reduced by 5dB; no renormalization to hit level',-8)
 n=f'sword_hit_flesh_{i:02}';p=f'impact/Audio/impactPunch_heavy_{i-1:03}.ogg';s=f'impact/Audio/impactSoft_heavy_{i-1:03}.ogg';pu=source(p);so=source(s)
 # Source Foley attack; noise transient only, no synthetic oscillator sweep.
 def decay(x,d):return x[:int(d*SR)]*np.exp(-np.arange(min(len(x),int(d*SR)))/SR*9)
 punch=decay(pu,.30);body=decay(filt(so,1100),.32)
 t=np.arange(int(.035*SR))/SR;attack=filt(rng.normal(size=len(t)),[700,6000],'bandpass')*np.exp(-t*125)
 x=mix(punch*.9,body*.55,attack*.2);x=np.tanh(x*1.25)
 save(n,x,[p,s],'v2: trimmed source Foley leading silence; punch attack foreground + short soft-body layer + 35ms bandpassed transient; capped 320ms; same -3dBFS ceiling')
 # Exact role exchange: all variants, no further audio edits or loudness changes.
 for dest,old in [(f'staff_swing_{i:02}',f'staff_hit_{i:02}'),(f'staff_hit_{i:02}',f'staff_swing_{i:02}')]:
  for ext in ['wav','ogg']:shutil.copy2(V1/f'processed/{ext}/{old}.{ext}',P/f'processed/{ext}/{dest}.{ext}')
  new=dict(original_by[old]);new.update(id=dest,revision='v2',remapped_from_v1=old,modifications='v2 owner-requested exact role exchange, bit-identical to v1 '+old);by[dest]=new
# Naturalistic filtered Foley/grain air, no sinusoidal oscillator/harmonic drone/pitch sweep.
rel='impact/Audio/impactSoft_heavy_000.ogg';rel2='impact/Audio/impactWood_heavy_000.ogg';swrel='battle/battle_sound_effects/swish_3.wav'
soft=source(rel);wood=source(rel2);sw=source(swrel)
def bed(d):
 t=np.arange(int(d*SR))/SR;noise=filt(rng.normal(size=len(t)),[65,900],'bandpass');env=filt(rng.uniform(.25,1,len(t)),9);return noise*env*.8
thump=filt(mix(soft*.8,wood*.2),350);thump=thump[:int(.24*SR)]*np.exp(-np.arange(min(len(thump),int(.24*SR)))/SR*12)
def add(dst,x,time,gain=1):
 a=int(time*SR);n=min(len(x),len(dst)-a)
 if n>0:dst[a:a+n]+=x[:n]*gain
x=bed(1.5);x*=np.linspace(.15,1,len(x))**1.2
for t,g in [(0,.3),(.55,.45),(1.0,.7),(1.28,.9)]:add(x,thump,t,g)
save('charge_start',x,[rel,rel2],'v2: lowpassed soft/wood Foley thumps + growing low band air; no oscillator, pitched drone or pitch sweep',-7)
x=bed(1.98)
for t,g in [(0,.35),(.61,.3),(1.25,.38),(1.69,.28)]:add(x,thump,t,g)
save('charge_hold_loop',x,[rel,rel2],'v2: subdued irregular Foley resonance and low air; no tone; 20ms runtime overlap crossfade recommended',-12,True)
x=mix(sw*.28,thump*1.4,bed(.35)*.2)
save('charge_release',x,[swrel,rel,rel2],'v2: natural swish + lowpassed impact release, no synthetic tone',-3)
x=bed(1.98)*.2
for t,g in [(0,.7),(.49,.8),(.99,.75),(1.49,.85)]:add(x,sw,t,g)
save('spin_swing_loop',x,[swrel],'v2: source swish pulses + quiet low air, removed v1 tonal charge bed; crossfade 20ms',-7,True)
# spin_finish audio remains unchanged; no v2 charge oscillator was present in it.
(P/'manifest.json').write_text(json.dumps(list(by.values()),ensure_ascii=False,indent=2))
# Changed category demo and clearly separate attack->hit pairs.
segments=[];idx=[];pos=0
def item(label,x,events=None):
 global pos
 idx.append(dict(at_seconds=round(pos/SR,3),label=label,events=events or []));segments.extend([x,np.zeros(int(.65*SR))]);pos+=len(x)+int(.65*SR)
def audio(n):return read(P/'processed/wav'/f'{n}.wav')
for n in ['sword_swing_01','sword_hit_flesh_01','staff_swing_01','staff_hit_01','charge_start','charge_hold_loop','charge_release','spin_swing_loop']:
 item(n,audio(n))
for name,a,b in [('刀：揮刀→肉身命中','sword_swing_01','sword_hit_flesh_01'),('棍：空揮→肉身命中（依意見交換）','staff_swing_01','staff_hit_01')]:
 delay=.32;xx=np.zeros(max(len(audio(a)),int(delay*SR)+len(audio(b))));add(xx,audio(a),0);add(xx,audio(b),delay)
 # Shared -3 dB attenuation on pair only for summation headroom, event files unchanged.
 item(name,xx*10**(-3/20),[{'offset_seconds':0,'id':a},{'offset_seconds':delay,'id':b}])
x=np.concatenate(segments);wavfile.write(P/'preview.wav',SR,np.round(x*32767).astype(np.int16));sp.run(['ffmpeg','-v','error','-y','-i',str(P/'preview.wav'),'-c:a','libmp3lame','-b:a','192k',str(P/'Sengoku_Weapon_SFX_Changes_v2.mp3')],check=True)
(P/'docs/preview-index.json').write_text(json.dumps(idx,ensure_ascii=False,indent=2));print(json.dumps(idx,ensure_ascii=False));print('duration',len(x)/SR,'peak',20*np.log10(max(abs(x))))
