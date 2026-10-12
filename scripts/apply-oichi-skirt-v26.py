#!/usr/bin/env python3
"""Copy reviewed generated skirt pixels onto exactly matching v25 sources.
Run: python scripts/apply-oichi-skirt-v26.py --apply (or omit --apply to verify).
"""
import argparse,json,io
import numpy as np
from PIL import Image
from oichi_skirt_v26 import ROOT,MANIFEST,sha,verify

def main(apply):
    if not apply:return verify()
    m=json.loads(MANIFEST.read_text());updates=[]
    for clip,item in m['sources'].items():
        p=ROOT/item['file'];current=p.read_bytes();digest=sha(current)
        if digest==item['after_sha256']:continue
        assert digest==item['before_sha256'],('Refusing unreviewed source version',item['file'])
        arr=np.array(Image.open(io.BytesIO(current)).convert('RGBA'));assert sha(arr.tobytes())==item['before_rgba_sha256']
        patchfile=ROOT/item['after_patch'];assert sha(patchfile.read_bytes())==item['after_patch_sha256'];patch=np.array(Image.open(patchfile).convert('RGBA'));mask=patch[:,:,3]>0
        arr[mask,:3]=patch[mask,:3];assert sha(arr.tobytes())==item['after_rgba_sha256']
        buf=io.BytesIO();Image.fromarray(arr).save(buf,format='PNG');data=buf.getvalue();assert sha(data)==item['after_sha256'],'PNG encoder mismatch; reviewed pixels matched but encoding differs'
        updates.append((p,data))
    reg=ROOT/'game/assets/v22/oichi/registration.json';pair=m['approved_overlay']['game/assets/v22/oichi/registration.json'];assert sha(reg.read_bytes()) in [pair['before_sha256'],pair['after_sha256']]
    newreg=(ROOT/m['registration_after']).read_bytes();assert sha(newreg)==pair['after_sha256']
    for path,data in updates:path.write_bytes(data)
    reg.write_bytes(newreg);verify()
if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');main(p.parse_args().apply)
