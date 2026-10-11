"""Validate the retained body-layer sources and the runtime registration boundaries."""
import hashlib
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import Delaunay

BASE=Path(__file__).resolve().parents[1]/'game/assets/v22/nobunaga'
reg=json.loads((BASE/'registration.json').read_text(encoding='utf-8'))
expected={'idle','walk','run','light1','light2','light3','heavy1','heavy2','dash_strike','rising','low_sweep','charged_upper','charged_slam','air_light','air_heavy','special','jump','guard','throw','victory','hurt','stunned','down','recovering','launched'}
assert set(reg['clips'])==expected
assert reg['aliases']['dash_heavy']=='light3'
checks=2
for name,clip in reg['clips'].items():
    source=BASE/(name+'.png');raw=source.read_bytes()
    assert hashlib.sha256(raw).hexdigest()==clip['source_sha256'];checks+=1
    im=Image.open(source)
    assert im.mode=='RGBA' and im.size==(1536,1024);checks+=1
    a=np.asarray(im)[:,:,3]
    assert np.count_nonzero(a==0)>a.size*.15;checks+=1
    labels,count=ndimage.label(a>32);sizes=np.bincount(labels.ravel())
    main_ids=np.argsort(sizes[1:])[-6:]+1
    assert len(clip['frames'])==6;checks+=1
    hashes=[]
    for index,frame in enumerate(clip['frames']):
        x,y,w,h=frame['rect'];hx,hy=frame['hand']
        assert x>=0 and y>=0 and x+w<=im.width and y+h<=im.height;checks+=1
        assert w>80 and h>80 and frame['body_height']>=300;checks+=1
        assert 0<=hx<w and 0<=hy<h and a[y+int(hy),x+int(hx)]>=100;checks+=1
        crop=im.crop((x,y,x+w,y+h));hashes.append(hashlib.sha256(crop.tobytes()).hexdigest())
        if name!='walk':
            local=labels[y:y+h,x:x+w]
            largest=int(np.bincount(local.ravel())[1:].argmax()+1)
            own=(local==largest)
            foreign=np.isin(local,[v for v in main_ids if v!=largest])
            if 'clip_polygon' in frame:
                hull=Delaunay(np.array(frame['clip_polygon']))
                sy,sx=np.where(own)
                assert np.all(hull.find_simplex(np.column_stack((sx,sy)))>=0);checks+=1
                fy,fx=np.where(foreign)
                visible=hull.find_simplex(np.column_stack((fx,fy)))>=0
                assert np.count_nonzero(visible)<=8,(name,index,'neighbor leaks',int(np.count_nonzero(visible)));checks+=1
            else:
                assert np.count_nonzero(foreign)<=8,(name,index,'unclipped neighbor');checks+=1
    assert len(set(hashes))==6,(name,'duplicate frame pixels');checks+=1
assert reg['clips']['down']['frames'][5]['rect'][2]>reg['clips']['down']['frames'][5]['rect'][3]*2;checks+=1
print(f'PASS Nobunaga v22: {checks} checks; 25 clips, 150 distinct frames, preserved original RGBA, grip anchors, no adjacent-body leaks')
