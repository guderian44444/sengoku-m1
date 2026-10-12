#!/usr/bin/env python3
"""Pixel-exact invariants for the v25 armor-only overlay, not a visual substitute."""
from pathlib import Path
import json,hashlib,sys,io
import numpy as np
from PIL import Image,ImageDraw,ImageChops
import nobunaga_dark_red_v25 as N
from oichi_skirt_v26 import approved_expected_hash,asset_path
from hero_palette_v23 import hsv
ROOT=N.ROOT;M=json.loads(N.MANIFEST.read_text());O=ROOT/'artifacts/nobunaga-dark-red-v25';reg=json.loads((N.ASSET/'registration.json').read_text());rows=[]
assert len(reg['clips'])==25 and sum(len(c['frames']) for c in reg['clips'].values())==150
assert len(json.loads((ROOT/'game/assets/v22/weapons/registration.json').read_text())['items'])==48
mask_checks=0;mask_overlap={}
for annotations in ['cape-exclusion-polygons.json','chest-adjustment-polygons.json']:
 spec=json.loads((ROOT/'game/assets/v25'/annotations).read_text())
 for clip,item in spec['clips'].items():
  generated=Image.new('L',tuple(spec['sheet_size']))
  for f in item['frames']:
   tile=Image.new('L',generated.size);draw=ImageDraw.Draw(tile)
   for poly in f['source_sheet_polygons']:draw.polygon([tuple(q) for q in poly],fill=255)
   for poly in f['source_sheet_exclude_polygons']:draw.polygon([tuple(q) for q in poly],fill=0)
   if f['constrain_to_runtime_frame']:
    x,y,w,h=f['runtime_rect'];bound=Image.new('L',generated.size);ImageDraw.Draw(bound).rectangle((x,y,x+w-1,y+h-1),fill=255)
    if f.get('runtime_clip_polygon'):
     cp=Image.new('L',generated.size);ImageDraw.Draw(cp).polygon([(x+px,y+py) for px,py in f['runtime_clip_polygon']],fill=255);bound=ImageChops.multiply(bound,cp)
    tile=ImageChops.multiply(tile,bound)
   generated=ImageChops.lighter(generated,tile)
  if item.get('subtract_cape_mask'):generated=ImageChops.subtract(generated,Image.open(ROOT/item['subtract_cape_mask']).convert('L'))
  actual=Image.open(ROOT/item['mask_file']).convert('L');assert generated.tobytes()==actual.tobytes(),('Polygon reproduction',clip);assert N.sha((ROOT/item['mask_file']).read_bytes())==item['mask_sha256'];mask_checks+=1
  if annotations.startswith('chest'):
   cape=np.array(Image.open(ROOT/M['clips'][clip]['cape_mask']).convert('L'));mask_overlap[clip]=int(((np.array(actual)>0)&(cape>0)).sum())
verified_protected=0
for p,digest in M['protected_sha256'].items():
 if '--assets-only' in sys.argv and not asset_path(p):continue
 assert N.sha((ROOT/p).read_bytes())==approved_expected_hash(p,digest),p
 verified_protected+=1
assert N.sha(json.dumps(N.geometry(reg),sort_keys=True).encode())==M['geometry_sha256']
for clip,c in reg['clips'].items():
 b=np.array(Image.open(N.ASSET/(clip+'.png')).convert('RGBA'));digest=N.sha((N.ASSET/(clip+'.png')).read_bytes());assert digest==c['source_sha256']
 if clip in M['unchanged_clips']:
  assert digest==M['unchanged_clips'][clip];rows.append({'clip':clip,'unchanged_bytes':True,'frames':6});continue
 item=M['clips'][clip];original=N.before_bytes(clip,item,O/'before');a=np.array(Image.open(io.BytesIO(original)).convert('RGBA'));mask=np.array(Image.open(ROOT/item['cape_mask']).convert('L'));chest=np.array(Image.open(ROOT/item['chest_mask']).convert('L')) if 'chest_mask' in item else None;reproduced,weight,gain=N.correct_rgba(a,c['frames'],mask,item['parameters'],chest)
 assert np.array_equal(b,reproduced);assert digest==item['after_sha256'];assert np.array_equal(a[...,3],b[...,3]);assert np.array_equal(a[mask==255],b[mask==255]);assert np.array_equal(a[a[...,3]==0],b[a[...,3]==0])
 hh,s,v=hsv(a).transpose(2,0,1);gold=((hh>.075)&(hh<.19)&(s>.25)&(a[...,3]>0));skin=((hh>.055)&(hh<.15)&(s<.65)&(v>.35)&(a[...,3]>0));assert np.array_equal(a[gold],b[gold]);assert np.array_equal(a[skin],b[skin]);assert np.array_equal(a[weight==0],b[weight==0])
 changed=np.any(a[...,:3]!=b[...,:3],axis=2);assert changed.sum()==item['changed_rgb_pixels'];assert not np.any(b[...,:3]>a[...,:3]);rows.append({'clip':clip,'frames':6,'changed_rgb_pixels':int(changed.sum()),'alpha_equal':True,'cape_mask_pixels_equal':True,'gold_class_pixels_equal':True,'skin_class_pixels_equal':True,'outside_red_material_equal':True,'parameters':item['parameters']})
report={'status':'PASS','scope':'25 clips /150 frames;17 corrected sheets,8 exact unchanged','protected_files':verified_protected,'code_snapshot_checked':'--assets-only' not in sys.argv,'weapons':48,'polygon_masks_reproduced':mask_checks,'chest_cape_geometric_intersections':mask_overlap,'cape_intersection_actual_changed_pixels':0,'note':'Cape exclusion takes priority even when annotation polygons intersect. Color-class checks and polygons supplement independent whole-frame visual review, not semantic ground truth. Poses, hands, alpha, other heroes and48 weapons stay unchanged.','clips':rows}
O.mkdir(parents=True,exist_ok=True);(O/'pixel-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(f'PASS v25:150 frames,{verified_protected} protected files,48 weapons;alpha/cape/skin/gold/geometry exact')
