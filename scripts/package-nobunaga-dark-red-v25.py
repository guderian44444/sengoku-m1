#!/usr/bin/env python3
"""Small reproducible RGB-only overlay; intentionally excludes large sprite PNGs."""
from pathlib import Path
import zipfile,json,hashlib
from PIL import Image
R=Path(__file__).resolve().parents[1];O=R/'artifacts/nobunaga-dark-red-v25';D=O/'delivery';D.mkdir(exist_ok=True)
files=[R/'scripts'/s for s in ['nobunaga_dark_red_v25.py','hero_palette_v23.py','preview-nobunaga-dark-red-v25.py','register-nobunaga-v22.py','test-nobunaga-dark-red-v25.py','test-weapon-art-v24.py','package-nobunaga-dark-red-v25.py']]+list((R/'game/assets/v25').rglob('*'))
with zipfile.ZipFile(D/'nobunaga-dark-red-tools-v25.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in files:
  if p.is_file():z.write(p,p.relative_to(R))
 for s in ['README-V25-DARK-RED.txt','VALIDATION.txt','pixel-validation.json','preview-source-audit.json','clean-reproduction.log','registration-test.log','registration-rebuild.log']:
  z.write(O/s,s)
with zipfile.ZipFile(D/'nobunaga-all-150-frame-review-v25.zip','w',zipfile.ZIP_DEFLATED,compresslevel=9) as z:
 for p in sorted(O.glob('nobunaga-dark-all-frames-*.png')):
  j=D/(p.stem+'.jpg');Image.open(p).save(j,quality=94,subsampling=0);z.write(j,j.name)
 z.write(O/'nobunaga-dark-red-before-after.png','all25-before-after.png')
 for p in ['audit/final-anatomical-measurements.json','audit/idle-six-frame-reference.json','pixel-validation.json','VALIDATION.txt']:
  if (O/p).exists():z.write(O/p,Path(p).name)
manifest=[]
for p in [O/'nobunaga-dark-red-focus.png',O/'nobunaga-dark-red-all-25-actions.mp4',D/'nobunaga-dark-red-tools-v25.zip',D/'nobunaga-all-150-frame-review-v25.zip']:
 assert p.stat().st_size<15_000_000,(p,p.stat().st_size)
 manifest.append({'file':p.name,'bytes':p.stat().st_size,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(D/'delivery-hashes.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps(manifest,indent=2))
