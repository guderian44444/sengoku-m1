from PIL import Image,ImageDraw
import numpy as np, json, hashlib, math
from pathlib import Path
BASE=Path(__file__).parent
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
def build(name,poses,durations,events):
 d=BASE/name;d.mkdir(exist_ok=True); src=Image.open(d/'body_source.png').convert('RGBA'); bow=Image.open(BASE/'sources/bow_azusa.png').convert('RGBA')
 frames=[]; records=[]; contacts=[]
 for i,p in enumerate(poses):
  cell,root,hand,aux,ang,dx=p[:6]; source_path=d/'body_source.png'; frame_src=src
  if cell==-1: source_path=BASE/'light_1/body_source.png'; frame_src=Image.open(source_path); cell=0
  if len(p)>7: source_path=BASE/p[7]; frame_src=Image.open(source_path)
  x=(cell%3)*512;y=(cell//3)*512
  w=h=512
  if len(p)>6: x,y,w,h=p[6]
  body=frame_src.crop((x,y,x+w,y+h));body.save(d/f'body_{i:02}.png');scale=148/480
  out=Image.new('RGBA',(340,250),(30,39,49,255)); layer=Image.new('RGBA',out.size);ox=112+dx-root[0]*scale;oy=218-root[1]*scale
  layer.alpha_composite(body.resize((round(w*scale),round(h*scale)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
  # Separate full-length bow with unstretched string; transform around measured native grip.
  wb=Image.new('RGBA',(1400,1400));wb.alpha_composite(bow,(460,50));wd=ImageDraw.Draw(wb);wd.line([(605,65),(598,1024)],fill=(226,205,170,215),width=3)
  # Native grip 240,650 is now 700,700; rotate center and then scale to a constant physical length.
  wb=wb.rotate(-ang,Image.Resampling.BICUBIC);ws=scale*.49;wb=wb.resize((round(1400*ws),round(1400*ws)),Image.Resampling.LANCZOS)
  hp=(ox+hand[0]*scale,oy+hand[1]*scale)
  out.alpha_composite(layer);out.alpha_composite(wb,(round(hp[0]-wb.width/2),round(hp[1]-wb.height/2)))
  # Tight manually measured front-hand patches. Native alpha preserved.
  mask=Image.new('RGBA',body.size)
  for pt in [hand,aux]:
   box=(int(pt[0]-10),int(pt[1]-11),int(pt[0]+10),int(pt[1]+11));mask.alpha_composite(body.crop(box),box[:2])
  mask.save(d/f'hand_foreground_{i:02}.png');out.alpha_composite(mask.resize((round(w*scale),round(h*scale)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
  dr=ImageDraw.Draw(out);dr.text((9,8),f'OICHI {name} | 148px | prototype',fill=(228,232,239));dr.line((20,219,320,219),fill=(78,87,96));out.convert('RGB').save(d/f'preview_{i:02}.png');frames.append(out.convert('RGB'))
  records.append(dict(frame=i,source_region=[x,y,w,h],source_file=str(source_path.relative_to(BASE)),source_sha256=sha(source_path),body_height=480,foot=root,hand=hand,melee_support_grip=aux,weapon_angle=ang,weapon_visible=True,weapon_behind=False,root_displacement_px148=dx,duration_ms=durations[i],hand_foreground_mask=f'hand_foreground_{i:02}.png'))
 frames[0].save(d/f'oichi_{name}_148px.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2)
 montage=Image.new('RGB',(340*len(frames),250));
 for i,f in enumerate(frames):montage.paste(f,(i*340,0))
 montage.save(d/'contact_sheet.png')
 a=np.array(src)[:,:,3]
 meta=dict(action=name,status='prototype; not runtime registered',timing_basis='estimated short ground strike; original runtime duration not available in source registration',body_height_measurement='Constant 480 source px standing-equivalent crown-to-sole ruler, excluding ponytail; no frame bbox normalization',frames=records,events=events,source_sha256=sha(d/'body_source.png'),weapon_sha256=sha(BASE/'sources/bow_azusa.png'),alpha_zero_fraction=float((a==0).mean()),notes=['New imagegen articulated poses, no optical flow.','No second_hand field; melee_support_grip is not string draw.','Single input triggers only this clip; next segment requires new press.','Forward displacement retained at end.','Preview uses no hit FX without an opponent.','Bow and unstretched string independently composited; no arrows.'])
 (d/'anchors_events.json').write_text(json.dumps(meta,indent=2))
 return frames
if __name__=='__main__':
 build('light_1',[(0,(405,490),(350,138),(361,153),-35,0),(1,(407,490),(198,92),(204,111),-22,0),(2,(387,490),(408,168),(398,181),42,4),(3,(433,490),(482,126),(468,135),58,9),(4,(402,490),(362,133),(371,150),-25,12),(5,(390,490),(323,130),(336,147),-35,12),(0,(405,490),(350,138),(361,153),-35,12)],[160,90,60,70,90,100,250],[{'frame':2,'event':'foot_plant'},{'frame':3,'event':'bow_body_contact_window','on_confirmed_hit':'push_standing_target'},{'frame':6,'event':'ready_and_optional_next_press'}])
