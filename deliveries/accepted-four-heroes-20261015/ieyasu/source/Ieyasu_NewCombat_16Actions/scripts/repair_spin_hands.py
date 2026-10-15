from pathlib import Path
from PIL import Image,ImageDraw
import json
P=Path(__file__).resolve().parents[1];D=P/'actions/charge_release';O=P/'qa/charge_release_hand_candidate';O.mkdir(parents=True,exist_ok=True)
m=json.load(open(D/'metadata.json'));src=Image.open(D/'sources/right_hand_repair.png').convert('RGBA')
polys=[[(370,130),(580,130),(580,230),(420,300),(365,230)],[(900,130),(1060,130),(1060,235),(930,300),(885,230)],[(1070,140),(1280,140),(1280,245),(1070,225)],[(1530,135),(1820,135),(1820,245),(1530,225)]]
hands=[(558,170),(1030,170),(1127,174),(1570,175)];out=[]
for i in range(8,12):
 r=m['frames'][i];s=r['body_scale'];rx,ry=r['support_foot'];ox=205-rx*s;oy=365-ry*s
 mask=Image.new('L',src.size);ImageDraw.Draw(mask).polygon(polys[i-8],fill=255)
 patch=src.copy();a=patch.getchannel('A');import PIL.ImageChops
 patch.putalpha(PIL.ImageChops.multiply(a,mask));patch.save(O/f'arm_source_{i:02}.png')
 arm=Image.new('RGBA',(560,400));arm.alpha_composite(patch.resize((round(src.width*s),round(src.height*s)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
 gx,gy=hands[i-8];grip=[ox+gx*s,oy+gy*s];fist_unscaled=arm.crop((round(grip[0]-5),round(grip[1]-6),round(grip[0]+5),round(grip[1]+6)))
 if i in [9,10,11]:
  pivot,k={9:(177,.25),10:(170,.60),11:(150,.50)}[i]
  arm=arm.transform(arm.size,Image.Transform.AFFINE,(1/k,0,pivot-pivot/k,0,1,0),Image.Resampling.BICUBIC);grip[0]=pivot+(grip[0]-pivot)*k
 canvas=arm.copy();canvas.alpha_composite(Image.open(D/f'body_canvas_{i:02}.png'))
 if i in [9,10,11]:canvas.alpha_composite(fist_unscaled,(round(grip[0]-5),round(grip[1]-6)))
 canvas.save(O/f'body_canvas_{i:02}.png');out.append(dict(frame=i,grip_world=grip,local_repair='far right arm local patch; perspective compressed approaching side view; original upper retained except fist visibility'))
(O/'metadata.json').write_text(json.dumps(out,indent=2))
cs=Image.new('RGB',(1120,800),(47,53,61))
for j,i in enumerate(range(8,12)):
 im=Image.open(O/f'body_canvas_{i:02}.png');bg=Image.new('RGB',im.size,(47,53,61));bg.paste(im,mask=im.getchannel('A'));ImageDraw.Draw(bg).text((10,10),str(i+1),fill='white');cs.paste(bg,((j%2)*560,(j//2)*400))
cs.save(O/'contact.png')
