from pathlib import Path
from PIL import Image
import math,json,struct

def quantize(d):
 total=0;prev=0;out=[]
 for v in d:
  total+=v;cur=math.floor(total/10+.5)*10;out.append(cur-prev);prev=cur
 return out

def patch_gif(path,durations):
 # Change only Graphics Control Extension delay bytes. Compressed image data untouched.
 data=bytearray(path.read_bytes());pos=13
 if data[10]&128:pos+=3*(2**((data[10]&7)+1))
 offsets=[]
 def blocks(pos):
  while data[pos]:pos+=1+data[pos]
  return pos+1
 while pos<len(data):
  marker=data[pos];pos+=1
  if marker==0x3b:break
  if marker==0x21:
   label=data[pos];pos+=1
   if label==0xf9:offsets.append(pos+2)
   pos=blocks(pos)
  elif marker==0x2c:
   packed=data[pos+8];pos+=9
   if packed&128:pos+=3*(2**((packed&7)+1))
   pos+=1;pos=blocks(pos)
  else:raise ValueError((path,pos,marker))
 assert len(offsets)==len(durations),(path,len(offsets),len(durations))
 for offset,ms in zip(offsets,durations):data[offset:offset+2]=struct.pack('<H',ms//10)
 path.write_bytes(data)
 im=Image.open(path);actual=[]
 for i in range(im.n_frames):im.seek(i);actual.append(im.info.get('duration',0))
 assert actual==durations,(actual,durations)
 return actual

if __name__=='__main__':
 p=Path(__file__).parent
 for key in ['charge_release','dash_heavy','air_heavy']:
  d=p/key;m=json.loads((d/'metadata.json').read_text());frames=m['frames'];original=[f['duration'] for f in frames];dur=quantize(original)
  for gif in d.glob('*.gif'):
   im=Image.open(gif)
   if im.n_frames==len(dur):patch_gif(gif,[v*3 for v in dur] if 'slow' in gif.name else dur)
  elapsed=0
  for f,v in zip(frames,dur):f['source_design_duration']=f['duration'];f['duration']=v;f['start_ms']=elapsed;elapsed+=v
  m['source_design_total_ms']=sum(original);m['gif_decoded_total_ms']=sum(dur);m['gif_decoded_durations_ms']=dur;m['timing_quantization']='cumulative nearest 10ms, no cumulative truncation';m['total_duration_ms']=sum(dur)
  if 'total_ms' in m:m['total_ms']=sum(dur)
  for event in m.get('strike_events',[]):event['start_ms']=sum(dur[:event['frame']-1])
  (d/'metadata.json').write_text(json.dumps(m,indent=2));print(key,sum(original),sum(dur),dur)
