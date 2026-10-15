from PIL import Image
from pathlib import Path
import json,hashlib
P=Path(__file__).parent;im=Image.open(P/'source.png').convert('RGBA');r=[]
for j,name in enumerate(['footstep','blunt_impact']):
 for i in range(3):
  box=[i*512,j*512,(i+1)*512,(j+1)*512];cell=im.crop(box);cell.save(P/f'{name}_{i+1:02}_source.png')
  cell.resize((64,64),Image.Resampling.LANCZOS).save(P/f'{name}_{i+1:02}.png')
  r.append(dict(name=name,frame=i+1,file=f'{name}_{i+1:02}.png',source_crop_xyxy=box,anchor=[32,44] if j==0 else [32,32],duration_ms=60 if i!=1 else 80,draw_layer='front',trigger='foot_plant' if j==0 else 'confirmed_blunt_contact',no_extra_damage=True))
(P/'metadata.json').write_text(json.dumps(dict(source='source.png',source_sha256=hashlib.sha256((P/'source.png').read_bytes()).hexdigest(),source_provenance='Built-in image_gen; uniform 1/8 pixel scaling, no procedural substitute.',frames=r),indent=2))
