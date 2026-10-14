"""Neutral/matchlock offline material previews from actual Emitter state exports."""
import argparse,json,math,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--timeline',type=Path,required=True);p.add_argument('--audio',type=Path,required=True);p.add_argument('--kind',choices=['gun','neutral'],required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
cat=json.load(open(a.repo/'game/vfx/v2/catalog.json'))['effects'];recipes=json.load(open(a.repo/'game/vfx/v2/effect_recipes.json'))['recipes'];frames=json.load(open(a.timeline))['frames'];src={k:Image.open(a.repo/'game'/s['texture'].removeprefix('res://')).convert('RGBA') for k,s in cat.items()};font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';big=ImageFont.truetype(font,27);normal=ImageFont.truetype(font,18);small=ImageFont.truetype(font,14)
NAMES=['neutral_slash_arc','thrust_cone','arrow_trail','throwing_blade_trail','blunt_impact','guard_sparks','slash_hit','dash_dust']
def value(keys,t,default=1):
 if not keys:return default
 if t<=keys[0][0]:return keys[0][1]
 for (x0,y0),(x1,y1) in zip(keys,keys[1:]):
  if t<=x1:return y0+(y1-y0)*(t-x0)/(x1-x0)
 return keys[-1][1]
def draw_state(im,state,origin,binding={}):
 recipe=recipes[state['recipe_id']];phase=recipe['phases'][state['phase']];age=state['last_tick']-state['phase_start'];t=age/phase['duration_ticks'];face=state['context'].get('face',1)
 for layer in phase['layers']:
  spec=cat[layer['effect']];curves={**phase.get('curves',{}),**layer.get('curves',{})};size=layer['size']*value(curves.get('scale'),t)*value(curves.get('radius'),t)*binding.get('size_multiplier',1);alpha=value(curves.get('opacity'),t);stretch=layer.get('stretch',[1,1]);bs=binding.get('stretch',[1,1]);w=max(1,round(size*stretch[0]*bs[0]));h=max(1,round(size*stretch[1]*bs[1]));img=src[layer['effect']].resize((w,h),Image.Resampling.LANCZOS);img.putalpha(img.getchannel('A').point(lambda p:int(p*min(1,max(0,alpha)))))
  px,py=spec.get('pivot',[.5,.5]);px*=w;py*=h
  if face<0:img=img.transpose(Image.Transpose.FLIP_LEFT_RIGHT);px=w-px
  angle=binding.get('rotation',layer.get('rotation',0))*face;rp=(px-w/2,py-h/2);rp=(rp[0]*math.cos(angle)-rp[1]*math.sin(angle),rp[0]*math.sin(angle)+rp[1]*math.cos(angle));img=img.rotate(-math.degrees(angle),resample=Image.Resampling.BICUBIC,expand=True)
  off=layer.get('offset',[0,0]);vel=layer.get('velocity',[0,0]);x=origin[0]+off[0]*face+vel[0]*face*age/60-img.width/2-rp[0];y=origin[1]+off[1]+vel[1]*age/60-img.height/2-rp[1];im.alpha_composite(img,(round(x),round(y)))
proc=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r','30','-i','-','-an','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p',str(a.out/'visual.tmp.mp4')],stdin=subprocess.PIPE)
for frame in frames:
 im=Image.new('RGBA',(1280,720),(12,18,28,255));d=ImageDraw.Draw(im);tick=frame['tick']
 if a.kind=='gun':
  d.text((25,22),'MATCHLOCK / HERO vs ENEMY / SINGLE SHOT + OWN AUDIO',font=big,fill='white');d.text((25,68),'OFFLINE COMPOSITING / Gray lines are barrel-and-muzzle markers, not new character art.',font=small,fill=(161,182,202))
  for origin,face in [((300,280),1),((930,280),-1),((970,520),-1)]:d.line((origin[0]-140*face,origin[1],*origin),fill=(97,113,128),width=9);d.ellipse((origin[0]-3,origin[1]-3,origin[0]+3,origin[1]+3),fill=(197,213,221))
  for i in range(10):d.line((75+i*42,520,100+i*42,520),fill=(97,113,128),width=5)
  for id,state in frame['instances'].items():draw_state(im,state,frame['origins'][id])
  d=ImageDraw.Draw(im);d.text((72,360),'HERO: larger flash, sparks and powder tail',font=normal,fill=(236,206,157));d.text((725,360),'ENEMY: compact, short and mirrored',font=normal,fill=(236,206,157));d.text((62,590),'10 ENEMY SHOTS / 3 ticks apart',font=normal,fill=(225,230,237));d.text((765,590),'DISTANT HERO / distance gain -12 dB',font=normal,fill=(225,230,237));d.text((25,666),'No new reload / penetration / damage rules. One authoritative shot event triggers one effect.',font=small,fill=(161,182,202))
 else:
  d.text((25,22),'NEUTRAL WEAPON MOTION / 8 RECIPES / NO ELEMENT GLOW',font=big,fill='white');d.text((25,68),'OFFLINE COMPOSITING / Trail heads follow velocity; slash origin follows hand-to-tip geometry.',font=small,fill=(161,182,202));index=frame['case_index']
  for i,name in enumerate(NAMES):
   x=155+(i%4)*320;y=280+(i//4)*290;active=i==index;d.text((x-140,y+95),name,font=normal,fill=(242,220,177) if active else (91,109,128))
   if not active:continue
   binding={};angle=0
   if i==0:
    angle=-1.2+(tick%60)*.07;d.line((x,y,x+80*math.cos(angle),y+80*math.sin(angle)),fill=(128,142,153),width=3);binding={'rotation':angle,'size_multiplier':.8}
   elif i==1:angle=math.atan2(-25,80);d.line((x-80,y+25,x,y),fill=(128,142,153),width=3);binding={'rotation':angle,'size_multiplier':math.hypot(80,25)/110,'stretch':[1,.65]}
   elif i in [2,3]:
    vx=850*(-1 if index%2 else 1);vy=-250 if i==2 else 260;angle=math.atan2(vy,vx);d.line((x-20*math.cos(angle),y-20*math.sin(angle),x+8*math.cos(angle),y+8*math.sin(angle)),fill=(160,170,178),width=3);length=min(240,max(12,math.hypot(vx,vy)*(.12 if i==2 else .08)));binding={'rotation':angle,'size_multiplier':length/180,'stretch':[1,.5]}
   else:d.ellipse((x-3,y-3,x+3,y+3),fill=(154,173,190))
   if 'case' in frame['instances']:draw_state(im,frame['instances']['case'],(x,y),binding)
  d=ImageDraw.Draw(im);d.text((25,688),'Gray geometry markers are separate from the transparent motion textures. Each sound fires once.',font=small,fill=(161,182,202))
 if tick in ([2,122,246,362] if a.kind=='gun' else [6,66,126,186,246,306,366,426]):im.convert('RGB').save(a.out/f'{a.kind}-tick-{tick}.jpg',quality=92)
 proc.stdin.write(im.convert('RGB').tobytes())
proc.stdin.close();assert proc.wait()==0
subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(a.out/'visual.tmp.mp4'),'-i',str(a.audio),'-c:v','copy','-c:a','aac','-b:a','192k','-shortest','-movflags','+faststart',str(a.out/f'{a.kind}-effects-audio-demo.mp4')],check=True)
print('PASS',a.kind,'8-second offline material+sound preview')
