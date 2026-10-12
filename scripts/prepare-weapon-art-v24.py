#!/usr/bin/env python3
"""Reproducible alpha-only cleanup of 30 original imagegen source images.

RGB values, silhouette core, dimensions and artistic details are not repainted.
Raw originals stay separate. The isolated largest solid object is expanded by
two pixels to retain antialiased edges; alpha below 16 or away from that object
is removed. This deliberately does NOT claim raw-alpha identity for v24.
"""
from pathlib import Path
import json, hashlib, subprocess, sys
from scipy import ndimage
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/'game/assets/v24/weapons'
OUT=ROOT/'game/assets/v22/weapons'

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def prepare(raw):
 pixels=np.array(Image.open(raw).convert('RGBA'))
 alpha=pixels[:,:,3]
 core=(alpha>=192).astype('uint8')
 labels,count=ndimage.label(core,np.ones((3,3),dtype=bool))
 assert count>0, str(raw)+': no solid pixels'
 label=1+int(np.argmax(np.bincount(labels.ravel())[1:]))
 main=labels==label
 assert np.count_nonzero(main)>np.count_nonzero(core)*.98, str(raw)+': disconnected solid object; review before processing'
 near=ndimage.binary_dilation(main,structure=np.ones((5,5),dtype=bool))
 newalpha=np.where(near & (alpha>=16),alpha,0).astype('uint8')
 result=pixels.copy();result[:,:,3]=newalpha
 assert np.array_equal(result[:,:,:3],pixels[:,:,:3])
 return Image.fromarray(result),{'method':'largest alpha>=192 component + 2px edge margin; alpha<16 and remote halo removed','raw_sha256':sha(raw),'removed_alpha_pixels':int(np.count_nonzero(alpha!=newalpha)),'rgb_unchanged':True,'opaque_core_unchanged':bool(np.all(newalpha[main]==alpha[main])),'raw_size':list(Image.open(raw).size)}

def main():
 specs=json.loads((DATA/'art-spec30.json').read_text())
 added=json.loads((OUT/'expansion-registration-spec.json').read_text())
 report=[]
 for spec in specs['items']:
  id=spec['id'];raw=ROOT/spec['raw_source']
  image,audit=prepare(raw)
  path=OUT/'sources'/f'{id}-generated.png'
  image.save(path)
  audit.update({'id':id,'prepared_sha256':sha(path),'prepared_source':str(path.relative_to(ROOT))})
  report.append(audit)
  added[id]={'source':'sources/'+path.name,'grip_y':spec['grip_y'],'world_length':spec['world_length'],'proportions_cm':spec.get('proportions_cm',{}),'scale_note':spec['scale_note'],'raw_source':spec['raw_source'],'alpha_processing':audit['method'],'visual_differences':spec['visual_differences']}
 (OUT/'expansion-registration-spec.json').write_text(json.dumps(added,ensure_ascii=False,indent=2)+'\n')
 (DATA/'alpha-processing.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
 subprocess.run([sys.executable,str(ROOT/'scripts/register-weapons-v22.py')],check=True)
 print(f'Prepared {len(report)} new weapons; RGB unmodified, raw originals retained')

if __name__=='__main__': main()
