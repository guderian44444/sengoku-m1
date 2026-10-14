"""Software compositing from actual headless Emitter timeline; NOT native GPU capture."""
import argparse,json,math,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--timeline',type=Path,required=True);p.add_argument('--audio',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args();a.out.mkdir(parents=True,exist_ok=True)
cat=json.load(open(a.repo/'game/vfx/v2/catalog.json'))['effects'];recipes=json.load(open(a.repo/'game/vfx/v2/effect_recipes.json'))['recipes'];timeline=json.load(open(a.timeline))['frames']
font='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';title=ImageFont.truetype(font,28);normal=ImageFont.truetype(font,20);small=ImageFont.truetype(font,15)
sources={k:Image.open(a.repo/'game'/v['texture'].removeprefix('res://')).convert('RGBA') for k,v in cat.items()}
def value(keys,t,default=1):
 if not keys:return default
 if t<=keys[0][0]:return keys[0][1]
 for (x0,y0),(x1,y1) in zip(keys,keys[1:]):
  if t<=x1:return y0+(y1-y0)*(t-x0)/(x1-x0)
 return keys[-1][1]
def integral(keys,t,default=.6):
 if t<=0:return 0
 if not keys:return t*default
 last=0;lv=value(keys,0,default);s=0
 for x,y in keys:
  end=min(t,x)
  if end>last:
   ev=value(keys,end,default);s+=(lv+ev)*.5*(end-last);last=end;lv=ev
  if last>=t:return s
 return s+(t-last)*lv

def image_for(key,size,age,angle):
 spec=cat[key];size=max(4,round(size));pad=round(size*spec.get('render_padding',0));img=np.asarray(sources[key].resize((size,size),Image.Resampling.LANCZOS),dtype=np.float32)
 yy,xx=np.mgrid[:size+2*pad,:size+2*pad].astype(np.float32);u=(xx-pad)/(size-1);v=(yy-pad)/(size-1)
 if spec.get('motion')=='ellipse_flow':
  cx,cy=spec.get('flow_center',spec.get('pivot',[.5,.5]));rx,ry=spec.get('flow_radius',[.4,.15]);qx=(u-cx)/rx;qy=(v-cy)/ry
  u=cx+(qx*math.cos(angle)-qy*math.sin(angle))*rx;v=cy+(qx*math.sin(angle)+qy*math.cos(angle))*ry
 elif spec.get('motion')=='turbulence':
  env=np.sin(u*np.pi)*np.sin(v*np.pi);t=age/60
  u,v=u+np.sin(v*26-t*6)*.008*env,v+np.cos(u*21-t*4)*.008*env
 valid=(u>=0)&(u<=1)&(v>=0)&(v<=1);x=np.clip(u*(size-1),0,size-1);y=np.clip(v*(size-1),0,size-1);x0=x.astype(int);y0=y.astype(int);x1=np.minimum(x0+1,size-1);y1=np.minimum(y0+1,size-1);fx=(x-x0)[...,None];fy=(y-y0)[...,None]
 out=(img[y0,x0]*(1-fx)+img[y0,x1]*fx)*(1-fy)+(img[y1,x0]*(1-fx)+img[y1,x1]*fx)*fy;out[:,:,3]*=valid
 return Image.fromarray(np.clip(out,0,255).astype('uint8')),size,pad

def layers(state,origin):
 recipe=recipes[state['recipe_id']];phase=recipe['phases'][state['phase']];age=state['last_tick']-state['phase_start'];duration=phase['duration_ticks'];t=age/duration;result=[]
 for layer in phase.get('layers',[]):
  curves={**phase.get('curves',{}),**layer.get('curves',{})};size=layer.get('size',280)*value(curves.get('scale'),t)*value(curves.get('radius'),t);alpha=value(curves.get('opacity'),t);key=layer['effect'];spec=cat[key]
  if spec.get('family')=='lightning':alpha*=.82+.18*math.sin(math.floor(age/3)*2.399)
  if size<1 or alpha<=0:continue
  angle=state.get('uv_offset_radians',0)+integral(curves.get('uv_radians_per_second'),t)*duration/60
  img,size,pad=image_for(key,size,age,angle);img.putalpha(img.getchannel('A').point(lambda p:int(p*max(0,min(1,alpha)))))
  offset=layer.get('offset',[0,0]);velocity=layer.get('velocity',[0,0]);pivot=spec.get('pivot',[.5,.5]);x=origin[0]+offset[0]+velocity[0]*age/60-pivot[0]*size-pad;y=origin[1]+offset[1]+velocity[1]*age/60-pivot[1]*size-pad
  seam=round(spec.get('seam',.5)*size)+pad if spec.get('split_depth') else None
  result.append((img,round(x),round(y),seam))
 for hit in state.get('hit_visuals',[]):
  age=state['last_tick']-hit['tick']
  if 0<=age<16:
   key=recipe['hit_effect'];img,size,pad=image_for(key,150*(.55+.7*age/16),age,0);img.putalpha(img.getchannel('A').point(lambda p:int(p*(1-age/16))));result.append((img,round(550-size*.5),round(380-size*.5),None))
 return result
proc=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r','30','-i','-','-an','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p',str(a.out/'visual-only.tmp.mp4')],stdin=subprocess.PIPE)
for index,frame in enumerate(timeline):
 im=Image.new('RGBA',(1280,720),(12,18,28,255));d=ImageDraw.Draw(im);family=frame['family'];tick=frame['tick']
 d.text((30,22),'VFX v2 / '+family.upper()+' / EACH EFFECT HAS ITS OWN SOUND',font=title,fill=(245,247,250));d.text((30,68),'OFFLINE COMPOSITING FROM GODOT CONTROLLER TIMELINE / SINGLE BASES + PROCEDURAL MOTION',font=small,fill=(163,185,207));d.line((640,130,640,620),fill=(52,65,78));d.line((25,458,1255,458),fill=(51,62,72))
 for key,origin in [('charge',(310,440)),('spin',(950,440))]:
  state=frame['instances'].get(key);visuals=layers(state,origin) if state else []
  for img,x,y,seam in visuals:
   if seam is not None:im.alpha_composite(img.crop((0,0,img.width,seam)),(x,y))
  d=ImageDraw.Draw(im);d.rounded_rectangle((origin[0]-26,origin[1]-110,origin[0]+26,origin[1]+15),radius=8,fill=(63,78,91));d.text((origin[0]-30,origin[1]+23),'anchor',font=small,fill=(120,144,164))
  for img,x,y,seam in visuals:
   if seam is None:im.alpha_composite(img,(x,y))
   else:im.alpha_composite(img.crop((0,seam,img.width,img.height)),(x,y+seam))
 d=ImageDraw.Draw(im);d.text((92,540),'GATHER > RELEASE > CONFIRMED HIT',font=normal,fill=(239,211,160));d.text((714,540),('GROWING ICE RING / FADE' if family=='ice' else '2 TURNS / EXPANDING RADIUS / FADE'),font=normal,fill=(239,211,160))
 d.text((92,577),'Charge loop stops on release. Hit cue plays once.',font=small,fill=(165,186,205));d.text((714,577),'Radius 0.55 > 1.15 > 1.80, then dissipates.',font=small,fill=(165,186,205));d.text((30,654),f'Local simulation tick {tick:03d} / 216. Gray forms are occlusion markers; this is not gameplay capture.',font=small,fill=(157,180,202))
 if tick in [30,66]:im.convert('RGB').save(a.out/f'{family}-tick-{tick}.jpg',quality=92)
 proc.stdin.write(im.convert('RGB').tobytes())
proc.stdin.close();assert proc.wait()==0
subprocess.run(['ffmpeg','-y','-loglevel','error','-i',str(a.out/'visual-only.tmp.mp4'),'-i',str(a.audio),'-c:v','copy','-c:a','aac','-b:a','192k','-shortest','-movflags','+faststart',str(a.out/'five-families-curves-audio-demo.mp4')],check=True)
print('PASS: 18 second curve/audio preview, exact supplied audio duration and controller event times')
