"""Eight sequential neutral cues at the controller's default runtime gain. No voice."""
from pathlib import Path
import json,hashlib
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly
R=Path(__file__).resolve().parent;SR=48000
keys=['neutral_slash_arc','thrust_cone','arrow_trail','throwing_blade_trail','blunt_impact','guard_sparks','slash_hit','dash_dust']
out=np.zeros(8*SR);events=[]
for i,key in enumerate(keys):
 sr,x=wavfile.read(R/'wav'/(key+'.wav'));assert sr==SR
 x=x.astype(float)/32768
 # Default context intensity=1, phase_progress=0: -18dB base -2dB grow, pitch .98.
 pos=np.arange(0,len(x)-1,.98);x=np.interp(pos,np.arange(len(x)),x)*10**(-20/20)
 start=i*SR;out[start:start+len(x)]+=x
 events.append({'tick':i*60,'seconds':i,'instance_id':'neutral_demo_'+str(i),'cue_key':key,'operation':'start','context':{'intensity':1.0,'phase_progress':0.0},'gain_db':-20.0,'pitch_scale':.98})
path=R/'neutral_cases_8s.wav';wavfile.write(path,SR,(out*32767).astype(np.int16))
report={'duration_seconds':8,'fps':60,'events':events,'loop':False,'voice':False,'presentation_master_gain_db':0,'sample_peak_dbfs':float(20*np.log10(max(abs(out)))),'true_peak_estimate_4x_dbfs':float(20*np.log10(max(abs(resample_poly(out,4,1))))),'clipped_samples':int(np.sum(abs(out)>=1)),'wav_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'audition_status':'not subjectively auditioned'}
(R/'neutral_demo_events.json').write_text(json.dumps(report,indent=2)+'\n')
freeze=json.loads((R/'FREEZE.json').read_text())
for name in ['neutral_cases_8s.wav','neutral_demo_events.json','render_neutral_demo.py']:freeze['hashes'][name]=hashlib.sha256((R/name).read_bytes()).hexdigest()
(R/'FREEZE.json').write_text(json.dumps(freeze,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['duration_seconds','sample_peak_dbfs','true_peak_estimate_4x_dbfs','clipped_samples']}))
