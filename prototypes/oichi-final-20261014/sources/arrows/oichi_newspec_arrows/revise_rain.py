import render_v2 as b,copy,json
from PIL import Image
P=b.P;O=b.OUT;old=P/'deliverable/charge_rain';m=json.load(open(old/'animation.json'));catalog=[]
for i,f in enumerate(m['frames']):
 n=f.get('right_draw_fingertips') or [f['grip_left_hand'][0]-140,f['grip_left_hand'][1]+180]
 q=copy.deepcopy(b.frames[0]);q.update(image=str(old/'character'/f'{i:02}.png'),phase=f['pose'],grip=f['grip_left_hand'],draw_point=n,is_drawing=f['right_draw_fingertips'] is not None,arrow_nocked=f['arrow_nock'] is not None,release_event=f['release_event'],arrow_flying=f['release_event'],source_provenance=f['provenance'],bow_angle=[0,0,12,32,55,55,0,0][i]);
 if i==5:q['arrow_direction']=[.55,-.83]
 catalog.append(q)
src=P.parent/'generated_images/exec-0eebd114-05ac-45cf-8981-2efcbbe31be1.png';im=Image.open(src).convert('RGBA');scale=.56
for k in range(2):
 box=(k*887,0,(k+1)*887,887);crop=im.crop(box).resize((497,497),Image.Resampling.LANCZOS);off=[211 if k==0 else 212,425];can=Image.new('RGBA',(1024,1024));can.alpha_composite(crop,tuple(off));path=O/f'rain_added_{k}.png';can.save(path)
 cv=lambda p:[off[0]+(p[0]-box[0])*scale,off[1]+p[1]*scale]
 q=copy.deepcopy(catalog[2]);q.update(image=str(path),phase=['squat_draw_transition','rising_followthrough_transition'][k],grip=cv([(820,140),(1685,125)][k]),draw_point=cv([(420,285),(1270,340)][k]),is_drawing=k==0,arrow_nocked=k==0,release_event=False,arrow_flying=False,bow_angle=23 if k==0 else 35,source_provenance={'kind':'cloud_imagegen','source':src.name,'region':box,'anatomical_scale':scale,'root_offset':off,'native_alpha_preserved':True,'no_optical_flow':True});catalog.append(q)
b.frames=catalog
r=b.render('charge_rain_circle_10keys',[0,1,2,8,3,4,5,9,6,7],[80,80,130,100,140,190,100,100,160,220])
a=json.load(open(r/'animation.json'));a.update(action='charge_rain',revision='two_new_character_keyframes_and_centered_irregular_circular_rain',rain_trigger={'event':'upward_arrow_exits_viewport','delay_ms':0,'effect':'independent_arrow_rain','contact':'area_knockdown','ice':False},area={'center_root':[480,884],'ground_circle_radius':410,'perspective_y_scale':.20},runtime_changed=False);json.dump(a,open(r/'animation.json','w'),indent=2)
