from PIL import Image,ImageDraw
from pathlib import Path
import numpy as np, json,math,hashlib,sys,shutil
from scipy import ndimage
BASE=Path(__file__).parent

def build(name):
 d=BASE/name;c=json.loads((d/'config.json').read_text()); im=Image.open(d/'source.png').convert('RGBA'); spear=Image.open(BASE/'source/spear_suyari.png').convert('RGBA')
 W,H=c.get('canvas_size',[640,340]);floor=c.get('floor_y',296); size=c.get('standing_height',390); s=160/size;ws=c.get('weapon_length',270)/962
 frames=[];records=[]
 for i,f in enumerate(c['frames']):
  s=160/f.get('standing_height',size);x,y,w,h=f['rect'];frame_source=Image.open(BASE/f['source_file']).convert('RGBA') if 'source_file' in f else im;body=frame_source.crop((x,y,x+w,y+h));arr=np.array(body); lab,n=ndimage.label(arr[:,:,3]>24); counts=np.bincount(lab.ravel()); counts[0]=0; keep=lab==counts.argmax(); keep=ndimage.binary_dilation(keep,iterations=2); arr[:,:,3]=np.where(keep,arr[:,:,3],0); body=Image.fromarray(arr); body.save(d/f'body_{i+1:02}.png')
  root=f['root'];pos=f.get('position',[240,296]);ox,oy=pos[0]-root[0]*s,pos[1]-root[1]*s
  if not name.startswith('air_'):
   scaled=body.resize((round(w*s),round(h*s)),Image.Resampling.LANCZOS);aa=np.array(scaled.getchannel('A')); rows=np.where((aa>32).any(axis=1))[0];oy=floor-int(rows[-1]) if len(rows) else oy
  b=Image.new('RGBA',(W,H));b.alpha_composite(body.resize((round(w*s),round(h*s)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
  grip=f['grip'];gx,gy=ox+grip[0]*s,oy+grip[1]*s
  ws=c.get('weapon_length',270)/962*f.get('weapon_scale',1);wg=f.get('weapon_grip',[188,621]);theta=math.radians(f['angle']);co,si=math.cos(theta),math.sin(theta);wx=c.get('weapon_length',270)/962;a,bv=co/wx,si/wx;dd,ee=-si/ws,co/ws
  weapon=spear.transform((W,H),Image.Transform.AFFINE,(a,bv,wg[0]-a*gx-bv*gy,dd,ee,wg[1]-dd*gx-ee*gy),Image.Resampling.BICUBIC)
  b.save(d/f'body_canvas_{i+1:02}.png');weapon.save(d/f'weapon_{i+1:02}.png');
  if f.get('weapon_behind',False): weapon.alpha_composite(b);b=weapon
  else:b.alpha_composite(weapon)
  occlusion=Image.new('RGBA',(W,H))
  for hand in f.get('hands',[grip]):
   r=12;patch=body.crop((hand[0]-r,hand[1]-r,hand[0]+r,hand[1]+r));patch=patch.resize((round(2*r*s),round(2*r*s)),Image.Resampling.LANCZOS);b.alpha_composite(patch,(round(ox+(hand[0]-r)*s),round(oy+(hand[1]-r)*s)));occlusion.alpha_composite(patch,(round(ox+(hand[0]-r)*s),round(oy+(hand[1]-r)*s)))
  occlusion.save(d/f'hand_occlusion_{i+1:02}.png');fx=Image.new('RGBA',(W,H))
  if f.get('dust'):
   fd=ImageDraw.Draw(fx);opacity=int(90*f['dust'])
   for k in range(7):
    xx=pos[0]-70+k*24;yy=floor-5-(k%3)*3;rr=8+(k%3)*3;fd.ellipse((xx-rr,yy-rr/3,xx+rr,yy+rr/3),fill=(149,139,120,opacity))
  fx.save(d/f'effect_{i+1:02}.png');b.alpha_composite(fx)
  b.save(d/f'composite_{i+1:02}.png');can=Image.new('RGB',(W,H),(37,43,52));can.paste(b,mask=b.getchannel('A'));dr=ImageDraw.Draw(can);dr.line((20,floor,620,floor),fill=(65,72,80));dr.text((15,12),'TADAKATSU | '+name+' | prototype',fill=(215,220,225));dr.text((15,H-20),f"{i+1}/{len(c['frames'])} {f['duration']} ms  {f['event']}",fill=(165,174,184));frames.append(can);records.append(dict(f,frame=i+1,screen_root=pos,render_origin=[ox,oy],render_scale=s,screen_grip=[gx,gy],grounded_alpha_bottom=floor if not name.startswith('air_') else None,source_sha256=hashlib.sha256((BASE/f['source_file'] if 'source_file' in f else d/'source.png').read_bytes()).hexdigest()))
 durations=[f['duration'] for f in c['frames']]
 for speed in [1,3]:frames[0].save(d/('normal.gif' if speed==1 else 'slow.gif'),save_all=True,append_images=frames[1:],duration=[x*speed for x in durations],loop=0,disposal=2)
 cs=Image.new('RGB',(W*3,H*math.ceil(len(frames)/3)))
 for i,f in enumerate(frames):cs.paste(f,(i%3*W,i//3*H))
 cs.save(d/'contact.png');elapsed=0
 for rec in records:rec['start_ms']=elapsed;elapsed+=rec['duration']
 (d/'metadata.json').write_text(json.dumps(dict(action=name,frames=records,total_ms=sum(durations),standing_height_reference=size,preview_height=160,weapon_layer_independent=True,runtime_integrated=False,revision=c.get('revision'),timing_basis=c.get('timing_basis')),indent=2))
if __name__=='__main__':build(sys.argv[1])
