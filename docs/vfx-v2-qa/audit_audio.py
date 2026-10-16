import json,hashlib,subprocess,sys
from pathlib import Path
import numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly
r=Path(sys.argv[1]);out=Path(sys.argv[2]);m=json.loads((r/'manifest.json').read_text());report={}
for key,a in m['assets'].items():
 p=r/a['wav'];assert hashlib.sha256(p.read_bytes()).hexdigest()==a['sha256']
 sr,x=wavfile.read(p);assert sr==48000 and x.ndim==1 and x.dtype==np.int16
 x=x.astype(float)/32768;assert abs(len(x)/sr-a['seconds'])<1/sr
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(r/a['ogg']),'-f','f32le','-ar','48000','-ac','1','-']);y=np.frombuffer(raw,np.float32)
 assert abs(len(x)-len(y))<1024 and np.max(abs(y))<1
 report[key]={'wav_sha256':a['sha256'],'wav_peak_dbfs':float(20*np.log10(np.max(abs(x)))),'ogg_peak_dbfs':float(20*np.log10(np.max(abs(y)))),'ogg_4x_true_peak_dbfs':float(20*np.log10(np.max(abs(resample_poly(y,4,1))))),'ogg_clipped_samples':int(np.sum(abs(y)>=1))}
assert len(report)==41
out.write_text(json.dumps({'scope':'Numerical decode/hash validation only; not listening approval','assets':report},indent=2))
print('PASS:',len(report),'WAV hashes/formats/durations and OGG decode; zero clipped samples; maximum OGG sample/4x peaks',max(v['ogg_peak_dbfs'] for v in report.values()),max(v['ogg_4x_true_peak_dbfs'] for v in report.values()))
