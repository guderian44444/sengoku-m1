"""Original matchlock gunshot design, three stems, four variants per hero/enemy class."""
from pathlib import Path
import json,hashlib,subprocess
import numpy as np
from scipy import signal
from scipy.io import wavfile
R=Path(__file__).resolve().parent;SR=48000;rng=np.random.default_rng(2026101303);(R/'stems').mkdir(exist_ok=True);m=json.loads((R/'manifest.json').read_text())
def band(n,lo,hi):return signal.sosfilt(signal.butter(3,[lo,hi],fs=SR,btype='bandpass',output='sos'),rng.normal(size=n))
def write(p,x):wavfile.write(p,SR,(x*32767).astype(np.int16))
for team in ['hero','enemy']:
 for variant in range(4):
  d=(1.1 if team=='hero' else .58)+variant*.018;t=np.arange(round(d*SR))/SR;n=len(t);hero=team=='hero'
  crack=band(n,450 if hero else 850,11500)*np.exp(-t/(.026 if hero else .017));crack+=.8*band(n,1500,15000)*np.exp(-t/.004)
  freq=(94 if hero else 160)+variant*7;body=np.sin(2*np.pi*(freq*t-35*t*t))*np.exp(-t/(.105 if hero else .060));body+=.6*band(n,40,460)*np.exp(-t/(.12 if hero else .065))
  powder=band(n,90,3900 if hero else 5800)*np.exp(-t/(.20 if hero else .105))*(1-np.exp(-t/.004))
  stems={'crack':crack,'body':body*(1.0 if hero else .45),'powder':powder*(.85 if hero else .5)}
  for x in stems.values():x[:48]*=np.linspace(0,1,48);x[-2400:]*=np.linspace(1,0,2400)
  mix=sum(stems.values());scale=10**(-7/20)/max(abs(mix));mix*=scale
  key=f'{team}_matchlock_shot_{variant}';stempaths={}
  for stem,x in stems.items():
   p=R/'stems'/f'{key}_{stem}.wav';write(p,x*scale);stempaths[stem]=str(p.relative_to(R))
  p=R/'wav'/(key+'.wav');q=R/'ogg'/(key+'.ogg');write(p,mix)
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(p),'-c:a','libvorbis','-q:a','6',str(q)],check=True)
  m['assets'][key]={'wav':'wav/'+p.name,'ogg':'ogg/'+q.name,'element':'matchlock','phase':'shot','team':team,'variant':variant,'loop':False,'seconds':len(mix)/SR,'peak_dbfs':float(20*np.log10(max(abs(mix)))),'true_peak_4x_dbfs':float(20*np.log10(max(abs(signal.resample_poly(mix,4,1))))),'clipped_samples':0,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'stems':stempaths,'design':'Thick low-mid blast plus powder tail' if hero else 'Short dry cutting crack plus compact body'}
(R/'manifest.json').write_text(json.dumps(m,indent=2)+'\n')
# Aligned use cases, modest presentation gain applied equally to all three.
out=np.zeros(8*SR);events=[]
for sec,team,v,distance in [(0,'hero',0,0),(2,'enemy',0,0)]+[(4+i*.05,'enemy',i%4,0) for i in range(10)]+[(6,'hero',1,1)]:
 key=f'{team}_matchlock_shot_{v}';_,x=wavfile.read(R/'wav'/(key+'.wav'));x=x.astype(float)/32768;gain=-18-(3 if team=='enemy' else 0)-12*distance;x*=10**(gain/20);start=round(sec*SR);out[start:start+len(x)]+=x;events.append({'seconds':sec,'cue_key':key,'operation':'start','distance':distance})
master=10**(-3/20)/max(abs(out));out*=master;write(R/'matchlock_cases_8s.wav',out)
(R/'matchlock_demo_events.json').write_text(json.dumps({'duration':8,'cases':['hero shot at0','enemy shot at2','ten enemy volley starts at4, 50ms stagger','hero far shot at6'],'events':events,'presentation_gain_db':float(20*np.log10(master)),'peak_dbfs':float(20*np.log10(max(abs(out)))),'true_peak_4x_dbfs':float(20*np.log10(max(abs(signal.resample_poly(out,4,1))))),'clipped_samples':int(np.sum(abs(out)>=1))},indent=2)+'\n');print('Added8mixes+24stems; cases8s')
