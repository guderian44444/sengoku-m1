from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,math
D=Path(__file__).resolve().parents[1];I=json.load(open(D/'inventory.json'))
for c in I['clips']:
 k=c['key'];n=c['approved_preview']['frames']
 if k=='throw_reverse':continue
 sheet=Image.new('RGB',(1440,400*math.ceil(n/4)),(35,40,48));dr=ImageDraw.Draw(sheet)
 for i in range(n):
  p=D/k/'frames-composite'/f'{i:03}.png'
  if k=='charge_release' and i>0:p=D/k/'layers-native/actor'/f'{i:03}.png'
  im=Image.open(p).convert('RGBA');b=Image.new('RGBA',im.size,(35,40,48,255));b.alpha_composite(im);z=np.array(b);out=D/k/'layers-visible';wm=np.array(Image.open(out/'masks'/f'{i:03}-weapon.png'))>0;hm=np.array(Image.open(out/'masks'/f'{i:03}-hand.png'))>0;z[wm,:3]=(z[wm,:3]*.3+np.array([45,220,250])*.7).astype('uint8');z[hm,:3]=(z[hm,:3]*.3+np.array([240,70,190])*.7).astype('uint8');q=Image.fromarray(z).convert('RGB');q.thumbnail((360,360));xx=i%4*360;yy=i//4*400;sheet.paste(q,(xx,yy+30));dr.text((xx+10,yy+5),f'{k} {i:02}',fill='white')
 sheet.save(D/'qa'/f'{k}-layers.jpg',quality=94)
print('Final QA rendered')
