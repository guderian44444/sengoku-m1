#!/usr/bin/env python3
"""Deterministic material-only RGB grades; never regenerate art or change alpha.

python scripts/hero_palette_v23.py --apply --backup-dir artifacts/palette-review/originals
python scripts/hero_palette_v23.py --check --backup-dir artifacts/palette-review/originals

Original source files can also be read directly from the recorded Git base commit.
An apply is idempotent and refuses files with an unknown hash. Backups are written
before any image modification. Pillow + NumPy + OpenCV are required (the same
image packages used by the v22 registration workflow).
"""
from pathlib import Path
import argparse,hashlib,io,json,subprocess
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'game/assets/v22/color-consistency.json'
def sha(b):return hashlib.sha256(b).hexdigest()
def hsv(a):
    import cv2
    v=cv2.cvtColor(a[...,:3].astype(np.float32)/255,cv2.COLOR_RGB2HSV).astype(np.float64)
    v[...,0]/=360
    return v

def masks(a):
    v=hsv(a);h,s,lum=v.transpose(2,0,1);signed=(h+.5)%1-.5
    # Pigment masks deliberately exclude warm skin, whites, neutral black cloth,
    # brown antlers and low-saturation metallic reflections. Smooth feathering
    # avoids a hue-threshold seam; invisible RGB is preserved byte-for-byte.
    red=np.clip((.055-np.abs(signed))/.025,0,1)*np.clip((s-.45)/.2,0,1)*np.clip((lum-.08)/.1,0,1)*(a[...,3]>0)
    gold=np.clip((h-.09)/.018,0,1)*np.clip((.18-h)/.025,0,1)*np.clip((s-.55)/.15,0,1)*np.clip((lum-.18)/.12,0,1)*(a[...,3]>0)
    return v,{'red_lacquer_and_cloth':red,'gold_trim':gold,'red_cloth':red}

def grade(a,params):
    import cv2
    original,weights=masks(a);rgb=a[...,:3].astype(np.float64)
    for material,p in params.items():
        v=original.copy();v[...,0]=(v[...,0]+p['hue_shift'])%1
        v[...,1]=np.clip(v[...,1]*p['saturation_gain'],0,1)
        v[...,2]=np.clip(v[...,2]*p['value_gain'],0,1)
        v[...,0]*=360
        recolored=cv2.cvtColor(v.astype(np.float32),cv2.COLOR_HSV2RGB).astype(np.float64)*255
        w=weights[material][...,None];rgb=rgb*(1-w)+recolored*w
    out=a.copy();out[...,:3]=np.rint(rgb).clip(0,255).astype(np.uint8)
    assert np.array_equal(out[...,3],a[...,3])
    assert np.array_equal(out[a[...,3]==0],a[a[...,3]==0])
    return out

def annotate_registration(data,hero):
    if not MANIFEST.exists():return data
    spec=json.loads(MANIFEST.read_text(encoding='utf-8'))
    if not any(k.startswith(hero+'/') for k in spec['corrections']):return data
    key='source_notes' if 'source_notes' in data else 'notes'
    text=data.get(key,'')
    text=text.replace('Original imagegen RGBA preserved.','Imagegen source geometry and alpha preserved; selected RGB materials color-calibrated in v23.').replace('Source pixels and alpha preserved.','Source geometry and alpha preserved; selected RGB materials color-calibrated in v23.')
    data[key]=text
    data['color_consistency']={'manifest':'../color-consistency.json','method':'material RGB only; original alpha and registration geometry unchanged','reference':spec['references'][hero]}
    return data

def original_bytes(relative,item,spec,backup):
    p=backup/relative
    if p.exists():b=p.read_bytes()
    else:b=subprocess.check_output(['git','show',spec['base_commit']+':game/assets/v22/'+relative],cwd=ROOT)
    assert sha(b)==item['original_sha256'],('Original source hash mismatch',relative)
    return b

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--apply',action='store_true');ap.add_argument('--check',action='store_true');ap.add_argument('--backup-dir',type=Path,default=ROOT/'artifacts/palette-review/originals');args=ap.parse_args()
    assert args.apply != args.check,'Choose exactly --apply or --check'
    spec=json.loads(MANIFEST.read_text(encoding='utf-8'));checks=0
    for rel,item in spec['corrections'].items():
        path=ROOT/'game/assets/v22'/rel;current=path.read_bytes();raw=original_bytes(rel,item,spec,args.backup_dir)
        a=np.array(Image.open(io.BytesIO(raw)).convert('RGBA'));out=grade(a,item['materials'])
        buf=io.BytesIO();Image.fromarray(out).save(buf,format='PNG');encoded=buf.getvalue()
        assert sha(encoded)==item['corrected_sha256'],('Correction not reproducible',rel)
        if args.apply:
            assert sha(current) in [item['original_sha256'],item['corrected_sha256']],('Refusing unexpected image',rel)
            dst=args.backup_dir/rel;dst.parent.mkdir(parents=True,exist_ok=True)
            if not dst.exists():dst.write_bytes(raw)
            if current!=encoded:path.write_bytes(encoded)
        else:assert current==encoded,('Runtime source differs from reviewed output',rel)
        assert sha(a[...,3].tobytes())==item['alpha_sha256']
        checks+=5
    if args.apply:
        for hero in ('nobunaga','oichi'):
            p=ROOT/'game/assets/v22'/hero/'registration.json';reg=json.loads(p.read_text(encoding='utf-8'))
            for c in reg['clips'].values():
                files=set(f['file'] for f in c['frames']);assert len(files)==1
                c['source_sha256']=sha((p.parent/next(iter(files))).read_bytes())
            annotate_registration(reg,hero);p.write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS palette v23: {len(spec["corrections"])} color-only files, {checks} reproduction/alpha/source checks')
if __name__=='__main__':main()
