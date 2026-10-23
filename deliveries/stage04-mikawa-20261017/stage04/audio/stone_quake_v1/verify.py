import json,subprocess,hashlib,math
from pathlib import Path
import numpy as np
R=Path(__file__).parent;m=json.loads((R/'manifest.json').read_text());out=[]
for c in m:
 for fmt in ['wav','ogg']:
  p=R/c[fmt];raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f64le','-ac','1','-ar','48000','-']);x=np.frombuffer(raw,dtype='<f8');peak=max(abs(x));fft=abs(np.fft.rfft(x))**2;freq=np.fft.rfftfreq(len(x),1/48000)
  row={'id':c['id'],'format':fmt,'decode_ok':True,'seconds':len(x)/48000,'finite':bool(np.isfinite(x).all()),'clipped_samples':int(sum(abs(x)>=1)),'peak_dbfs':20*math.log10(max(peak,1e-12)),'rms_dbfs':20*math.log10(max(np.sqrt(np.mean(x*x)),1e-12)),'low_band_35_220Hz_energy_fraction':float(sum(fft[(freq>=35)&(freq<=220)])/sum(fft)),'tail_last50ms_rms_dbfs':20*math.log10(max(np.sqrt(np.mean(x[-2400:]**2)),1e-12)),'sha_match':hashlib.sha256(p.read_bytes()).hexdigest()==c[fmt+'_sha256']};out.append(row)
assert all(x['finite'] and x['clipped_samples']==0 and x['sha_match'] for x in out)
(R/'verification.json').write_text(json.dumps({'files':out,'technical_pass':True,'subjective_listening':'Not performed; source and spectral measurements cannot prove perceived strength or material realism.'},indent=2));print(json.dumps(out,indent=2))
