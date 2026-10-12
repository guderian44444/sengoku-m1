#!/usr/bin/env python3
"""Armor-only dark-red adjustment on the approved 48-weapon + v23 palette base.
No shape/alpha/pose/hand/weapon edits. Explicit cape masks protect red fabric.
"""
from pathlib import Path
import argparse,hashlib,json,io,subprocess,sys
import numpy as np
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parents[1];ASSET=ROOT/'game/assets/v22/nobunaga';MANIFEST=ROOT/'game/assets/v25/nobunaga-dark-red.json'
def sha(data):return hashlib.sha256(data).hexdigest()
def geometry(reg):return {'clips':{k:c['frames'] for k,c in reg['clips'].items()},'aliases':reg['aliases'],'portrait':reg['portrait']}

def correct_rgba(a,frames,cape,p,chest=None):
    import cv2
    from hero_palette_v23 import hsv
    hsv0=hsv(a);h,s,v=hsv0.transpose(2,0,1);hh=(h+.5)%1-.5
    red=np.clip((.055-abs(hh))/.022,0,1)*np.clip((s-.45)/.18,0,1)*np.clip((v-.06)/.10,0,1)*(a[...,3]>0)
    # The semantic cape boundary is traced in source pixels, never inferred by
    # flood-filling red: cloth and armor often share a connected red component.
    red*=1-cape.astype(np.float64)/255
    weight=np.zeros(a.shape[:2],np.float64);gainfield=np.ones(a.shape[:2],np.float64)
    for f in frames:
        x,y,w,hgt=f['rect'];local=red[y:y+hgt,x:x+w].copy()
        visible=Image.new('L',(w,hgt),255)
        if 'clip_polygon' in f:
            visible=Image.new('L',(w,hgt));ImageDraw.Draw(visible).polygon([tuple(q) for q in f['clip_polygon']],fill=255)
        local*=np.asarray(visible)/255
        # Ignore tiny isolated red ornaments / lip pixels; do not recolor a hair tie.
        n,labels,stats,centres=cv2.connectedComponentsWithStats((local>.08).astype('uint8'),8)
        eligible=np.zeros(local.shape,bool)
        for i in range(1,n):
            if stats[i,4]>=250:eligible|=labels==i
        local*=eligible
        gain=np.full(local.shape,float(p['armor_gain']))
        # Red lower-leg plate components, separated from cloth by the explicit
        # mask. The extra is deliberately mild and disabled for bent-air poses.
        opacity=a[y:y+hgt,x:x+w,3]>160;ys=np.where(opacity)[0]
        low_line=float(ys.min()+.70*(ys.max()-ys.min())) if len(ys) else hgt
        if p['shin_extra']<1:
            for i in range(1,n):
                if stats[i,4]>=250 and centres[i,1]>low_line:
                    gain[labels==i]*=p['shin_extra']
        # Preserve the brighter but still dark-red wrist lacquer/glints near
        # registered hands, rather than forcing every armor part equally dark.
        yy,xx=np.indices(local.shape);hx,hy=f['hand'];r=np.hypot(xx-hx,yy-hy)
        radius=float(f['body_height'])*.17
        wrist=np.clip((radius-r)/(radius*.60),0,1)
        gain=gain+(np.maximum(gain,p['wrist_min_gain'])-gain)*wrist
        target=weight[y:y+hgt,x:x+w];gdst=gainfield[y:y+hgt,x:x+w]
        update=local>target;gdst[update]=gain[update];target[update]=local[update]
    if chest is not None:
        # A few exposed torso plates remain brighter than the idle reference.
        # Their separate traced regions receive a mild feathered adjustment;
        # dark shins, wrists, cape and neighboring armor are not dragged down.
        # Feather inward only, never into neighboring arms/cape/waist plates.
        soft=np.clip(cv2.distanceTransform((chest>0).astype('uint8'),cv2.DIST_L2,3)/3.,0,1)
        gainfield*=1-(1-float(p['chest_extra']))*soft
    factor=1-weight*(1-gainfield)
    out=a.copy();out[...,:3]=np.rint(a[...,:3].astype(np.float64)*factor[...,None]).clip(0,255).astype('uint8')
    assert np.array_equal(out[...,3],a[...,3])
    return out,weight,gainfield

def add_registration_note(reg):
    if not MANIFEST.exists():return reg
    m=json.loads(MANIFEST.read_text());reg['dark_red_armor']={'manifest':'../../v25/nobunaga-dark-red.json','reference':'idle.png unchanged dark-red armor','method':'Armor-only value adjustment; explicit cape protection; measured chest/shoulder/skirt/wrist/shin references','unchanged_clips':m['unchanged_clips']}
    return reg

def before_bytes(clip,item,backup):
    p=backup/(clip+'.png')
    if p.exists():data=p.read_bytes()
    elif sha((ASSET/(clip+'.png')).read_bytes())==item['before_sha256']:data=(ASSET/(clip+'.png')).read_bytes()
    else:
        # Deterministic reconstruction of the preceding v23 stage, if a local
        # pre-v25 backup is absent. The reviewed Git source is not modified.
        import hero_palette_v23 as old
        raw=subprocess.check_output(['git','show','2ac0688a8100b27b3a4fa958554aee8dcd3a1188:game/assets/v22/nobunaga/'+clip+'.png'],cwd=ROOT)
        prior=json.loads((ROOT/'game/assets/v22/color-consistency.json').read_text())['corrections']['nobunaga/'+clip+'.png']
        a=np.array(Image.open(io.BytesIO(raw)).convert('RGBA'));b=old.grade(a,prior['materials']);buf=io.BytesIO();Image.fromarray(b).save(buf,format='PNG');data=buf.getvalue()
    assert sha(data)==item['before_sha256'],('Wrong prior palette source',clip)
    return data

def main():
    p=argparse.ArgumentParser();p.add_argument('--apply',action='store_true');p.add_argument('--check',action='store_true');p.add_argument('--backup-dir',type=Path,default=ROOT/'artifacts/nobunaga-dark-red-v25/before');args=p.parse_args();assert args.apply!=args.check
    m=json.loads(MANIFEST.read_text());regpath=ASSET/'registration.json';reg=json.loads(regpath.read_text());assert sha(json.dumps(geometry(reg),sort_keys=True).encode())==m['geometry_sha256']
    regpair=m['approved_overlay']['game/assets/v22/nobunaga/registration.json']
    assert sha(regpath.read_bytes()) in regpair.values(),'Unrecognized Nobunaga registration'
    if args.check:assert sha(regpath.read_bytes())==regpair['after_sha256']
    # Protect the finalized 48 weapons, both other heroes, core/render code and
    # game test sources. A mismatching base stops before any pixel is written.
    for rel,digest in m['protected_sha256'].items():assert sha((ROOT/rel).read_bytes())==digest,('Protected file differs',rel)
    for clip,digest in m['unchanged_clips'].items():assert sha((ASSET/(clip+'.png')).read_bytes())==digest
    planned=[]
    for clip,item in m['clips'].items():
        path=ASSET/(clip+'.png');current=path.read_bytes();assert sha(current) in [item['before_sha256'],item['after_sha256']],('Unrecognized source',clip)
        original=before_bytes(clip,item,args.backup_dir);a=np.array(Image.open(io.BytesIO(original)).convert('RGBA'))
        maskpath=ROOT/item['cape_mask'];assert sha(maskpath.read_bytes())==item['cape_mask_sha256'];mask=np.array(Image.open(maskpath).convert('L'))
        chest=None
        if 'chest_mask' in item:
            cp=ROOT/item['chest_mask'];assert sha(cp.read_bytes())==item['chest_mask_sha256'];chest=np.array(Image.open(cp).convert('L'))
        b,_,_=correct_rgba(a,reg['clips'][clip]['frames'],mask,item['parameters'],chest);buf=io.BytesIO();Image.fromarray(b).save(buf,format='PNG');encoded=buf.getvalue();assert sha(encoded)==item['after_sha256'],('Not reproducible',clip)
        assert sha(a[...,3].tobytes())==item['alpha_sha256'];planned.append((clip,path,original,encoded))
        if args.check:assert current==encoded,(clip,'Current sprite not the reviewed dark version')
    # Only write once every preflight and every reconstruction has passed.
    if args.apply:
        args.backup_dir.mkdir(parents=True,exist_ok=True)
        backupreg=args.backup_dir/'registration.json'
        if not backupreg.exists():backupreg.write_bytes((ASSET/'registration.json').read_bytes())
        for clip,path,original,encoded in planned:
            b=args.backup_dir/path.name
            if not b.exists():b.write_bytes(original)
            if path.read_bytes()!=encoded:path.write_bytes(encoded)
            reg['clips'][clip]['source_sha256']=sha(encoded)
        add_registration_note(reg);(ASSET/'registration.json').write_text(json.dumps(reg,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(f'PASS v25 dark red: {len(planned)} sheets reproducible; 25 clips /150 frames geometry+alpha protected; idle/7 other dark clips and 48 weapons unchanged')
if __name__=='__main__':main()
