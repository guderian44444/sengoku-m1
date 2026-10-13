"""Original deterministic DSP SFX; existing project VoiceDesign recordings remastered, not regenerated."""
import json, subprocess, hashlib, wave, math, argparse
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile
ROOT=Path(__file__).resolve().parent
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--repo', type=Path, required=True, help='Path to the source game repository containing game/audio/v11')
args=parser.parse_args()
REPO=args.repo.resolve()
if not (REPO/'game/audio/v11/manifest.json').is_file():
 parser.error('--repo must contain game/audio/v11/manifest.json')
SR=48000
rng=np.random.default_rng(20261013)
HITS={'nobunaga':[26,68,110,152,192],'oichi':[26,68,110,152,192],'hideyoshi':[18,44,70,96,122,148,174,198],'ieyasu':[36,102,168],'mitsuhide':[24,66,108,150,192],'tadakatsu':[36,84,132,180]}
ELEMENTS={'nobunaga':'fire','oichi':'ice','hideyoshi':'wind','ieyasu':'fire_earth','mitsuhide':'blade','tadakatsu':'fire_spear'}
manifest={'sample_rate':SR,'voice_status':'existing_project_voice_remaster_not_new_performance','listening_review':'pending; numerical QA is not audition','actors':{},'assets':{}}
def db(x): return float(20*np.log10(max(float(x),1e-12)))
def noise(n,lo,hi):
 x=rng.normal(size=n); sos=signal.butter(3,[lo,hi],btype='bandpass',fs=SR,output='sos');return signal.sosfilt(sos,x)
def tone(t,f0,f1): return np.sin(2*np.pi*(f0*t+(f1-f0)*t*t/(2*max(t[-1],1e-5))))
def fade(x):
 n=len(x); a=min(240,n//10); b=min(2400,n//5);x[:a]*=np.linspace(0,1,a);x[-b:]*=np.linspace(1,0,b);return x

def save(key,x,folder='wav',peak=-5):
 x=fade(x-x.mean());x=x/max(np.max(np.abs(x)),1e-12)*10**(peak/20)
 dst=ROOT/folder/(key+'.wav');wavfile.write(dst,SR,(x*32767).astype(np.int16));ogg=ROOT/('voice_ogg' if folder=='voice_wav' else 'ogg')/(key+'.ogg')
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(dst),'-c:a','libvorbis','-q:a','6',str(ogg)],check=True)
 record={'wav':str(dst.relative_to(ROOT)),'ogg':str(ogg.relative_to(ROOT)),'seconds':len(x)/SR,'peak_dbfs':db(np.max(abs(x))),'rms_dbfs':db(np.sqrt(np.mean(x*x))),'true_peak_estimate_4x_dbfs':db(np.max(abs(signal.resample_poly(x,4,1)))),'clipped_samples':int(np.sum(abs(x)>=1)),'sha256':hashlib.sha256(dst.read_bytes()).hexdigest()}
 manifest['assets'][key]=record
 return x

def fx(actor,phase):
 idx=list(HITS).index(actor); d=HITS[actor][0]/60 if phase=='charge' else (0.48 if phase=='release' else 1.05)
 t=np.arange(int(SR*d))/SR;n=len(t);e=ELEMENTS[actor]
 if phase=='charge':
  env=(t/d)**1.5; x=(.4*noise(n,220,2600)+.3*tone(t,110+idx*17,470+idx*80))*env
 elif 'fire' in e:
  env=np.exp(-t/(.18 if phase=='release' else .39));x=(1.2*noise(n,60,1900)+.45*noise(n,2500,7000)+.7*tone(t,140+idx*9,38))*env
  for at in [0.03,.09,.16,.25,.37]:
   j=int(at*SR); m=min(int(.025*SR),n-j)
   if m>0:x[j:j+m]+=.27*noise(m,1800,8500)*np.exp(-np.arange(m)/SR/.007)
  if e=='fire_earth':x+=.6*np.sin(2*np.pi*53*t)*np.exp(-t/.25)
  if e=='fire_spear':x+=.4*tone(t,2900,550)*np.exp(-t/.075)
 elif e=='ice':
  x=.55*noise(n,1900,10500)*np.exp(-t/.11)
  for f in [1237,1873,2761,3907,5101]:x+=.13*np.sin(2*np.pi*f*t)*np.exp(-t/(.16+f/24000))
  x+=.3*tone(t,180,45)*np.exp(-t/.13)
 elif e=='wind':
  x=noise(n,350,7200)*np.sin(np.minimum(t/.28,1)*np.pi)**2*np.exp(-t/.4)
  x+=.24*tone(t,1300,190)*np.exp(-t/.12)
 else:
  x=noise(n,1300,9000)*np.exp(-t/.07)+.5*tone(t,2800,430)*np.exp(-t/.1)
  for f in [921,2089,4163]:x+=.16*np.sin(2*np.pi*f*t)*np.exp(-t/.25)
 if phase=='final':x+=.5*tone(t,100,30)*np.exp(-t/.25)
 return x

lines=json.loads((REPO/'game/audio/v11/lines.json').read_text())
original=json.loads((REPO/'game/audio/v11/manifest.json').read_text())
for actor, spec in lines['actors'].items():
 key=actor+'_special_0';src=REPO/'game/audio/v11'/(key+'.wav')
 if not src.exists():continue
 # EQ and controlled dynamics, no pitch shift, no timing edit, no voice cloning.
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(src),'-af','highpass=f=95,lowpass=f=9000,equalizer=f=1900:t=q:w=0.8:g=1.5,acompressor=threshold=0.2:ratio=2:attack=6:release=70:makeup=1','-ar',str(SR),'-ac','1','-f','f32le','-'])
 x=np.frombuffer(raw,np.float32).astype(float).copy();save(key,x,'voice_wav',-3.5)
 manifest['assets'][key].update(source=str(src.relative_to(REPO)),source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),source_backend=original['clips'][key].get('backend'),text=spec['clips']['special'][0],voice_description=spec['voice_description'])
 manifest['actors'][actor]={'voice':key,'text':spec['clips']['special'][0],'voice_start_tick':0,'voice_per_activation':1,'vocal_performance_changed':False}
for actor,ticks in HITS.items():
 layers={p:save(actor+'_'+p,fx(actor,p),peak=-8 if p=='charge' else -5) for p in ['charge','release','final']}
 manifest['actors'][actor].update(hit_ticks=ticks,duration_ticks=210,sfx_element=ELEMENTS[actor],charge=actor+'_charge',release=actor+'_release',final=actor+'_final',timebase_fps=60)
 mixed=np.zeros(int(4.5*SR));mixed[:len(layers['charge'])]+=.30*layers['charge']
 for i,tick in enumerate(ticks):
  x=layers['final' if i==len(ticks)-1 else 'release'];j=round(tick*SR/60);mixed[j:j+len(x)]+=.5*x
 _,voice=wavfile.read(ROOT/'voice_wav'/(actor+'_special_0.wav'));voice=voice.astype(float)/32768
 # Audition mix ducks effects under speech, then restores smoothly.
 duck=np.ones(len(mixed)); nv=min(len(voice),len(mixed));duck[:nv]=.50
 end=min(len(mixed),nv+int(.2*SR));duck[nv:end]=np.linspace(.5,1,end-nv)
 mixed*=duck;mixed[:nv]+=.85*voice[:nv];save(actor+'_preview',mixed,peak=-2)
 manifest['actors'][actor]['preview']=actor+'_preview'
manifest['actors']['hideyoshi']['new_authoring_name_unvoiced']='千成奇策'
manifest['actors']['ieyasu']['new_authoring_name_unvoiced']='三河不動'
(ROOT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
print('Created',len(manifest['assets']),'assets. Actors',len(manifest['actors']))
