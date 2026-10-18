"""Independent zero-movement, exact-RGBA verification of the visible layer package."""
from pathlib import Path
from PIL import Image
import argparse,hashlib,json
import numpy as np
D=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--source',type=Path,default=D.parent.parent/'nobunaga_impact_v4/throw_reverse_planted_v2');args=p.parse_args()
original=json.loads((args.source/'frame-manifest.json').read_text());rows=json.loads((D/'frame-manifest.json').read_text())
assert len(rows)==len(original)==16 and sum(r['duration_ms'] for r in rows)==800
checks=[]
for r,source_r in zip(rows,original):
 k=r['frame'];fn=f'{k:03}.png';source=args.source/'frames-native'/fn
 assert sha(source)==source_r['rgba_sha256']==r['approved_source_sha256']
 expected=np.array(Image.open(source).convert('RGBA'));out=None;owners=np.zeros(expected.shape[:2],dtype=np.uint8)
 for key in r['layer_order']:
  path=D/r['layer_paths'][key]['path'];assert sha(path)==r['layer_paths'][key]['sha256']
  layer=Image.open(path);assert layer.mode=='RGBA' and layer.size==(1800,1700)
  mask=np.array(Image.open(D/'masks'/key/fn));assert set(np.unique(mask)).issubset({0,255});owners+=(mask>0).astype('uint8')
  a=np.array(layer);assert np.array_equal(a[mask>0],expected[mask>0]);assert not a[mask==0].any()
  if out is None:out=layer.copy()
  else:out.alpha_composite(layer)
 assert (owners==1).all();out=np.array(out);assert np.array_equal(out,expected)
 assert r['grip_palm_centers_native']==source_r['manual_palm_centers_native_after_warp']
 assert r['root_anchor_native']==source_r['root_anchor_native']
 assert r['fixed_sole_contacts_native']==source_r['fixed_sole_contacts_native']
 assert all(t==[1,0,0,0,1,0] for t in r['transforms'].values())
 checks.append({'frame':k,'identical_rgba':True,'max_channel_error':0,'exact_metadata_inheritance':True})
result={'status':'PASS','frames':16,'canvas':[1800,1700],'duration_ms':800,'layers':48,'masks':48,'source_hashes_unchanged':True,'all_original_pixels_reconstructed_exactly':True,'geometry_and_palm_metadata_unchanged':True,'frames_checked':checks}
(D/'independent-verification.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
