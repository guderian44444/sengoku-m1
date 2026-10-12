#!/usr/bin/env python3
"""Exact local-garment patch provenance and version-aware protected-asset hashes.

python scripts/oichi_skirt_v26.py --check
Requires Pillow + NumPy. Verification needs no network, Git history, or game state.
"""
from pathlib import Path
import argparse,hashlib,json
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
MANIFEST=ROOT/'game/assets/v26/oichi-skirt.json'
NOTE=' v26: reviewed local skirt and lining patches; alpha, body geometry and all weapon anchors remain unchanged. See ../../v26/oichi-skirt.json.'
def sha(b):return hashlib.sha256(b).hexdigest()
def geometry(r):return {'clips':{k:v['frames'] for k,v in r['clips'].items()},'aliases':r['aliases'],'portrait':r['portrait']}
def annotate_registration(r):
    if not MANIFEST.exists():return r
    m=json.loads(MANIFEST.read_text())
    if NOTE not in r.get('source_notes',''):r['source_notes']=r.get('source_notes','')+NOTE
    r['garment_patch']={'manifest':'res://assets/v26/oichi-skirt.json','method':'generated skirt-only material patches; no full-body replacement','blocked_unchanged_clips':m['blocked_clips'],'conservative_outer_skirt_clips':m.get('conservative_redesign_clips',[]),'existing_leg_pixels_preserved':True}
    return r

def approved_expected_hash(relative,expected):
    """Advance only an exact historical base to its explicitly recorded after hash."""
    if not MANIFEST.exists():return expected
    m=json.loads(MANIFEST.read_text());change=m['approved_overlay'].get(relative)
    if change is None:return expected
    assert expected in [change['before_sha256'],change['after_sha256']],('v26 base is not the protected historical bytes',relative)
    return change['after_sha256']

def verify():
    m=json.loads(MANIFEST.read_text());assert m['blocked_clips']==[] and m['conservative_redesign_clips']==['jump','low_sweep']
    before=json.loads((ROOT/m['registration_before']).read_text());after=json.loads((ROOT/m['registration_after']).read_text());actual=json.loads((ROOT/'game/assets/v22/oichi/registration.json').read_text())
    assert actual==after;assert geometry(before)==geometry(after)
    assert sha(json.dumps(geometry(actual),sort_keys=True).encode())==m['registration_geometry_sha256']
    assert len(actual['clips'])==26 and sum(len(c['frames']) for c in actual['clips'].values())==156
    report=[]
    for clip,item in m['sources'].items():
        assert clip not in m['blocked_clips'];p=ROOT/item['file'];data=p.read_bytes();assert sha(data)==item['after_sha256']
        arr=np.array(Image.open(p).convert('RGBA'));assert sha(arr.tobytes())==item['after_rgba_sha256'];assert sha(arr[:,:,3].tobytes())==item['alpha_sha256']
        maskpath=ROOT/item['diff_mask'];assert sha(maskpath.read_bytes())==item['diff_mask_sha256'];mask=np.array(Image.open(maskpath).convert('L'));assert set(np.unique(mask))<={0,255};mask=mask>0
        patches={}
        for kind in ['before','after']:
            pp=ROOT/item[kind+'_patch'];assert sha(pp.read_bytes())==item[kind+'_patch_sha256'];pa=np.array(Image.open(pp).convert('RGBA'));assert pa.shape==arr.shape and np.array_equal(pa[:,:,3]>0,mask);patches[kind]=pa
        skinpath=ROOT/item['original_skin_mask'];assert sha(skinpath.read_bytes())==item['original_skin_mask_sha256'];skin=np.array(Image.open(skinpath).convert('L'))>0;assert not mask[skin].any(),('Existing leg/skin changed',clip)
        assert np.array_equal(arr[mask,:3],patches['after'][mask,:3]);reconstructed=arr.copy();reconstructed[mask,:3]=patches['before'][mask,:3]
        assert sha(reconstructed.tobytes())==item['before_rgba_sha256'],'Original RGBA cannot be exactly reconstructed'
        assert int(mask.sum())==item['changed_pixels'];assert np.array_equal(np.any(reconstructed[:,:,:3]!=arr[:,:,:3],axis=2),mask)
        frames=actual['clips'][clip]['frames'];changed=[]
        for n,f in enumerate(frames):
            x,y,w,h=f['rect'];region=mask[y:y+h,x:x+w]
            if region.any():changed.append(n+1)
            for key,radius in [('hand',16),('foot',10),('second_hand',12)]:
                if key not in f or (key=='hand' and f.get('weapon_behind',False)) or (key=='foot' and clip=='down' and n in [4,5]):continue
                # Lying down frames 5/6 use a central ground-contact anchor, not a shoe; its coordinates are still fixed by geometry.
                px=x+f[key][0];py=y+f[key][1];yy,xx=np.ogrid[:mask.shape[0],:mask.shape[1]];protected=(xx-px)**2+(yy-py)**2<=radius**2
                assert not mask[protected].any(),(clip,n+1,key,'anchor pixels changed')
        assert changed==item['modified_frames'];assert actual['clips'][clip]['source_sha256']==item['after_sha256']
        report.append({'clip':clip,'frames':changed,'changed_pixels':int(mask.sum()),'alpha_exact':True,'outside_mask_exact':True,'baseline_rgba_reconstructed':True})
    for clip,c in actual['clips'].items():
        if clip in m['sources']:continue
        fn=c['frames'][0]['file'];assert sha((ROOT/'game/assets/v22/oichi'/fn).read_bytes())==before['clips'][clip]['source_sha256'],('Retained source changed',clip)
    for rel,pair in m['approved_overlay'].items():assert sha((ROOT/rel).read_bytes())==pair['after_sha256']
    for rel,h in m['protected_assets_sha256'].items():assert sha((ROOT/rel).read_bytes())==h,('Unrelated asset changed',rel)
    from collections import Counter
    counts=Counter(f['status'] for f in m['frame_audit']);assert sum(counts.values())==156
    assert all(counts[k]==v for k,v in m['audit_summary'].items() if k not in ['inspected_frames','clips'])
    for f in m['frame_audit']:
        if f['clip'] in m['blocked_clips']:assert f['status']=='retained_generation_blocked' and f['changed_pixels']==0
    assert counts['modified']==sum(len(c['modified_frames']) for c in m['sources'].values())
    out={'status':'PASS','scope':'26 clips / 156 inspected frames','counts':dict(counts),'modified_sheets':len(m['sources']),'protected_other_assets':len(m['protected_assets_sha256']),'checks':report,'limitations':m['limitations']}
    dest=ROOT/'artifacts/oichi-skirt-v26';dest.mkdir(parents=True,exist_ok=True);(dest/'pixel-validation.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n');print(json.dumps(out,ensure_ascii=False,indent=2))
    return out
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--check',action='store_true');args=ap.parse_args();assert args.check,'Use --check';verify()
