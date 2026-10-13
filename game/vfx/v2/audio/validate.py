import json,subprocess,io
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly
r=Path(__file__).resolve().parent;m=json.loads((r/'manifest.json').read_text());report={}
for key,a in m['assets'].items():
 sr,x=wavfile.read(r/a['wav']);x=x.astype(float)/32768
 assert sr==48000 and x.ndim==1 and np.max(abs(x))<1
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(r/a['ogg']),'-f','f32le','-ar','48000','-ac','1','-']);y=np.frombuffer(raw,np.float32)
 assert abs(len(x)-len(y))<1024 and np.max(abs(y))<1
 p=subprocess.run(['ffmpeg','-hide_banner','-i',str(r/a['wav']),'-af','ebur128=peak=true','-f','null','-'],capture_output=True,text=True,check=True)
 summary=p.stderr.split('Summary:')[-1].strip()
 report[key]={'ogg_peak_dbfs':float(20*np.log10(np.max(abs(y)))),'ogg_true_peak_estimate_4x_dbfs':float(20*np.log10(np.max(abs(resample_poly(y,4,1))))),'ogg_clipped_samples':int(np.sum(abs(y)>=1)),'wav_loudness_summary':summary}
(r/'validation.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS WAV + OGG decode,48k mono,no digital clipping:',len(report));print('max OGG peak',max(v['ogg_peak_dbfs'] for v in report.values()))
