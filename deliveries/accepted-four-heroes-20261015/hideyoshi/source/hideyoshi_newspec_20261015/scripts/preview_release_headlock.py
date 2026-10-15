from PIL import Image,ImageDraw,ImageFilter
from pathlib import Path
import numpy as np
P=Path(__file__).resolve().parents[1];D=P/'head_identity_fix';D.mkdir(exist_ok=True)
ref=Image.open(P/'hideyoshi_head95_single_preview.png').convert('RGBA');mask=Image.new('L',ref.size);ImageDraw.Draw(mask).polygon([(104,0),(206,0),(206,77),(182,81),(171,84),(152,95),(138,81),(136,67),(108,65)],fill=255);head=ref.copy();head.putalpha(Image.fromarray(np.minimum(np.array(ref.getchannel('A')),np.array(mask))))
old=Image.open(P/'actions/charge_release_scale_v4/body_canvas_01.png').convert('RGBA');body=old.copy();clear=Image.new('L',old.size);ImageDraw.Draw(clear).polygon([(211,106),(246,106),(246,137),(237,137),(237,133),(218,133),(213,130),(211,126)],fill=255);body.putalpha(Image.fromarray(np.where(np.array(clear)>0,0,np.array(body.getchannel('A'))).astype('uint8')))
s=.31875;anchor=(150,93);target=(227,138.5);ox=target[0]-anchor[0]*s;oy=target[1]-anchor[1]*s;tile=head.transform(old.size,Image.Transform.AFFINE,(1/s,0,-ox/s,0,1/s,-oy/s),Image.Resampling.BICUBIC);body.alpha_composite(tile);body.save(D/'body_nearside_candidate.png');head.save(D/'approved_head_mask.png');clear.save(D/'old_head_remove_mask.png')
cs=Image.new('RGB',(1040,650),(42,48,56));dr=ImageDraw.Draw(cs)
for k,z in enumerate([old,body]):
 comp=z.copy();wp=Image.open(P/'actions/charge_release_scale_v4/weapon_01.png').convert('RGBA');comp.alpha_composite(wp)
 # keep original forearm/hands over blade as in the approved frame.
 previous=Image.open(P/'actions/charge_release_scale_v4/composite_01.png').convert('RGBA');comp.paste(previous.crop((0,151,520,300)),(0,151))
 cs.paste(comp,(k*520,0),comp);crop=z.crop((199,100,253,155)).resize((270,275),Image.Resampling.NEAREST);cs.paste(crop,(k*520+120,320),crop);dr.text((k*520+12,12),'BEFORE - pivot generated head' if k==0 else 'AFTER - exact approved95 head / neck locked',fill='white')
cs.save(D/'near_side_comparison.png')
print(D/'near_side_comparison.png')
