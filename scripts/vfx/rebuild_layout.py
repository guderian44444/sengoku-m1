"""Reproduce adopted blade/ice layout to NEW output; source art is never rewritten."""
from pathlib import Path
from PIL import Image
import argparse,hashlib,json
p=argparse.ArgumentParser();p.add_argument('--out',type=Path,required=True);a=p.parse_args();root=Path(__file__).resolve().parents[2]
a.out.mkdir(parents=True,exist_ok=True)
cat=json.loads((root/'game/vfx/catalog.json').read_text())['effects']
for family,tail in [('ice','source'),('blade','base')]:
 for key in [k for k in cat if k.startswith(family+'_')]:
  filename=f'{key}_{tail}.png' if key!='blade_ring' else 'blade_ring_base_v2.png'
  source=root/f'game/vfx/sources/{family}/{filename}'
  im=Image.open(source).convert('RGBA');im.thumbnail((896,896),Image.Resampling.LANCZOS)
  canvas=Image.new('RGBA',(1024,1024));canvas.paste(im,((1024-im.width)//2,(1024-im.height)//2))
  output=a.out/f'{key}.png';canvas.save(output)
  existing=Image.open(root/'game'/cat[key]['texture'].removeprefix('res://')).convert('RGBA')
  assert canvas.tobytes()==existing.tobytes(),f'Pixel reconstruction mismatch: {key}'
print('PASS: 8 adopted layout outputs pixel-identical (PNG encoding hashes may vary by Pillow version)')
