from PIL import Image,ImageDraw
from pathlib import Path
import json,math,random
P=Path(__file__).resolve().parent;R=P/'revision_horizontal/charge_rain_circle_10keys';O=P/'rain_circle_sparse_fx';O.mkdir(exist_ok=True)
for s in ['behind','front','upward']:(O/s).mkdir(exist_ok=True)
M=json.load(open(R/'animation.json'));f=next(x for x in M['frames'] if x['release_event']);release=f['start_ms'];g=f['grip_left_hand'];speed=7000;direction=[.55,-.83];exit_ms=release+math.ceil(g[1]/(.83*speed)*1000/10)*10
seed=141026;rand=random.Random(seed);particles=[]
for j in range(70):
 angle=rand.uniform(0,math.tau);radius=1230*math.sqrt(rand.random());x=480+radius*math.cos(angle);y=884+radius*.20*math.sin(angle)
 particles.append({'id':j,'ground_target':[round(x,3),round(y,3)],'world_angle':angle,'world_radius':radius,'birth_offset_ms':0 if j==0 else rand.randrange(0,185),'fall_duration_ms':rand.randrange(220,340),'drop_height':rand.randrange(550,820),'slant':rand.uniform(-.10,.10),'length':rand.randrange(95,135),'z_layer':'behind' if y<884 else 'front'})
def arrow(draw,tail,vec,length):
 tip=(tail[0]+vec[0]*length,tail[1]+vec[1]*length);draw.line([tuple(tail),tip],fill=(194,146,82,255),width=4);normal=(-vec[1],vec[0]);draw.polygon([tip,(tip[0]-vec[0]*14+normal[0]*5,tip[1]-vec[1]*14+normal[1]*5),(tip[0]-vec[0]*14-normal[0]*5,tip[1]-vec[1]*14-normal[1]*5)],fill=(230,231,218,255));draw.line([tuple(tail),(tail[0]+vec[0]*21,tail[1]+vec[1]*21)],fill=(237,217,180,255),width=8)
times=sorted(set(list(range(0,1300,40))+[release,exit_ms,1300]));tiles=[];states=[]
for k,t in enumerate(times[:-1]):
 fi=max(i for i,f in enumerate(M['frames']) if f['start_ms']<=t);char=Image.open(R/'character'/f'{fi:02}.png').convert('RGBA');body=char.copy()
 for layer in ['bow','string']:body.alpha_composite(Image.open(R/layer/f'{fi:02}.png'))
 if t<release:
  for layer in ['arrow','arrow_tail']:body.alpha_composite(Image.open(R/layer/f'{fi:02}.png'))
 grip=M['frames'][fi]['grip_left_hand'];rect=(round(grip[0]-13),round(grip[1]-18),round(grip[0]+17),round(grip[1]+19));body.alpha_composite(char.crop(rect),rect[:2])
 layers={n:Image.new('RGBA',(3072,1536)) for n in ['behind','front','upward']};counts={'behind':0,'front':0}
 if release<=t<exit_ms:
  dt=(t-release)/1000;arrow(ImageDraw.Draw(layers['upward']),[g[0]+direction[0]*speed*dt+1056,g[1]+direction[1]*speed*dt],direction,300)
 for p in particles:
  age=t-exit_ms-p['birth_offset_ms']
  if age<0 or age>p['fall_duration_ms']+100:continue
  progress=min(1,age/p['fall_duration_ms']);target=p['ground_target'];height=p['drop_height']*(1-progress);tip=[target[0]-p['slant']*height,target[1]-height];vec=[p['slant'],1];tail=[tip[0]-vec[0]*p['length']+1056,tip[1]-p['length']]
  arrow(ImageDraw.Draw(layers[p['z_layer']]),tail,vec,p['length']);counts[p['z_layer']]+=1
 for n,im in layers.items():im.save(O/n/f'{k:03}.png')
 comp=layers['behind'].copy();comp.alpha_composite(body,(1056,0));comp.alpha_composite(layers['front']);comp.alpha_composite(layers['upward'])
 tile=Image.new('RGB',(906,483),(50,54,62));small=comp.resize((906,453),Image.Resampling.LANCZOS);tile.paste(small,(0,0),small);ImageDraw.Draw(tile).text((6,461),'charge_rain | +50% spread / 70 arrows | DRAFT',fill='white');tiles.append(tile);states.append({'time_ms':t,'character_frame':fi,'active':counts})
 tiles[-1].save(O/'last_preview.png')
tiles[0].save(O/'charge_rain_circle_plus50_half_arrows_normal.gif',save_all=True,append_images=tiles[1:],duration=[b-a for a,b in zip(times,times[1:])],loop=0,disposal=2)
json.dump({'seed':seed,'center_ground_root':[480,884],'preview_canvas_root':[1536,884],'preview_canvas':[3072,1536],'body_translation_only':[1056,0],'previous_radius':820,'diameter_multiplier':1.5,'previous_particle_count':140,'character_scale_unchanged':True,'circle_world_radius':1230,'perspective_y_scale':.20,'release_ms':release,'upward_arrow_exit_ms':exit_ms,'rain_start_ms':exit_ms,'trigger_delay_ms':0,'layout':'uniform-area seeded irregular circle projected as ground ellipse, targets left right front back','occlusion':'target ground depth below/above root controls front/behind character','particle_count':len(particles),'particles':particles,'states':states,'contact_event':'area_knockdown','ice':False,'explosion':False,'runtime_changes':False},open(O/'circle_rain_events.json','w'),indent=2)
print('release',release,'exit/rain',exit_ms,'particles',len(particles))
