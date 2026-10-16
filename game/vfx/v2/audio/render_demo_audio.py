"""Render deterministic cue-driven SFX track for the matching five-element 18s visual demo."""
from pathlib import Path
import json,numpy as np
from scipy.io import wavfile
from scipy.signal import resample_poly
R=Path(__file__).resolve().parent;SR=48000;FPS=60;events=[]
for index,el in enumerate(['blade','fire','ice','wind','lightning']):
 base=index*216
 for kind in ['charge','spin']:
  ident=f'demo_{el}_{kind}'
  def cue(t,key,op='start',progress=0):events.append({'tick':base+t,'instance_id':ident,'cue_key':el+'_'+key if key else '', 'operation':op,'context':{'intensity':1.,'phase_progress':progress}})
  cue(0,'activate')
  if kind=='charge':
   cue(0,'charge_loop','loop_start');cue(60,'charge_loop','loop_stop',1);cue(60,'release',progress=1);cue(72,'hit',progress=.5);cue(84,'dissipate',progress=1);cue(102,'','finish',1)
  else:
   cue(0,'release');cue(36,'release',progress=.5);cue(72,'dissipate',progress=1);cue(90,'','finish',1)
events.sort(key=lambda e:e['tick']);timeline={'duration_seconds':18,'fps':FPS,'families':['blade','fire','ice','wind','lightning'],'seconds_per_family':3.6,'events':events,'notes':'No voice. Charged wave upper row, 2-turn growing spin lower row. Tick72 hit is explicitly confirmed for demo target.'}
(R/'demo_events.json').write_text(json.dumps(timeline,indent=2)+'\n')
# Reproducible offline cue mix, independent from visual rendering. Dedicated audition master gain only.
out=np.zeros(18*SR)
for e in events:
 op=e['operation'];key=e['cue_key']
 if op not in ['start','loop_start']:continue
 _,pcm=wavfile.read(R/'wav'/(key+'.wav'));x=pcm.astype(float)/32768;start=round(e['tick']*SR/FPS);isloop=op=='loop_start'
 if isloop:
  stop=next(v['tick'] for v in events if v['tick']>=e['tick'] and v['instance_id']==e['instance_id'] and v['operation']=='loop_stop');n=round((stop-e['tick'])*SR/FPS)
  progress=np.linspace(0,1,n);pitch=.98+.08*progress;pos=np.cumsum(pitch)-pitch[0];y=np.interp(pos%len(x),np.arange(len(x)),x);gain=10**((-24-8+8*progress)/20);y*=gain
 else:
  progress=e['context']['phase_progress'];pitch=.98+.08*progress;pos=np.arange(0,len(x)-1,pitch);y=np.interp(pos,np.arange(len(x)),x)*10**((-18-2+2*progress)/20)
 end=min(len(out),start+len(y));out[start:end]+=y[:end-start]
# One fixed audition master gain; do not infer this is the game's Master setting.
pre=float(max(abs(out)));gain=10**(-3/20)/pre;out*=gain
wavfile.write(R/'five_element_effects_demo_18s.wav',SR,(out*32767).astype(np.int16))
(R/'demo_mix_report.json').write_text(json.dumps({'seconds':18,'sample_peak_dbfs':float(20*np.log10(max(abs(out)))),'true_peak_estimate_4x_dbfs':float(20*np.log10(max(abs(resample_poly(out,4,1))))),'clipped_samples':int(np.sum(abs(out)>=1)),'presentation_master_gain_db':float(20*np.log10(gain)),'runtime_default_mix_unchanged':True,'human_audition':'not performed'},indent=2)+'\n')
print('Rendered 18s cue-driven WAV; events:',len(events))
