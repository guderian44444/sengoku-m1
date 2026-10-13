#!/usr/bin/env python3
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
P=Path(__file__).resolve().parent.parent;R=P/'runtime'
if not R.exists():R=P
reg=json.loads((R/'registration.proposed.json').read_text());assert len(reg['clips'])==39;count=0
for n,c in reg['clips'].items():
 assert len(c['frames'])==6
 for f in c['frames']:
  p=R/f['file'];body=np.array(Image.open(p));assert body.shape[2]==4;assert hashlib.sha256(p.read_bytes()).hexdigest()==f['body_sha256'];src=P/'sources'/f['source']['file'];assert hashlib.sha256(src.read_bytes()).hexdigest()==f['source']['sha256']
  for k in ['foot','right_hand','left_hand']:
   x,y=f[k];assert 0<=x<body.shape[1] and 0<=y<body.shape[0],(n,k)
  fg=np.array(Image.open(R/f['hand_foreground_file']));assert fg.shape==body.shape;assert np.all(fg[...,3]<=body[...,3]);m=fg[...,3]>0;assert np.array_equal(fg[...,:3][m],body[...,:3][m]);count+=1
manifest=P/'file-manifest.json'
if manifest.exists():
 for f in json.loads(manifest.read_text())['files']:
  p=P/f['file'];assert p.stat().st_size==f['bytes'];assert hashlib.sha256(p.read_bytes()).hexdigest()==f['sha256'],p
print('Verified39 clips /',count,'frames; sources, hashes, coordinates, foreground and optional file manifest pass.')
