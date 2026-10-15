from PIL import Image,ImageDraw
from pathlib import Path
import json
P=Path(__file__).parent
src=Image.open(P/'charge_ready/source.png').convert('RGBA')
scale=163/457
# Anatomical standing scale is shared, never normalized by per-frame alpha bounds.
roots=[(277,474),(277,474),(277,474),(277,477),(277,477),(277,477)]
bodies=[]
for i in range(6):
 cell=src.crop(((i%3)*512,(i//3)*512,(i%3+1)*512,(i//3+1)*512))
 cell.save(P/f'charge_ready/body_{i+1:02}.png')
 b=Image.new('RGBA',(640,340));r=cell.resize((round(512*scale),round(512*scale)),Image.Resampling.LANCZOS)
 b.alpha_composite(r,(round(320-roots[i][0]*scale),round(285-roots[i][1]*scale)))
 b.save(P/f'charge_ready/body_canvas_{i+1:02}.png');bodies.append(b)
def build(name,ids,durs,events):
 out=P/name;out.mkdir(exist_ok=True);frames=[]
 for j,i in enumerate(ids):
  canvas=Image.new('RGB',(640,340),(40,44,48));canvas.paste(bodies[i],mask=bodies[i].getchannel('A'))
  dr=ImageDraw.Draw(canvas);dr.line((24,285,616,285),fill=(75,80,85));dr.text((16,14),'KENNYO 03 | '+name+' | game scale',fill=(220,222,224));dr.text((16,316),events[j],fill=(180,185,190));frames.append(canvas)
 frames[0].save(out/'normal.gif',save_all=True,append_images=frames[1:],duration=durs,loop=0,disposal=2)
 frames[0].save(out/'slow.gif',save_all=True,append_images=frames[1:],duration=[v*3 for v in durs],loop=0,disposal=2)
 frames[-1].save(out/'poster.png')
 (out/'metadata.json').write_text(json.dumps({'action':name,'scale':scale,'scale_basis':'shared skeleton/head scale, no bbox-height normalization','standing_equivalent_pixels':163,'root':[320,285],'body_frames':[i+1 for i in ids],'durations_ms':durs,'events':events,'weapon_layer':'none during prayer','effect_layer':'pending separate particles','runtime_integrated':False},indent=2))
build('charge_ready',[0,1,2,3],[90,90,100,900],['empty-grip idle','hands approach','palms meet','fixed upright chant'])
build('charge_hold',[3],[1000],['fixed chant; body stays completely still'])
contact=Image.new('RGB',(640*3,340*2),(40,44,48))
for i,b in enumerate(bodies):
 c=Image.new('RGB',(640,340),(40,44,48));c.paste(b,mask=b.getchannel('A'));contact.paste(c,((i%3)*640,(i//3)*340))
contact.save(P/'charge_ready/contact.jpg',quality=92)
