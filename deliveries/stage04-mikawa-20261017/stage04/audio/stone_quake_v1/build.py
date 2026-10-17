import json,hashlib,subprocess,wave,shutil,math
from pathlib import Path
import numpy as np
from scipy.signal import butter,sosfilt,resample
R=Path(__file__).parent; SRC=Path('/workspace/scratch/98b7ec868bfb/stage4_object_sfx_v1/originals/impact/Audio');SR=48000
cache={}
def read(name):
 if name not in cache:
  p=SRC/name;shutil.copy2(p,R/'source_clips'/name)
  x=np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar',str(SR),'-f','f64le','-']),dtype='<f8').copy()
  active=np.flatnonzero(abs(x)>max(abs(x).max()*.025,.0005));x=x[max(0,active[0]-96):] if len(active) else x
  cache[name]=x
 return cache[name].copy()
def filt(x,lo,hi):return sosfilt(butter(3,[lo,hi],fs=SR,btype='bandpass',output='sos'),x)
def slow(x,factor):return resample(x,int(len(x)/factor))
def norm(x):return x/max(abs(x).max(),1e-9)
def layer(out,x,t,g):
 i=int(t*SR);n=min(len(out)-i,len(x));out[i:i+n]+=x[:n]*g

def save(id,x,event,sources,recipe,gain):
 x=filt(x,32,10500); x=np.tanh(x*1.15);x*=10**(-3/20)/max(abs(x).max(),1e-9)
 fade=min(int(.04*SR),len(x));x[-fade:]*=np.linspace(1,0,fade);x[:72]*=np.linspace(0,1,72)
 p=R/'wav'/(id+'.wav')
 with wave.open(str(p),'wb') as w:w.setparams((1,2,SR,0,'NONE','not compressed'));w.writeframes((np.clip(x,-1,1)*32767).astype('<i2').tobytes())
 o=R/'ogg'/(id+'.ogg');subprocess.run(['ffmpeg','-v','error','-y','-i',str(p),'-c:a','libvorbis','-q:a','6',str(o)],check=True)
 item=dict(id=id,event_id=event,wav='wav/'+p.name,ogg='ogg/'+o.name,seconds=len(x)/SR,sample_rate=SR,channels=1,gain_linear=gain,loop=False,source_files=['source_clips/'+n for n in sources],source_sha256={n:hashlib.sha256((SRC/n).read_bytes()).hexdigest() for n in sources},recipe=recipe,license='CC0 1.0 source material; derived original sound design',origin='Kenney Impact Sounds 1.0; mining/contact Foley, not authenticated falling-rock field recording',wav_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),ogg_sha256=hashlib.sha256(o.read_bytes()).hexdigest(),listening_review='Subjective audition pending; waveform QA is not listening verification')
 manifest.append(item);return x
manifest=[];pre=[]
for i in range(3):
 mining=f'impactMining_{i:03}.ogg'; mining2=f'impactMining_{(i+2)%5:03}.ogg'; concrete=f'footstep_concrete_{i:03}.ogg'; soft=f'impactSoft_heavy_{i:03}.ogg'
 a=read(mining); b=read(mining2); c=read(concrete);d=read(soft)
 # Distinct source material: mining crack, short concrete grit, slowed physical impact body.
 x=np.zeros(int((.95+.08*i)*SR));layer(x,norm(filt(a,350,6500)),0,.62);layer(x,norm(filt(slow(a,.42+.025*i),45,260)),.008,.70);layer(x,norm(filt(d,45,220)),.004,.50)
 for j,t in enumerate([.085,.145,.23,.34,.47,.61]):
  chip=filt(slow(b if j%2 else c,.72+.075*j+.025*i),700,7600); chip=chip[:int(.11*SR)];chip*=np.exp(-np.arange(len(chip))/SR*24)
  layer(x,norm(chip),t,.22*np.exp(-j*.32))
 pre.append(save(f'rock_impact_crumble_{i+1:02}',x,'rock_impact_crumble',[mining,mining2,concrete,soft],'Layer unmodified mining crack with 0.42–0.47x resampled low body (45–260Hz), soft physical impact, six staggered mining/concrete chips; 32Hz highpass, soft saturation, -3dBFS sample peak, 40ms tail fade. No staff or synthesized oscillator.',.72))
 x=np.zeros(int((1.05+.08*i)*SR)); low=norm(filt(slow(a,.22+.018*i),38,180));mid=norm(filt(slow(d,.45),70,330))
 layer(x,low,0,.95);layer(x,mid,.007,.65);layer(x,norm(filt(a,250,2000)),0,.26)
 for t,g in [(0.09,.30),(.22,.19),(.39,.11)]:layer(x,low,t,g)
 # Fast exponential decay leaves room between the 0.68-second triple slam beats.
 x*=np.exp(-np.arange(len(x))/SR*4.0)
 pre.append(save(f'ground_quake_thump_{i+1:02}',x,'ground_quake_thump',[mining,soft],'Resampled mining impact at0.22–0.256x filtered38–180Hz plus slowed physical soft impact70–330Hz; quiet mining transient250–2000Hz; three diminishing body reflections90/220/390ms, exponential decay4/sec. Derived grounded quake design, no staff, oscillator, or electronic pitch sweep.',.70))
(R/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
preview=np.concatenate([np.concatenate([x,np.zeros(int(.65*SR))]) for x in pre]);p=R/'preview.wav'
with wave.open(str(p),'wb') as w:w.setparams((1,2,SR,0,'NONE','not compressed'));w.writeframes((preview*32767).astype('<i2').tobytes())
subprocess.run(['ffmpeg','-v','error','-y','-i',str(p),'-codec:a','libmp3lame','-q:a','2',str(R/'preview.mp3')],check=True)
shutil.copy2(SRC.parent/'License.txt',R/'docs'/'Kenney-License.txt')
print('created',len(manifest),'derived clips')
