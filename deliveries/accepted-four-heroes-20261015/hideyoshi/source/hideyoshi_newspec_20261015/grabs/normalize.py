from pathlib import Path
from PIL import Image,ImageSequence
import json,math
R=Path(__file__).parent;N=R/'normalized';N.mkdir(exist_ok=True);scale=150/266;tx=round((520-800*scale)/2);ty=round(251-360*scale);M=json.loads((R/'manifest.json').read_text());NM={}
def transform(im,bg=(0,0,0,0)):
 im=im.convert('RGBA');out=Image.new('RGBA',(520,300),bg);out.alpha_composite(im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS),(tx,ty));return out
for n,meta in M.items():
 d=R/n;o=N/n;o.mkdir(exist_ok=True)
 for p in d.glob('*.png'):
  if p.name.startswith(('body_','weapon_','victim_')):transform(Image.open(p)).save(o/p.name)
 frames=[];gif=Image.open(d/'normal.gif');durs=[]
 for f in ImageSequence.Iterator(gif):frames.append(transform(f,(45,50,60,255)).convert('RGB'));durs.append(f.info['duration'])
 frames[0].save(o/f'hideyoshi_{n}_head95_game150.gif',save_all=True,append_images=frames[1:],duration=durs,loop=0,disposal=2)
 frames[min(2,len(frames)-1)].save(o/f'hideyoshi_{n}_head95_game150.png')
 contact=Image.new('RGB',(520*3,300*math.ceil(len(frames)/3)),(45,50,60))
 for i,f in enumerate(frames):contact.paste(f,(520*(i%3),300*(i//3)))
 contact.save(o/'contact.jpg');mm={'source_metadata':'../../'+n+'/metadata.json','source':meta['source'],'source_sha256':meta['source_sha256'],'head_scale':.95,'game_normalization':{'source_body_height_equivalent':266,'target_body_height_equivalent':150,'scale':scale,'source_canvas':[800,420],'target_canvas':[520,300],'translation':[tx,ty],'floor':251,'method':'Uniform whole-scene scale; character, victim, weapon and contacts use identical affine transform'},'frames':[]}
 for f in meta['frames']:
  ff=dict(f)
  for key in ['support_foot','hand_contact','victim_translation']:ff[key]=[round(f[key][0]*scale+tx,3),round(f[key][1]*scale+ty,3)]
  ff['source_translation']=ff.pop('translation');ff['body_scale']=f['scale']*scale;ff['normalization_transform']=[scale,0,tx,0,scale,ty];mm['frames'].append(ff)
 mm['duration_ms']=meta['duration_ms'];(o/'metadata.json').write_text(json.dumps(mm,indent=2));NM[n]=mm
(N/'manifest.json').write_text(json.dumps(NM,indent=2));(N/'preview.html').write_text('<body style="background:#2d323c;color:white">'+''.join(f'<h3>{n}</h3><img src="{n}/hideyoshi_{n}_head95_game150.gif">' for n in M))
print('Normalized 6 actions',scale,tx,ty)
