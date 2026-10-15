from PIL import Image,ImageDraw
from pathlib import Path
import math,json,hashlib
P=Path(__file__).resolve().parents[1];D=P/'actions/light_1';D.mkdir(exist_ok=True)
im=Image.open(P/'actions/light_1_source.png').convert('RGBA');sw=Image.open(P/'reference/tachi.png').convert('RGBA');sa=Image.open(P/'reference/saya.png').convert('RGBA');W,H=520,280
# Cell-local landmark coordinates, measured from actual artwork. Constant world scale, support feet relocked after transform.
hands=[(228,215),(153,200),(333,129),(398,127),(360,252),(272,205),(221,217),(228,215)]
roots=[(340,431),(342,431),(348,431),(365,431),(375,431),(367,431),(343,431),(340,431)]
angles=[-55,-30,-40,90,110,100,0,-55];ds=[110,100,70,60,90,90,90,110];xs=[180,180,190,201,201,201,201,201];ss=152/416
frames=[];records=[]
def weapon(src,anchor,point,angle,scale):
 t=math.radians(angle);c=math.cos(t)/scale;s=math.sin(t)/scale;gx,gy=point;ax,ay=anchor
 return src.transform((W,H),Image.Transform.AFFINE,(c,s,ax-c*gx-s*gy,-s,c,ay+s*gx-c*gy),Image.Resampling.BICUBIC)
for i in range(8):
 j=0 if i==7 else i;x0=round((j%4)*im.width/4);x1=round((j%4+1)*im.width/4);y0=round((j//4)*im.height/2);y1=round((j//4+1)*im.height/2)
 body=im.crop((x0,y0,x1,y1));body.save(D/f'body_{i:02}.png');rx,ry=roots[i];ox=xs[i]-rx*ss;oy=245-ry*ss
 layer=Image.new('RGBA',(W,H));small=body.resize((round(body.width*ss),round(body.height*ss)),Image.Resampling.LANCZOS);layer.alpha_composite(small,(round(ox),round(oy)));layer.save(D/f'body_canvas_{i:02}.png')
 gx,gy=hands[i];point=(ox+gx*ss,oy+gy*ss);sword=weapon(sw,(100,1080),point,angles[i],.085)
 # Sheath anchored at left waist behind body, angle diagonally down-back.
 saya=weapon(sa,(87,22),(ox+225*ss,oy+220*ss),65,.073);saya.save(D/f'sheath_{i:02}.png');sword.save(D/f'sword_{i:02}.png')
 comp=Image.new('RGBA',(W,H));comp.alpha_composite(saya);comp.alpha_composite(layer);comp.alpha_composite(sword)
 patch=body.crop((gx-13,gy-13,gx+13,gy+13)).resize((round(26*ss),round(26*ss)),Image.Resampling.LANCZOS);comp.alpha_composite(patch,(round(point[0]-13*ss),round(point[1]-13*ss)));comp.save(D/f'composite_{i:02}.png')
 bg=Image.new('RGB',(W,H),(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,246,W,246),fill=(80,86,93));dr.text((12,12),'IEYASU 06 / light_1 / 8 keyframes / 720 ms',fill='white');dr.text((12,262),f'{i+1:02}  body + tachi + saya | candidate',fill=(180,190,200));frames.append(bg)
 records.append(dict(frame=i,source_cell=j,source_rect=[x0,y0,x1,y1],support_foot=[rx,ry],root_world=[xs[i],245],body_scale=ss,grip=[gx,gy],blade_angle=angles[i],duration_ms=ds[i],event='contact_push' if i==3 else None))
frames[0].save(D/'light_1_normal.gif',save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2)
frames[0].save(D/'light_1_slow.gif',save_all=True,append_images=frames[1:],duration=[d*3 for d in ds],loop=0,disposal=2)
sheet=Image.new('RGB',(W*4,H*2));[sheet.paste(f,((i%4)*W,(i//4)*H)) for i,f in enumerate(frames)];sheet.save(D/'contact_sheet.png')
json.dump(dict(action='light_1',candidate=True,frames=records,total_ms=sum(ds),source_sha256=hashlib.sha256((P/'actions/light_1_source.png').read_bytes()).hexdigest(),limitations=['whole-body frames; anatomical limb split not done','weapon baseline is candidate; blade perspective variants pending','not native runtime tested']),open(D/'metadata.json','w'),indent=2)
