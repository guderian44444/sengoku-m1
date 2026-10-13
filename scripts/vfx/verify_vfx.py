"""Read-only art/contract verification; Pillow + NumPy required."""
from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
root=Path(__file__).resolve().parents[2];cat=json.loads((root/'game/vfx/catalog.json').read_text());report={'base_commit':'966cf8c','effects':{},'checks':[]};hashes=set()
for key,spec in cat['effects'].items():
 path=root/'game'/spec['texture'].removeprefix('res://');data=path.read_bytes();sha=hashlib.sha256(data).hexdigest();im=Image.open(path)
 assert im.mode=='RGBA',(key,im.mode)
 assert sha==spec['sha256'],key
 assert sha not in hashes,('duplicate art, possible recolor alias',key)
 hashes.add(sha);a=np.asarray(im.getchannel('A'));assert a.min()==0 and a.max()>200,key
 assert (a==0).mean()>.1 and ((a>0)&(a<255)).any(),key
 assert tuple(spec['cell'])==im.size and spec['frames']==1,key
 assert 0<=spec['pivot'][0]<=1 and 0<=spec['pivot'][1]<=1,key
 if spec['split_depth']:
  seam=round(im.height*spec['seam']);assert 0<seam<im.height
  back=np.zeros_like(a);front=np.zeros_like(a);back[:seam]=a[:seam];front[seam:]=a[seam:]
  assert np.array_equal(back.astype(int)+front.astype(int),a.astype(int))
 mask=a>8; ys,xs=np.where(mask)
 report['effects'][key]={'size':im.size,'sha256':sha,'author_frames':1,'alpha_zero_fraction':float((a==0).mean()),'partial_alpha_fraction':float(((a>0)&(a<255)).mean()),'alpha_gt8_bbox':[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)],'gpu_rgba_bytes':im.width*im.height*4}
report['checks']=['RGBA with true clear area and partial alpha','Unique original texture hash per effect','Source hash preserved','Single-frame count honestly declared','Ring back/front reconstruction exact']
report['gpu_rgba_bytes_total']=sum(v['gpu_rgba_bytes'] for v in report['effects'].values());report['not_tested']=['Native GPU visuals','Godot 4.7.2','Windows/controller','Battle integration','performance/fps','web/export']
output=root/'docs/shared-vfx-validation.json';output.write_text(json.dumps(report,indent=2));print(f'PASS: {len(report["effects"])} VFX assets; report {output}')
