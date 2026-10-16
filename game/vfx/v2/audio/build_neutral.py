"""Eight original physical-action SFX. No magical hum, no loops, no external samples."""
from pathlib import Path
import json,hashlib,subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile
R=Path(__file__).resolve().parent;SR=48000;rng=np.random.default_rng(2026101304);m=json.loads((R/'manifest.json').read_text())
def band(n,lo,hi):return signal.sosfilt(signal.butter(3,[lo,hi],fs=SR,btype='bandpass',output='sos'),rng.normal(size=n))
recipes={'neutral_slash_arc':(.27,700,7900),'thrust_cone':(.20,1800,10000),'arrow_trail':(.16,2500,11500),'throwing_blade_trail':(.13,3200,11000),'blunt_impact':(.32,55,850),'guard_sparks':(.32,1300,12500),'slash_hit':(.18,600,7500),'dash_dust':(.38,170,2700)}
for key,(d,lo,hi) in recipes.items():
 t=np.arange(round(d*SR))/SR;n=len(t);x=band(n,lo,hi)
 if key in ['neutral_slash_arc','thrust_cone','arrow_trail','throwing_blade_trail']:
  x*=np.sin(np.pi*t/d)**2*np.exp(-t/(d*.8))
 elif key=='blunt_impact':x=x*np.exp(-t/.065)+.65*np.sin(2*np.pi*(98*t-58*t*t))*np.exp(-t/.072)
 elif key=='guard_sparks':
  x*=np.exp(-t/.035)
  for freq in [1729,3131,5791]:x+=.15*np.sin(2*np.pi*freq*t)*np.exp(-t/.115)
 elif key=='slash_hit':x*=np.exp(-t/.03);x+=.20*np.sin(2*np.pi*270*t)*np.exp(-t/.04)
 else:x*=np.exp(-t/.09)*(1+.2*np.sin(2*np.pi*45*t))
 x[:96]*=np.linspace(0,1,96);x[-1200:]*=np.linspace(1,0,1200);x-=x.mean();x*=10**(-7/20)/max(abs(x));p=R/'wav'/(key+'.wav');q=R/'ogg'/(key+'.ogg');wavfile.write(p,SR,(x*32767).astype(np.int16))
 subprocess.run(['ffmpeg','-v','error','-y','-i',str(p),'-c:a','libvorbis','-q:a','6',str(q)],check=True)
 m['assets'][key]={'wav':'wav/'+p.name,'ogg':'ogg/'+q.name,'element':'neutral','phase':'action','loop':False,'seconds':len(x)/SR,'peak_dbfs':float(20*np.log10(max(abs(x)))),'true_peak_4x_dbfs':float(20*np.log10(max(abs(signal.resample_poly(x,4,1))))),'clipped_samples':0,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'layering_recommendation':'context.layered=true on both neutral and element = -6dB each'}
(R/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');print('Added8neutral original cues')
