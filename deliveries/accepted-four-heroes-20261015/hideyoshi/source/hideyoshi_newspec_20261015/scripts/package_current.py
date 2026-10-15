from pathlib import Path
import json,zipfile,hashlib
from PIL import Image
P=Path(__file__).resolve().parents[1];root=P.parent
m=json.loads((P/'review_manifest.json').read_text())
assert len(m['actions'])==16,len(m['actions'])
files=set()
for a in m['actions']:
 for k in ['gif','representative','contact','metadata']:assert (root/a[k]).exists(),(a['id'],k)
 files.update((root/a['metadata']).parent.rglob('*'))
for d in ['reference','scripts','grabs/sources']:
 files.update((P/d).rglob('*'))
for a in ['grab_start','grab_hold','grab_hit_1','grab_hit_2','throw_forward','throw_reverse']:
 files.update((P/'grabs'/a).rglob('*'))
files.update((P/'actions').glob('*.png'))
for dep in ['light_1_8frame_baseline','light_3_fastlow_v3','charge_release_pivot_v2','charge_release_reach_v3','charge_release_scale_v4','charge_release_headlock_v5','charge_release_sharpfx_v6','charge_release_outburst_v7']:
 files.update((P/'actions'/dep).rglob('*'))
files.update((P/'actions').glob('*landmarks.json'))
files.update((P/'grabs').glob('*.py'))
files.update((P/'grabs').glob('*.json'))
files.update((P/'grabs/normalized').glob('*.json'))
files.update(P.glob('*.md'));files.update(P.glob('*.json'))
files.add(P/'hideyoshi_head95_single_preview.png')
files.update(x for x in (P/'head_identity_fix').glob('*.png') if x.name!='approved_head_turntable.png')
files={x for x in files if x.is_file() and '__pycache__' not in str(x) and x.name not in ['SHA256_current.json','delivery_versions.json'] and 'rejected' not in str(x)  and 'build_90' not in x.name and not x.name.endswith('_old_source.png') and '_old_reverse_' not in x.name}
files={x for x in files if not ('grabs' in x.parts and 'normalized' not in x.parts and x.name.startswith('hideyoshi_'))}
sha={str(x.relative_to(P)):hashlib.sha256(x.read_bytes()).hexdigest() for x in files}
(P/'SHA256_current.json').write_text(json.dumps(sha,indent=2));files.add(P/'SHA256_current.json')
full=P/'hideyoshi_newspec_head95_complete.zip'
with zipfile.ZipFile(full,'w',zipfile.ZIP_DEFLATED,6) as z:
 for f in sorted(files):z.write(f,str(f.relative_to(root)))
review=P/'hideyoshi_newspec_head95_review.zip'
with zipfile.ZipFile(review,'w',zipfile.ZIP_DEFLATED,6) as z:
 for a in m['actions']:
  for k in ['gif','representative','metadata']:
   f=root/a[k];z.write(f,str(f.relative_to(root)))
 for f in [P/'review_manifest.json',P/'HANDOFF.md',P/'MOVE_REVIEW.md']:z.write(f,str(f.relative_to(root)))
assert review.stat().st_size<9_000_000,review.stat().st_size
print(full,full.stat().st_size,review,review.stat().st_size)
