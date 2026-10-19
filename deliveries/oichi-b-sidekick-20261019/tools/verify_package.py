"""Read-only checks: python verify_package.py [package-directory]. Requires Pillow."""
from pathlib import Path
import hashlib,json,sys,math
from PIL import Image

base=Path(sys.argv[1]).resolve() if len(sys.argv)>1 else Path(__file__).resolve().parents[1]
errors=[];count=0
for line in (base/'SHA256SUMS.txt').read_text('utf-8').splitlines():
    digest,name=line.split('  ',1);p=base/name;count+=1
    if not p.is_file() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:errors.append(name)
restoration=json.loads((base/'alignment/restore-original-pixels.json').read_text('utf-8'))
clip=json.loads((base/'ready-assets/light_3.candidate.json').read_text('utf-8'))
atlas=Image.open(base/'ready-assets/body-atlas.png').convert('RGBA')
for r in restoration:
    original=Image.open(base/r['original_file']).convert('RGBA')
    aligned=Image.open(base/r['aligned_file']).convert('RGBA')
    x,y,w,h=r['restore_crop_xywh']
    if aligned.crop((x,y,x+w,y+h)).tobytes()!=original.tobytes():errors.append('aligned round trip '+str(r['pose']))
    frame=next(f for f in clip['frames'] if f['approved_pose']==r['pose'])
    x,y,w,h=frame['layers']['body']['rect']
    if atlas.crop((x,y,x+w,y+h)).tobytes()!=original.tobytes():errors.append('atlas round trip '+str(r['pose']))
if (base/'ready-assets/light_3.approved-scale.json').exists():
    approved=json.loads((base/'ready-assets/light_3.approved-scale.json').read_text('utf-8'))
    corrections=json.loads((base/'alignment/calibrated-anchors.json').read_text('utf-8'))
    for i,(old,new) in enumerate(zip(approved['frames'],clip['frames'])):
        r=corrections[new['approved_pose']]
        if old['duration_ms']!=new['duration_ms'] or old['root_step']!=new['root_step']:errors.append('clock/root motion '+str(i))
        if not (new['authored_weapon'] and new['fixed_weapon'] and not new['nocked']):errors.append('bow/arrow flags '+str(i))
        if 'fx_back' in old['layers']:
            a,b=old['layers']['fx_back'],new['layers']['fx_back']
            ratio=296/380
            for axis in [0,1]:
                expected=a['anchor'][axis]+r['anchor_delta_px'][axis]*ratio
                if not math.isclose(b['anchor'][axis],expected,abs_tol=1e-9):errors.append('FX anchor '+str(i))
            if not math.isclose(b['body_height'],new['layers']['body']['body_height']*ratio,abs_tol=1e-9):errors.append('FX scale '+str(i))
    if not math.isclose(sum(f['duration_ms'] for f in clip['frames']),970,abs_tol=1e-6):errors.append('duration')
print(json.dumps({'checked_files':count,'restored_poses':len(restoration),'errors':errors},indent=2))
raise SystemExit(1 if errors else 0)
