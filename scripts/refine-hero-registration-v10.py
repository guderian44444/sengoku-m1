"""Register full original alpha components; preserve every source PNG byte."""
import json, statistics
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
path = ROOT / 'game/assets/v10/hero-registration.json'
registration = json.loads(path.read_text(encoding='utf-8'))
components = json.loads((ROOT / 'artifacts/art-native-v10/hero-components.json').read_text())
skill_body_heights = {'hideyoshi':181, 'ieyasu':180, 'mitsuhide':190, 'tadakatsu':175}

def overlap(a, b):
    x,y,w,h = a
    X,Y,W,H = b
    return max(0,min(x+w,X+W)-max(x,X))*max(0,min(y+h,Y+H)-max(y,Y))

def runs(values):
    indices = np.flatnonzero(values)
    return np.split(indices,np.where(np.diff(indices)>1)[0]+1) if indices.size else []

for name,spec in registration['actors'].items():
    alpha = np.array(Image.open(ROOT / 'game/assets/v10' / (name+'.png')).getchannel('A'))
    image_height,image_width = alpha.shape
    mask = alpha > 90
    boxes = [c['bounds'] for c in components[name]]
    original = spec.get('measurement_regions',spec['regions'])
    spec['measurement_regions'] = original.copy()
    mapping = [max(range(len(boxes)),key=lambda j:overlap(original[str(i)],boxes[j])) for i in range(spec["columns"] * spec["rows"])]
    joined = []
    hero,sheet = name.split('-')
    # Spacing edits can resize a whole sheet; calibrate neutral standing bodies per atlas.
    body_height = skill_body_heights[hero]
    if sheet == 'combat': body_height = statistics.median(boxes[mapping[i]][3] for i in range(6))
    elif sheet == 'reactions': body_height = boxes[mapping[0]][3]
    elif sheet == 'idle': body_height = {'hideyoshi':218,'ieyasu':253,'mitsuhide':235,'tadakatsu':253}[hero]
    spec['body_height'] = body_height
    if sheet == 'reactions': spec['unplanted'] = list(range(12,24)) + list(range(30,36))
    for cell,component in enumerate(mapping):
        row = cell // 6
        peers = [i for i,c in enumerate(mapping) if c == component]
        if len(peers)>1:
            joined.append(cell)
            x,y,w,h = original[str(cell)]
        else:
            x,y,w,h = [int(v) for v in boxes[component]]
            end_x,end_y = min(image_width,x+w+2),min(image_height,y+h+2)
            x,y = max(0,x-2),max(0,y-2)
            w,h = end_x-x,end_y-y
        spec['regions'][str(cell)] = [x,y,w,h]
        crop = mask[y:y+h,x:x+w]
        ys,xs = np.nonzero(crop)
        if len(xs)==0: raise ValueError((name,cell,'empty region'))
        center_x,center_y = x+float(xs.mean()),y+float(ys.mean())
        support_y = int(ys.max())
        sole = None
        for line_y in range(support_y,max(-1,support_y-25),-1):
            solid = crop[max(0,line_y-4):line_y+1].sum(axis=0) >= 4
            candidates = [r for r in runs(solid) if len(r)>=8]
            if candidates:
                sole = min(candidates,key=lambda r:r[0])
                support_y = line_y
                break
        support_x = x+float(np.median(sole)) if sole is not None else center_x
        support_y += y
        if (sheet=='reactions' and row==2) or (sheet=='skills' and row==4):
            support_x,support_y = center_x,center_y+body_height*0.44
        elif sheet=='reactions' and row in [3,5]:
            support_x = center_x
        elif sheet=='combat' and row==0:
            support_x = center_x - body_height * 0.32
        spec['feet'][cell] = [round(support_x,2),round(support_y,2)]
    print(name,'body',spec['body_height'],'awaiting source separation',joined)
registration['measurement'] = 'Full alpha component bounds, measured rear soles, per-sheet standing body calibration, body-centred airborne and recovery pivots. Source PNGs unchanged.'
for target in [path,ROOT/'assets/animation-v0.10/hero-registration.json']:
    target.write_text(json.dumps(registration,ensure_ascii=False,indent=2),encoding='utf-8')
