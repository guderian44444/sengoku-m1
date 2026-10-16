from pathlib import Path
from PIL import Image
import json,hashlib,shutil,os
D=Path('nobunaga_final_approved');inv=json.load(open(D/'inventory.json'));assets={};aliases={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def copy(src,dst):
 src=Path(src);dst.parent.mkdir(parents=True,exist_ok=True)
 if not dst.exists():
  try:os.link(src,dst)
  except OSError:shutil.copy2(src,dst)
 return {'path':str(dst.relative_to(D)),'sha256':sha(dst),'bytes':dst.stat().st_size}
for c in inv['clips']:
 k=c['key'];assets[k]={'preview':copy(c['approved_preview']['gif_path'],D/k/'preview-approved.gif')}
 rev=Path(c['approved_preview']['review_directory'])
 fs=sorted(rev.glob('*.png'))
 if len(fs)!=c['approved_preview']['frames']:raise RuntimeError((k,len(fs)))
 assets[k]['approved_review_frames']=[copy(p,D/k/'frames-approved-review'/f'{i:03}.png') for i,p in enumerate(fs)]
 if k=='throw_reverse':
  src=Path(c['selected_root']);assets[k]['native_masters']=[copy(src/'frames-native'/f'{i:03}.png',D/k/'frames-composite'/f'{i:03}.png') for i in range(16)]
  copy(src/'frame-manifest.json',D/k/'approved-source-frame-manifest.json')
  copy(src/'site-import-manifest.json',D/k/'approved-site-import-manifest.json')
  copy(src/'nobunaga-reverse-throw-planted-16f-800ms.mp4',D/k/'preview-approved.mp4')
  copy(src/'frame-manifest.json',D/k/'source-approved'/'frame-manifest.json')
  for i in range(16):copy(src/'frames-native'/f'{i:03}.png',D/k/'source-approved'/'frames-native'/f'{i:03}.png')
 srcs=[Path(r['path']) for r in c['original_resolution_sources']]
 sm=D/k/'source-mapping.json'
 if sm.exists():
  for r in json.load(open(sm))['frames']:srcs.extend(Path(p) for p in r['original_sources'])
 for p in srcs:
  if not p.exists():continue
  if p.is_relative_to(D):continue
  h=sha(p);dst=D/'original-source-artifacts'/f'{h}{p.suffix.lower()}';item=copy(p,dst);aliases[str(p)]=item
 rep=c['approved_preview']['frames']//2
 if k=='charge_release':rep=14
 elif k=='throw_reverse':rep=7
 assets[k]['representative']=copy(fs[rep],D/'representatives'/f'{k}.png');assets[k]['representative']['frame']=rep
 print(k,'collected',flush=True)
(D/'packaged-assets.json').write_text(json.dumps(assets,indent=2));(D/'source-aliases.json').write_text(json.dumps(aliases,indent=2))
print('done',len(aliases),'source aliases')
