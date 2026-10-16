from PIL import Image,ImageDraw
from pathlib import Path
import numpy as np,math,json
D=Path(__file__).parent;P=D.parent;W,H=640,380;sc=163/1420;ws=Image.open(P/'source/ornate_shakujo-source.png').convert('RGBA');wsc=215/1360
cfgs=[None,dict(file='impact-original.png',pivot=[550,750],grip=[380,390],feet=[[800,1390],[920,1090]],angle=-20,rotation=0),dict(file='flight-original.png',pivot=[700,650],grip=[280,450],feet=[[1120,950],[1370,660]],angle=30,rotation=0),dict(file='flight-original.png',pivot=[700,650],grip=[280,450],feet=[[1120,950],[1370,660]],angle=75,rotation=-8),dict(file='fall-original.png',pivot=[750,600],grip=None,feet=[[1220,950],[1410,710]],angle=100,rotation=0)];ds=[30,70,90,110,120];disp=[[0,0],[-25,-20],[-75,-95],[-120,-65],[-155,-15]];frames=[];review=[];meta=[];idle=Image.open(P/'idle/composite.png').convert('RGBA')
for i,cfg in enumerate(cfgs):
 if cfg is None:
  ls={n:Image.open(P/f'idle/{n}.png').convert('RGBA') for n in ['body','weapon','hand_occlusion']};co=idle.copy();rec={'source':'registered combat idle','root':[286,325],'feet':[[226.351,326.011],[330.484,325]],'grips':[[286,227.607],[278.923,216.149]],'weapon_angle_degrees':-31.7014}
 else:
  src=Image.open(D/'source'/cfg['file']).convert('RGBA');a=np.array(src.getchannel('A'));yy,xx=np.where(a>128);theta=math.radians(cfg['rotation']);c=math.cos(theta);s=math.sin(theta);px,py=cfg['pivot'];dest=[800,850]
  def point(q):
   dx,dy=q[0]-px,q[1]-py;return [800+c*dx-s*dy,850+s*dx+c*dy]
  def rig(im):return im.transform((1800,1800),Image.Transform.AFFINE,(c,s,px-c*800-s*850,-s,c,py+s*800-c*850),Image.Resampling.BICUBIC)
  hi=rig(src);hi.save(D/f'body_source_{i+1:02}.png');ox=286-800*sc;oy=260-850*sc
  def small(im):
   out=Image.new('RGBA',(W,H));out.alpha_composite(im.resize((round(1800*sc),round(1800*sc)),Image.Resampling.LANCZOS),(round(ox),round(oy)));return out
  body=small(hi);hand=Image.new('RGBA',(W,H));grips=[]
  if cfg['grip']:
   g=point(cfg['grip']);gp=[ox+g[0]*sc,oy+g[1]*sc];mask=Image.new('L',src.size);x,y=cfg['grip'];ImageDraw.Draw(mask).ellipse((x-45,y-45,x+45,y+45),fill=255);h=src.copy();h.putalpha(Image.fromarray((np.array(mask,dtype=np.float32)*np.array(src.getchannel('A'))/255).astype('uint8')));hand=small(rig(h));grips=[gp]
  else:gp=[350,250]
  ang=math.radians(cfg['angle']);c=math.cos(ang)/wsc;s=math.sin(ang)/wsc;weapon=ws.transform((W*4,H*4),Image.Transform.AFFINE,(c/4,s/4,95.5-c*gp[0]-s*gp[1],-s/4,c/4,147/wsc+s*gp[0]-c*gp[1]),Image.Resampling.BICUBIC).resize((W,H),Image.Resampling.LANCZOS)
  ls={'body':body,'weapon':weapon,'hand_occlusion':hand};co=body.copy();co.alpha_composite(weapon);co.alpha_composite(hand);feet=[]
  for f in cfg['feet']:
   q=point(f);feet.append([ox+q[0]*sc,oy+q[1]*sc])
  rec=dict(source='source/'+cfg['file'],source_effective_bbox=[int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)],uniform_scale=sc,source_anatomical_standing_ruler_px=1420,root=[286,325],feet=feet,grips=grips,weapon_angle_degrees=cfg['angle'],weapon_released=cfg['grip'] is None)
 for n,im in ls.items():im.save(D/f'{n}_{i+1:02}.png')
 co.save(D/f'composite_{i+1:02}.png');bg=Image.new('RGB',(W,H),(40,44,48));bg.paste(co,disp[i],co);dr=ImageDraw.Draw(bg);dr.line((20,326,620,326),fill=(95,102,109));dr.text((20,18),'KENNYO03 / LAUNCHED / candidate / 163px',fill='white');dr.text((20,350),f'{i+1}/5 | {ds[i]}ms | impact -> flight -> falling',fill='white');frames.append(bg);rv=Image.new('RGB',(1280,400),(40,44,48));rv.paste(idle,(0,0),idle);rv.paste(bg,(640,0));ImageDraw.Draw(rv).text((20,18),'APPROVED combat idle / unchanged',fill='white');review.append(rv)
 rec.update(frame=i+1,duration_ms=ds[i],start_ms=sum(ds[:i]),layer_order=['body','weapon','hand_occlusion'],preview_displacement=disp[i],world_displacement=[0,0],world_motion_mode='engine knockback impulse; preview not baked',events=[['entry_idle'],['hit_takeoff'],['flight_apex'],['descending'],['release_weapon','transition_to_down']][i]);meta.append(rec)
frames[0].save(D/'kennyo03-launched.gif',save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2);review[0].save(D/'idle-launched-comparison.gif',save_all=True,append_images=review[1:],duration=ds,loop=0,disposal=2);review[2].save(D/'idle-launched-comparison.png');(D/'metadata.json').write_text(json.dumps(dict(character='kennyo03',action='launched',candidate=True,approved=False,frames=meta,frame_count=5,total_duration_ms=sum(ds),loop=False,preview_repeats_for_review=True,standing_ruler_px=163,fx=False,root_local_layers=True,transition_to='down',no_optical_flow=True,source_references=['original identity idle-body.png','approved combat light_1/source.png']),indent=2))
