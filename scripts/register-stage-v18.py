"""Register untouched imagegen sources; extraction happens in Godot, not in a repainted atlas."""
import hashlib
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / 'game/assets/v18'
PROPS = ['jar', 'basket', 'crate', 'large_crate', 'cart', 'stall', 'barricade', 'fence', 'stone_lantern', 'planter', 'rice_bales', 'lantern']
HEIGHTS = [72, 55, 78, 102, 120, 185, 112, 112, 118, 88, 92, 140]

def register(file, names, cols, rows, row_edges=None):
    image = Image.open(ART / file).convert('RGBA')
    alpha = np.asarray(image)[:, :, 3]
    w, h = image.size
    assert (alpha == 0).mean() > .3, f'{file}: actual transparent alpha required'
    edges = row_edges or [round(i*h/rows) for i in range(rows+1)]
    frames = {}
    for i, name in enumerate(names):
        left, right = round(i%cols*w/cols), round((i%cols+1)*w/cols)
        top, bottom = edges[i//cols:i//cols+2]
        ys, xs = np.where(alpha[top:bottom, left:right] > 128)
        assert len(xs) > 3000
        x0, x1 = max(left, left+int(xs.min())-4), min(right, left+int(xs.max())+5)
        y0, y1 = max(top, top+int(ys.min())-4), min(bottom, top+int(ys.max())+5)
        assert x0 > left and x1 < right and y0 > top and y1 < bottom, f'{name}: unsafe cell boundary'
        frames[name] = {'source':file, 'region':[x0,y0,x1-x0,y1-y0], 'anchor':[(x1-x0)*.5,y1-y0-4], 'body_height':y1-y0-8}
    return frames

data = {'version':'0.18', 'generator':'built-in image_gen.imagegen', 'extraction':'RGBA source pixels are retained; independent padded textures prevent adjacent-cell filtering.', 'props':register('props.png',PROPS,4,3,[0,370,698,1086]), 'food':register('food-source.png',['rice','fish','dango','peach'],2,2), 'debris':register('debris.png',['ceramic','wood','bamboo','wicker'],2,2), 'backgrounds':{}, 'sources':{}}
data['flags'] = register('imagawa-flag.png',['0','1','2','3'],2,2)
for index, frame in enumerate(data['flags'].values()):
    # Keep the pole planted while the cloth silhouette changes between drawings.
    alpha = np.asarray(Image.open(ART / 'imagawa-flag.png'))[:, :, 3]
    x, y, w, h = frame['region']
    ys, xs = np.where(alpha[y+h-24:y+h,x:x+w] > 128)
    frame['anchor'][0] = float(np.median(xs))
for name, height in zip(PROPS,HEIGHTS): data['props'][name]['display_height'] = height
for name in data['food']: data['food'][name]['display_height'] = 50 if name != 'fish' else 46
for name, horizon in {'bamboo':.595,'ridge':.515,'village':.545,'fort':.565,'camp':.535,'chamber':.475}.items():
    data['backgrounds'][name] = {'source':name+'.png','horizon':horizon}
for path in sorted(ART.glob('*.png')):
    with Image.open(path) as im:
        data['sources'][path.name] = {'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'size':list(im.size),'mode':im.mode}
(ART / 'registration.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS: 12 props, 4 foods, 4 debris, 4 flag drawings, 6 landscapes registered with isolated bounds and source hashes')
