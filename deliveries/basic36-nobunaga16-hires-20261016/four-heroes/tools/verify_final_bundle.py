from pathlib import Path
from PIL import Image,ImageChops
import json,hashlib,math
D=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
m=json.loads((D/'manifest.json').read_text());assert m['accepted_action_count']==36 and m['game_frame_count']==212 and not m['runtime_tested'];frames=0
for a in m['actions']:
 j=json.loads((D/a['contract']).read_text());assert j['status']=='accepted' and not j['runtime_tested'];assert sum(f['duration_ms'] for f in j['frames'])==j['total_duration_ms'];assert len(j['frames'])==j['frame_count']
 if a['character']=='ieyasu' and a['action']=='run':assert '/run_v5/' in j['source_metadata']
 for f in j['frames']:
  assert len(f['root_canvas_px'])==2 and len(f['preview_displacement_px'])==2 and len(f['world_displacement_px'])==2 and math.isfinite(f['weapon_angle_degrees'])
  assert len([x for x in f['feet_canvas_px'].values() if x is not None])>=2
  layers={n:Image.open(D/p).convert('RGBA') for n,p in f['layers'].items()};assert set(layers)=={'body','weapon','hand_occlusion'}
  co=Image.new('RGBA',tuple(f['canvas_size_px']))
  for n in f['layer_order_back_to_front']:co.alpha_composite(layers[n])
  ex=Image.open(D/f['composite']).convert('RGBA');assert not any(v[1] for v in ImageChops.difference(co,ex).getextrema())
  bb=ex.getchannel('A').getbbox();w,h=ex.size;assert bb and bb[0]>0 and bb[1]>0 and bb[2]<w and bb[3]<h
  frames+=1
assert frames==212
for c in m['characters']:
 C=D/c
 for line in (C/'SHA256SUMS').read_text().splitlines():
  if not line.strip():continue
  digest,path=line.split(None,1);path=path.lstrip('* ');assert sha(C/path)==digest,(c,path,'hash mismatch')
files=[f for f in D.rglob('*') if f.is_file()];assert not any(f.is_symlink() for f in files);oversized=[str(f.relative_to(D)) for f in files if f.stat().st_size>=100_000_000];assert not oversized,oversized
if (D/'SHA256SUMS').exists():
 for line in (D/'SHA256SUMS').read_text().splitlines():
  digest,path=line.split(None,1);assert sha(D/path.lstrip('* '))==digest,path
print(json.dumps({'status':'pass','actions':36,'accepted':36,'frames':frames,'file_count':len(files),'total_bytes':sum(f.stat().st_size for f in files),'max_file_bytes':max(f.stat().st_size for f in files),'runtime_tested':False}))
