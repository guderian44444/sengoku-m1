"""Read-only offline verification of this expanded handoff; no game runtime implied."""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
B=Path(__file__).resolve().parent

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def rgba(p):return Image.open(p).convert('RGBA')
def pixels(p):return np.array(rgba(p)).astype('int16')
def delta(a,b):return int(np.abs(pixels(a)-pixels(b)).max())
manifest=json.load(open(B/'character_manifest.json'))
integration=json.load(open(B/'integration_manifest.json'))
assert manifest['approval']=='accepted' and manifest['current_run_revision']=='run_v5'
assert integration['runtime_tested'] is False
assert manifest['approval_basis']['message_id']=='Sentinel_003f9aaa53ac819191a42c7ac9485ce8'
files=sorted(p for p in B.rglob('*') if p.is_file() and '__pycache__' not in p.parts)
assert all(p.stat().st_size<100_000_000 for p in files)
hashes={}
for line in (B/'SHA256SUMS').read_text().splitlines():
 h,rel=line.split('  ',1);p=B/rel;assert p.is_file() and digest(p)==h,rel;hashes[rel]=h
assert set(hashes)=={str(p.relative_to(B)) for p in files if p.name!='SHA256SUMS'}
frames=0;source_references=0
for item in manifest['actions']:
 m=json.load(open(B/item['metadata']));d=B/item['revision_folder'];assert m['approval']=='accepted'
 assert m['approval_basis']['message_id']==manifest['approval_basis']['message_id']
 t=0
 for i,f in enumerate(m['frames'],1):
  assert f['frame']==i and f['start_ms']==t;t+=f['duration_ms']
  assert f['root_canvas']==[220,280] and f['world_delta']==[0,0]
  assert len(f['preview_displacement'])==2 and f['layer_order']==['body','weapon','hand_occlusion']
  assert 'landing' in f and 'settle' in f and 'loop_next' in f and 'weapon_angle_degrees' in f
  assert all(k in f['feet_canvas'] for k in ['near','far'])
  im=Image.new('RGBA',(480,320))
  for n in m['layers']:
   layer=rgba(d/f['layer_files'][n]);assert layer.size==(480,320);im.alpha_composite(layer)
  assert np.array_equal(np.array(im),np.array(rgba(d/f['composite_file'])))
  alpha=np.array(im)[:,:,3];assert not np.any(np.r_[alpha[0],alpha[-1],alpha[:,0],alpha[:,-1]])
  for s in f['source_parts']:
   p=B/s['path'];assert p.is_file() and digest(p)==s['sha256'];source_references+=1
   if 'source_bbox' in s:
    x0,y0,x1,y1=s['source_bbox'];w,h=rgba(p).size
    assert 0<=x0<x1<=w and 0<=y0<y1<=h
    assert y1-y0==s['source_effective_height']
  expected_next=(i+1 if i<len(m['frames']) else 1 if m['loop'] else None)
  assert f['loop_next']==expected_next
  frames+=1
 assert t==m['total_ms']==item['total_ms']
 assert len(m['frames'])==item['frame_count']
assert frames==50
for a,b in [('down/composite_02.png','recovering/composite_01.png'),('recovering/composite_05.png','idle/composite.png'),('hurt/composite_06.png','idle/composite.png'),('jump/composite_08.png','idle/composite.png'),('victory_v2/composite_06.png','idle/composite.png')]:assert delta(B/a,B/b)==0
idle=Image.new('RGBA',(480,320))
for n in manifest['layers']:idle.alpha_composite(rgba(B/f'idle/{n}.png'))
assert np.array_equal(np.array(idle),np.array(rgba(B/'idle/composite.png')))
oldrun=json.load(open(B/'provenance/run_v4_locked_baseline/metadata.json'))
newrun=json.load(open(B/'run_v5/metadata.json'))
for i,f in enumerate(newrun['frames'],1):
 mask=np.array(Image.open(B/f'run_v5/masks/protected_legs_{i:02}.png').convert('L'))>0
 a=pixels(B/f'run_v5/composite_{i:02}.png');b=pixels(B/f'provenance/run_v4_locked_baseline/composite_{i:02}.png');assert np.max(np.abs(a-b)[mask])==0
 for k in ['root_canvas','duration_ms','start_ms','preview_displacement','world_delta']:
  assert f[k]==oldrun['frames'][i-1][k]
 assert all(f['feet_canvas'][k]==oldrun['frames'][i-1]['feet_canvas'][k] for k in ['near','far'])
portrait=json.load(open(B/'portrait/provenance.json'))
expected=rgba(B/'approved_reference/actions/light_1_source.png').crop(portrait['crop'])
assert np.array_equal(np.array(expected),np.array(rgba(B/'portrait/portrait.png')))
for p in files:
 if p.suffix.lower() in ['.png','.jpg','.gif']:
  with Image.open(p) as im:im.verify()
print(json.dumps({'result':'PASS','accepted_actions':9,'frames_recomposed':frames,'source_references_sha_verified':source_references,'sha256_files_verified':len(hashes),'largest_file_bytes':max(p.stat().st_size for p in files),'run_v5_protected_leg_frames_exact':6,'exact_transition_pairs':5,'runtime_tested':False},indent=2))
