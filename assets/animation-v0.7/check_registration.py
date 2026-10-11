"""Validate final source rectangles and source/runtime hashes without editing images."""
from pathlib import Path
from PIL import Image
import hashlib, json

root = Path(__file__).parent
runtime = root.parents[1]/'game/assets/v07'
results = []
for hero in ('nobunaga','oichi'):
    metadata = json.loads((root/hero/'registration.json').read_text(encoding='utf-8'))
    assert len(metadata['sheets']) == (5 if hero == 'nobunaga' else 1)
    for sheet,spec in metadata['sheets'].items():
        path = root/hero/(sheet+'.png')
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        assert digest == spec['sha256'] == hashlib.sha256((runtime/hero/path.name).read_bytes()).hexdigest()
        image = Image.open(path).convert('RGBA')
        assert len(spec['feet']) == len(spec['left_support']) == len(spec['right_support']) == 12
        for i in range(12):
            default = [(i%4)*384,i//4*1024//3,384,(i//4+1)*1024//3-i//4*1024//3]
            x,y,w,h = spec.get('regions',{}).get(str(i),default)
            assert x>=0 and y>=0 and x+w<=1536 and y+h<=1024
            border = [image.getpixel((px,y))[3] for px in range(x,x+w)]+[image.getpixel((px,y+h-1))[3] for px in range(x,x+w)]+[image.getpixel((x,py))[3] for py in range(y,y+h)]+[image.getpixel((x+w-1,py))[3] for py in range(y,y+h)]
            clipped = sum(a>=128 for a in border)
            results.append({'hero':hero,'sheet':sheet,'cell':i,'region':[x,y,w,h],'opaque_border_pixels':clipped})
            assert clipped==0, results[-1]
(root/'registration-qa.json').write_text(json.dumps(results,indent=2),encoding='utf-8')
print('PASS: 72 registered cells, no opaque pixels at crop borders; all source/runtime SHA256 match.')
