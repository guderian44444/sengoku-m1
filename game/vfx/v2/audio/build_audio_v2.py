"""Deterministic original five-element DSP effects. No external samples or voices."""
from pathlib import Path
import numpy as np
from scipy import signal
from scipy.io import wavfile
import json,subprocess,hashlib
R=Path(__file__).resolve().parent;SR=48000;rng=np.random.default_rng(2026101302)
ELEMENTS=['blade','fire','ice','wind','lightning'];PHASES=['activate','charge_loop','release','hit','dissipate']
m={'version':2,'sample_rate':SR,'provenance':'Original deterministic DSP; no external recordings or voice','audition_status':'not auditioned; numerical QA only','assets':{}}
def noise(n,lo,hi,loop=False):
 if loop:
  f=np.fft.rfftfreq(n,1/SR);a=rng.normal(size=len(f))+1j*rng.normal(size=len(f));a*=np.exp(-((f-(lo+hi)/2)/((hi-lo)/2))**8);a[0]=0;x=np.fft.irfft(a,n);return x/max(np.std(x),1e-9)
 return signal.sosfilt(signal.butter(3,[lo,hi],btype='bandpass',fs=SR,output='sos'),rng.normal(size=n))
def make(el,ph):
 loop=ph=='charge_loop';dur={'activate':.24,'charge_loop':1.,'release':.65,'hit':.38,'dissipate':.65}[ph];t=np.arange(round(SR*dur))/SR;n=len(t)
 if el=='fire':x=noise(n,70,2800,loop)+.25*noise(n,3600,8000,loop);x*=.8+.2*np.sin(2*np.pi*13*t)
 elif el=='wind':x=noise(n,500,6800,loop)*(.7+.3*np.sin(2*np.pi*3*t));x+=.09*np.sin(2*np.pi*430*t)
 elif el=='ice':
  x=.5*noise(n,2300,10500,loop)
  for freq in [1371,2253,3937,5101]:x+=.12*np.sin(2*np.pi*freq*t)
 elif el=='blade':x=noise(n,1600,9200,loop)+.15*np.sin(2*np.pi*1910*t)+.09*np.sin(2*np.pi*3781*t)
 else:
  buzz=signal.sawtooth(2*np.pi*120*t)*(.35+.2*np.sin(2*np.pi*19*t));x=.6*noise(n,950,9600,loop)+buzz
  # Crackling transient bursts, periodically gated in the loop.
  x+=.7*noise(n,3000,13000,loop)*(np.sin(2*np.pi*37*t)>.93)
 if not loop:
  if ph=='release':env=np.sin(np.minimum(t/.28,1)*np.pi/2)*np.exp(-t/.23)
  elif ph=='activate':env=np.exp(-t/.065)
  elif ph=='hit':env=np.exp(-t/.085)
  else:env=np.exp(-t/.22)
  x*=env
  if ph in ['hit','release']:
   f=150 if el in ['fire','lightning'] else 230
   x+=.48*np.sin(2*np.pi*(f*t-80*t*t))*np.exp(-t/.09)
  x[:144]*=np.linspace(0,1,144);x[-2400:]*=np.linspace(1,0,2400)
 x-=x.mean();peak=-10 if loop else -7;x*=10**(peak/20)/max(abs(x));return x,loop
for el in ELEMENTS:
 for ph in PHASES:
  key=el+'_'+ph;x,loop=make(el,ph);p=R/'wav'/(key+'.wav');wavfile.write(p,SR,(x*32767).astype(np.int16));q=R/'ogg'/(key+'.ogg')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(p),'-c:a','libvorbis','-q:a','6',str(q)],check=True)
  m['assets'][key]={'wav':'wav/'+p.name,'ogg':'ogg/'+q.name,'element':el,'phase':ph,'loop':loop,'seconds':len(x)/SR,'peak_dbfs':float(20*np.log10(max(abs(x)))),'true_peak_4x_dbfs':float(20*np.log10(max(abs(signal.resample_poly(x,4,1))))),'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'clipped_samples':0,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'loop_boundary_delta':float(abs(x[-1]-x[0])) if loop else None}
(R/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');print('Generated',len(m['assets']),'original cues')
