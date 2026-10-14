from PIL import Image,ImageDraw
from pathlib import Path
import json,copy,math,hashlib,shutil
P=Path(__file__).resolve().parent; OLD=P/'prior/heavy_1000ms'; A=json.load(open(OLD/'standing/animation.json')); OUT=P/'revision_horizontal';OUT.mkdir(exist_ok=True)
# Freeze the existing anatomically normalized native poses; use no optical flow.
frames=copy.deepcopy(A['frames'])
for f in frames:
 f['image']=str(OLD/f['character_png']);f['source_provenance']=f.get('provenance');f['anatomical_height']=502
raw=Image.open(P.parent/'generated_images/exec-5eacfe6b-46f7-4a13-81d6-d2846ae221bc.png').convert('RGBA')
# Standing-equivalent ruler from face and leg segments; not alpha bbox height.
scale=.64; im=raw.resize((round(raw.width*scale),round(raw.height*scale)),Image.Resampling.LANCZOS);can=Image.new('RGBA',(1024,1024));can.alpha_composite(im,(83,145));can.save(OUT/'short_release_character.png')
f=copy.deepcopy(frames[3]);f.update(image=str(OUT/'short_release_character.png'),grip=[761,484],draw_point=[490,539],is_drawing=False,arrow_nocked=False,release_event=True,arrow_flying=True,phase='short_release',source_provenance={'kind':'cloud_imagegen','raw':'exec-5eacfe6b-46f7-4a13-81d6-d2846ae221bc.png','scale':.64,'translation':[83,145],'no_optical_flow':True});frames.append(f)
json.dump(frames,open(OUT/'pose_catalog.json','w'),indent=2)

def render(name,idx,durations):
 root=OUT/name;root.mkdir(exist_ok=True)
 for sub in ['character','bow','string','arrow','arrow_tail','composite']:(root/sub).mkdir(exist_ok=True)
 rows=[];tiles=[];start=0
 bow0=Image.open(P/'bow_azusa.png').convert('RGBA');bs=.54;bow0=bow0.resize((round(bow0.width*bs),round(bow0.height*bs)),Image.Resampling.LANCZOS)
 bg=(50,54,62); side=302
 for i,j in enumerate(idx):
  f=copy.deepcopy(frames[j]);char=Image.open(f['image']).convert('RGBA');g=f['grip'];n=f['draw_point'];blank=lambda:Image.new('RGBA',(1024,1024))
  bow=blank();bow.alpha_composite(bow0,(round(g[0]-240*bs),round(g[1]-640*bs)))
  tips=[[g[0]+(153-240)*bs,g[1]+(18-640)*bs],[g[0]+(144-240)*bs,g[1]+(966-640)*bs]]
  angle=f.get('bow_angle',0);rad=math.radians(angle);c=math.cos(rad);ss=math.sin(rad)
  if angle:
   bow=bow.rotate(angle,resample=Image.Resampling.BICUBIC,center=tuple(g))
   tips=[[g[0]+c*(p[0]-g[0])+ss*(p[1]-g[1]),g[1]-ss*(p[0]-g[0])+c*(p[1]-g[1])] for p in tips]
  string=blank();d=ImageDraw.Draw(string);draw=f['is_drawing'];d.line([tuple(tips[0]),tuple(n),tuple(tips[1])] if draw else [tuple(tips[0]),tuple(tips[1])],fill=(230,219,188,255),width=3)
  arrow=blank();tail=blank();v=f.get('arrow_direction',[g[0]-n[0],g[1]-8-n[1]]);norm=math.hypot(*v);v=[x/norm for x in v]
  t=n if f['arrow_nocked'] else f.get('arrow_tail_override',[g[0]+v[0]*20,g[1]-8+v[1]*20])
  if f['arrow_nocked'] or f['arrow_flying']:
   tip=[t[0]+v[0]*300,t[1]+v[1]*300];ad=ImageDraw.Draw(arrow);ad.line([tuple(t),tuple(tip)],fill=(171,125,73,255),width=4);ad.ellipse((tip[0]-4,tip[1]-4,tip[0]+4,tip[1]+4),fill=(225,225,218,255));td=ImageDraw.Draw(tail);td.line([tuple(t),(t[0]+v[0]*30,t[1]+v[1]*30)],fill=(240,225,185,255),width=9)
  comp=char.copy()
  for layer in [bow,string,arrow,tail]:comp.alpha_composite(layer)
  # Exact opaque source hand pixels occlude grip; nothing is painted onto character.
  rect=(round(g[0]-13),round(g[1]-18),round(g[0]+17),round(g[1]+19));comp.alpha_composite(char.crop(rect),rect[:2])
  for key,im in [('character',char),('bow',bow),('string',string),('arrow',arrow),('arrow_tail',tail),('composite',comp)]:im.save(root/key/f'{i:02}.png')
  tile=Image.new('RGB',(side,side+30),bg);small=comp.resize((side,side),Image.Resampling.LANCZOS);tile.paste(small,(0,0),small);ImageDraw.Draw(tile).text((8,side+7),f'{name} | PROTOTYPE',fill='white');tiles.append(tile)
  rows.append({'index':i,'pose':f['phase'],'duration_ms':durations[i],'start_ms':start,'root':[480,884],'grip_left_hand':g,'right_draw_fingertips':n if draw else None,'bow_tips':tips,'arrow_nock':n if f['arrow_nocked'] else None,'release_event':f['release_event'],'projectiles':1 if f['release_event'] else 0,'provenance':f['source_provenance']});start+=durations[i]
 tiles[0].save(root/f'{name}_normal_prototype.gif',save_all=True,append_images=tiles[1:],duration=durations,loop=0,disposal=2)
 meta={'action':name,'status':'prototype, new specification not yet mapped to game ticks','preview_only_ms':start,'runtime_timing_changed':False,'game_scale':A['game_scale'],'standing_equivalent_height_px':148,'root':[480,884],'frames':rows,'event_rules':{'heavy':'one arrow, contact standing knockback, no ice','charge_release':'one piercing arrow, contact knockback, no ice','charge_rain':'one upward arrow, on viewport exit immediately independent rain, area knockdown, no ice'},'layers':['character','bow','string','arrow','arrow_tail'],'loopable':name=='charge_hold','no_optical_flow':True}
 json.dump(meta,open(root/'animation.json','w'),indent=2)
 return root
if __name__=='__main__':
 render('heavy',[0,1,2,3,10,9,0],[80,90,90,140,90,130,180])
