from PIL import Image,ImageDraw
import numpy as np,math,json,hashlib
from pathlib import Path
D=Path(__file__).parent;P=D.parent;S=Path('kennyo03_snapshot_20261015_v6/sources');W,H=640,380;sc=163/950
ws=Image.open(P/'source/ornate_shakujo-source.png').convert('RGBA');wsc=215/1360
prep=dict(file='jump12-original.png',rect=[0,0,820,1024],feet=[[90,955],[680,930]],grips=[[470,480],[415,375]],root_x=450);up=dict(file='jump12-original.png',rect=[820,0,1536,1024],feet=[[60,960],[390,870]],grips=[[380,360],[340,270]],root_x=400);apex=dict(file='jump34-original.png',rect=[0,0,820,1024],feet=[[390,700],[465,748]],grips=[[350,320],[330,200]],root_x=450);descent=dict(file='jump34-original.png',rect=[820,0,1536,1024],feet=[[75,975],[560,925]],grips=[[345,470],[297,350]],root_x=350);configs=[None,prep,up,apex,descent,prep,None];ds=[60,180,90,130,100,110,160];py=[0,0,-12,-55,-30,0,0];frames=[];comparison=[];records=[]
idle=Image.open(P/'idle/composite.png').convert('RGBA')
for i,cfg in enumerate(configs):
 if cfg is None:
  layers={n:Image.open(P/f'idle/{n}.png').convert('RGBA') for n in ['body','weapon','hand_occlusion']};co=idle.copy();rec=dict(source='registered approved combat idle',root=[286,325],feet_preview=[[226.351,326.011],[330.484,325]],grips_preview=[[286,227.607],[278.923,216.149]],weapon_angle_degrees=-31.7014,uniform_body_scale=.337)
 else:
  im=Image.open(D/'source'/cfg['file']).convert('RGBA');body=im.crop(cfg['rect']);body.save(D/f'body_source_{i+1:02}.png');ox=286-cfg['root_x']*sc;oy=325-950*sc
  b=Image.new('RGBA',(W,H));b.alpha_composite(body.resize((round(body.width*sc),round(body.height*sc)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
  g,u=cfg['grips'];gp=[ox+g[0]*sc,oy+g[1]*sc];up=[ox+u[0]*sc,oy+u[1]*sc];angle=math.atan2(up[0]-gp[0],gp[1]-up[1]);c=math.cos(angle)/wsc;s=math.sin(angle)/wsc
  weapon=ws.transform((W*4,H*4),Image.Transform.AFFINE,(c/4,s/4,95.5-c*gp[0]-s*gp[1],-s/4,c/4,147/wsc+s*gp[0]-c*gp[1]),Image.Resampling.BICUBIC).resize((W,H),Image.Resampling.LANCZOS)
  mask=Image.new('L',body.size);md=ImageDraw.Draw(mask)
  for x,y in [g,u]:md.ellipse((x-30,y-28,x+30,y+28),fill=255)
  hand=body.copy();hand.putalpha(Image.fromarray((np.array(mask,dtype=np.float32)*np.array(body.getchannel('A'))/255).astype('uint8')));hl=Image.new('RGBA',(W,H));hl.alpha_composite(hand.resize((round(body.width*sc),round(body.height*sc)),Image.Resampling.LANCZOS),(round(ox),round(oy)))
  layers={'body':b,'weapon':weapon,'hand_occlusion':hl};co=b.copy();co.alpha_composite(weapon);co.alpha_composite(hl);aa=np.array(body.getchannel('A'));yy,xx=np.where(aa>128)
  rec=dict(source='source/'+cfg['file'],source_crop=cfg['rect'],source_effective_height_px=int(yy.max()-yy.min()+1),root=[286,325],feet_source=cfg['feet'],feet_preview=[[ox+x*sc,oy+y*sc] for x,y in cfg['feet']],grips_source=cfg['grips'],grips_preview=[gp,up],weapon_angle_degrees=math.degrees(angle),uniform_body_scale=sc)
 for n,v in layers.items():v.save(D/f'{n}_{i+1:02}.png')
 co.save(D/f'composite_{i+1:02}.png');bg=Image.new('RGB',(W,H),(40,44,48));bg.paste(co,(0,py[i]),mask=co.getchannel('A'));dd=ImageDraw.Draw(bg);dd.line((20,326,620,326),fill=(95,102,109));dd.text((20,18),'KENNYO 03 / JUMP / candidate / 163px',fill='white');dd.text((20,350),f'{i+1}/7 | {ds[i]}ms | crouch / push-off / apex / land | no FX',fill=(205,210,216));frames.append(bg)
 review=Image.new('RGB',(1280,400),(40,44,48));review.paste(idle,(0,0),idle);review.paste(bg,(640,0));ImageDraw.Draw(review).text((20,18),'APPROVED combat idle / unchanged',fill='white');comparison.append(review)
 rec.update(frame=i+1,duration_ms=ds[i],start_ms=sum(ds[:i]),layer_order=['body','weapon','hand_occlusion'],preview_displacement=[0,py[i]],world_displacement=[0,0],world_vertical_mode="engine_controls_jump_arc",root_local_layers=True,events=[["entry_idle"],["anticipation_crouch"],["takeoff"],["apex"],["descending"],["landing"],["settled_to_idle"]][i]);records.append(rec)
frames[0].save(D/'kennyo03-jump.gif',save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2);frames[0].save(D/'kennyo03-jump-slow.gif',save_all=True,append_images=frames[1:],duration=[d*3 for d in ds],loop=0,disposal=2);comparison[0].save(D/'idle-jump-comparison.gif',save_all=True,append_images=comparison[1:],duration=ds,loop=0,disposal=2);comparison[2].save(D/'idle-jump-comparison.png')
(D/'metadata.json').write_text(json.dumps(dict(character='kennyo03',action='jump',candidate=True,approved=False,frames=records,frame_count=7,total_duration_ms=sum(ds),loop=False,preview_repeats_for_review=True,exit_to='registered_idle',standing_ruler_px=163,fixed_scale='fixed source163/950, jump poses not bbox normalized',fx=False,source_sha256={n:hashlib.sha256((D/'source'/n).read_bytes()).hexdigest() for n in ['jump12-original.png','jump34-original.png']},source_references=['original high-resolution identity/idle-body.png','approved combat light_1/source.png'],no_optical_flow=True,no_reduced_frame_regeneration=True),ensure_ascii=False,indent=2))
print([(r['frame'],r.get('source_effective_height_px')) for r in records])
