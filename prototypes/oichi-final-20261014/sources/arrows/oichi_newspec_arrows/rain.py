import build,copy,json,math
from PIL import Image
P=build.P;O=build.OUT
src=P.parent/'generated_images/exec-db1e1d43-4257-4ec8-8fff-01ca0fda4fb6.png';im=Image.open(src).convert('RGBA')
regions=[(0,0,540,510),(540,0,1036,510),(1036,0,1536,510),(0,512,510,1024),(510,512,1024,1024),(1024,512,1536,1024)]
roots=[(260,496),(789,496),(1293,496),(270,988),(788,988),(1305,988)]
grips=[(502,123),(994,130),(1470,104),(389,543),(880,543),(1480,737)]
draws=[(247,121),(785,169),(1284,219),(250,730),(670,762),(1250,698)]
angles=[0,12,32,55,55,0];scale=1.04
for k,(box,root,g,n) in enumerate(zip(regions,roots,grips,draws)):
 crop=im.crop(box);crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS)
 off=[round(480-(root[0]-box[0])*scale),round(884-(root[1]-box[1])*scale)];can=Image.new('RGBA',(1024,1024));can.alpha_composite(crop,tuple(off));path=O/f'rain_pose_{k}.png';can.save(path)
 cv=lambda p:[off[0]+(p[0]-box[0])*scale,off[1]+(p[1]-box[1])*scale]
 f=copy.deepcopy(build.frames[5]);f.update(image=str(path),phase=['full_draw','half_squat_raise','deep_squat_raise','sky_aim','sky_release','rise_recover'][k],grip=cv(g),draw_point=cv(n),bow_angle=angles[k],is_drawing=k<4,arrow_nocked=k<4,release_event=k==4,arrow_flying=k==4,source_provenance={'kind':'cloud_imagegen','source':src.name,'source_region':box,'anatomical_scale':scale,'root_offset':off,'native_alpha_preserved':True})
 if k==4:f['arrow_direction']=[.55,-.83]
 build.frames.append(f)
idx=[5,11,12,13,14,15,16,0]
root=build.render('charge_rain',idx,[100,100,160,180,230,100,200,230])
a=json.load(open(root/'animation.json'));a['scope']='Character and upward projectile prototype. Independent falling rain VFX not yet rendered.';a['rain_trigger']={'event':'upward_arrow_exits_viewport','delay_ms':0,'effect':'independent_arrow_rain','contact':'area_knockdown','ice':False};json.dump(a,open(root/'animation.json','w'),indent=2)
