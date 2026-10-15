from pathlib import Path
from PIL import Image,ImageDraw
import json,math
P=Path(__file__).parent
old=P.parent/'air_light_11f_v2'
rect=(160,70,440,350); cell=560
refs=Image.new('RGBA',(1680,1680));guide=Image.new('RGBA',(1680,1680))
grips=[[[275,269],[266,249]],[[279,184],[271,157]],[[277,147],[282,121]],[[290,150],[310,123]],[[303,151],[330,136]],[[325,174],[354,178]],[[322,224],[342,237]],[[309,213],[333,206]],[[307,255],[315,234]]]
for j in range(9):
 x=(j%3)*cell;y=(j//3)*cell
 im=Image.open(old/f'body_canvas_{j+2:02}.png').crop(rect).resize((cell,cell),Image.Resampling.LANCZOS)
 refs.alpha_composite(im,(x,y));guide.alpha_composite(im,(x,y))
 d=ImageDraw.Draw(guide)
 g=[(x+(p[0]-rect[0])*2,y+(p[1]-rect[1])*2) for p in grips[j]]
 dx=g[1][0]-g[0][0];dy=g[1][1]-g[0][1];ln=math.hypot(dx,dy)
 d.line((g[0][0]-dx*1.2,g[0][1]-dy*1.2,g[1][0]+dx*1.5,g[1][1]+dy*1.5),fill=(0,255,255,220),width=4)
 for k,(a,b) in enumerate(g):d.ellipse((a-9,b-9,a+9,b+9),outline=(255,20,20,255) if k==0 else (30,100,255,255),width=5)
refs.save(P/'arm-edit-target.png');guide.save(P/'grip-guide.png');(P/'desired-grips.json').write_text(json.dumps(grips))
