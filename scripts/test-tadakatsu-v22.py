"""Verify source integrity, all actions, grip placement and isolation from neighboring sprites."""
from pathlib import Path
import json, hashlib
import cv2
import numpy as np
from PIL import Image

BASE=Path(__file__).resolve().parents[1]/'game/assets/v22/tadakatsu'
reg=json.loads((BASE/'registration.json').read_text(encoding='utf-8'))
required={'idle','walk','run','jump','light1','light2','light3','heavy1','heavy2','slam_charge','charged_slam','charge_forward','dash','upper','low_sweep','air_light','air_heavy','hurt','guard','death','recover','holding','throw','launched','special','victory'}
assert set(reg['clips'])==required
checks=1
for source in reg['sources']:
 path=BASE/source['file']; image=Image.open(path)
 assert hashlib.sha256(path.read_bytes()).hexdigest()==source['sha256']
 assert image.mode=='RGBA' and image.size==(1536,1024)
 alpha=np.array(image)[:,:,3]
 assert not any((edge>100).any() for edge in [alpha[0,:],alpha[-1,:],alpha[:,0],alpha[:,-1]]),(path.name,'body clipped by canvas')
 checks+=3
for clip,spec in reg['clips'].items():
 assert len(spec['frames'])==6
 im=np.array(Image.open(BASE/spec['frames'][0]['file']))
 _,labels,stats,centers=cv2.connectedComponentsWithStats((im[:,:,3]>100).astype('uint8'),8)
 ids=[i for i in range(1,len(stats)) if stats[i,4]>7000]
 ids.sort(key=lambda i:(int(centers[i,1]//(im.shape[0]/2)),centers[i,0]))
 assert len(ids)==6
 checks+=2
 for index,frame in enumerate(spec['frames']):
  x,y,w,h=frame['rect'];hx,hy=frame['hand']
  assert 0<=x<x+w<=im.shape[1] and 0<=y<y+h<=im.shape[0]
  assert im[y+hy,x+hx,3]>=100,(clip,index,'grip must lie on opaque body')
  assert frame['body_height']>=300
  assert frame['weapon_visible']
  mask=np.zeros(labels.shape,np.uint8)
  poly=np.array(frame['clip_polygon'],np.int32)+[x,y]
  cv2.fillPoly(mask,[poly.astype(np.int32)],1)
  for other in ids:
   if other!=ids[index]: assert not ((labels==other)&(mask>0)).any(),(clip,index,'neighbor visible inside crop polygon')
  checks+=5
assert all(target in reg['clips'] for target in reg['aliases'].values())
assert [i for i,f in enumerate(reg['clips']['charged_slam']['frames']) if f['weapon_grounded']]==[3,4]
for clip in ['walk','run']:
 foot_spreads=[]
 for frame in reg['clips'][clip]['frames']:
  x,y,w,h=frame['rect']; a=np.array(Image.open(BASE/frame['file']))[y:y+h,x:x+w,3]
  yy,xx=np.where(a[-40:,:]>100)
  foot_spreads.append(int(xx.max()-xx.min()))
 assert max(foot_spreads)-min(foot_spreads)>80,(clip,'wide and passing feet must differ')
checks+=4
run_grips=[(f['hand'][0]-f['foot'][0])*155/f['body_height'] for f in reg['clips']['run']['frames']]
assert max(run_grips)-min(run_grips)<4,'running grip must remain horizontally steady while legs alternate'
checks+=1
print(f'PASS Tadakatsu v22 artwork: {checks} checks; 26 clips / 156 poses; no clipped body or neighboring sprite pixels.')
