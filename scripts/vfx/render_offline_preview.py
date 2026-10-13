"""Offline visual contract preview, NOT native gameplay/GPU capture.
Composites original RGBA textures with the same ellipse UV flow/depth seam contract.
No source PNG pixel edits are written. Static actor poses isolate occlusion tests.
"""
import argparse,json,math,subprocess
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw,ImageFont
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--actors',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--seconds',type=int,default=12);args=p.parse_args()
root=args.root;out=args.out;out.mkdir(parents=True,exist_ok=True)
catalog=json.loads((root/'game/vfx/catalog.json').read_text())['effects']
actors=json.loads((args.actors/'actors.json').read_text())
fontfile='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
font=ImageFont.truetype(fontfile,22);small=ImageFont.truetype(fontfile,15);title=ImageFont.truetype(fontfile,30)
cache={}
def load(key,size):
 k=(key,size)
 if k not in cache:
  path=root/'game'/catalog[key]['texture'].removeprefix('res://')
  cache[k]=np.asarray(Image.open(path).convert('RGBA').resize((size,size),Image.Resampling.LANCZOS)).astype(np.float32)
 return cache[k]
def warp(key,size,t,angle_override=None):
 spec=catalog[key];a=load(key,size);pad=round(size*spec.get('render_padding',0));yy,xx=np.mgrid[:size+2*pad,:size+2*pad].astype(np.float32);u=(xx-pad)/(size-1);v=(yy-pad)/(size-1)
 if spec.get('motion')=='ellipse_flow':
  cx,cy=spec.get('flow_center',[.5,.518]);rx,ry=spec.get('flow_radius',[.46,.18]);ang=t*spec.get('flow_radians_per_second',.6) if angle_override is None else angle_override
  qx=(u-cx)/rx;qy=(v-cy)/ry
  u=cx+(qx*np.cos(ang)-qy*np.sin(ang))*rx;v=cy+(qx*np.sin(ang)+qy*np.cos(ang))*ry
 elif spec.get('motion')=='turbulence':
  env=np.sin(u*np.pi)*np.sin(v*np.pi)
  u,v=u+np.sin(v*26-t*6)*.008*env,v+np.cos(u*21-t*4)*.008*env
 x=np.clip(u*(size-1),0,size-1);y=np.clip(v*(size-1),0,size-1);x0=x.astype(int);y0=y.astype(int);x1=np.minimum(x0+1,size-1);y1=np.minimum(y0+1,size-1);fx=(x-x0)[...,None];fy=(y-y0)[...,None]
 b=(a[y0,x0]*(1-fx)+a[y0,x1]*fx)*(1-fy)+(a[y1,x0]*(1-fx)+a[y1,x1]*fx)*fy
 return Image.fromarray(np.clip(b,0,255).astype('uint8'))
def paste(canvas,img,x,y,alpha=1):
 if alpha<1:img=img.copy();img.putalpha(img.getchannel('A').point(lambda p:int(p*max(0,alpha))))
 canvas.alpha_composite(img,(round(x),round(y)))
def actor(canvas,key,x,y,flip=False):
 meta=actors[key];im=Image.open(args.actors/f'{key}.png').convert('RGBA');scale=200/meta['body_height'];im=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS);ax,ay=meta['anchor'];ax*=scale;ay*=scale
 if flip:im=im.transpose(Image.Transpose.FLIP_LEFT_RIGHT);ax=im.width-ax
 paste(canvas,im,x-ax,y-ay)
proc=subprocess.Popen(['ffmpeg','-y','-loglevel','error','-f','rawvideo','-pix_fmt','rgb24','-s','1280x720','-r','30','-i','-','-an','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',str(out/'shared-vfx-offline-preview.mp4')],stdin=subprocess.PIPE)
for frame in range(args.seconds*30):
 t=frame/30; family=['fire','blade','ice'][min(2,int(t//4))];local=t%4
 if family+'_ring' not in catalog:family='fire'
 im=Image.new('RGBA',(1280,720),(14,21,31,255));d=ImageDraw.Draw(im)
 d.rectangle((0,420,1280,720),fill=(30,36,40));d.line((0,545,1280,545),fill=(68,78,78),width=2)
 for x in [430,855]:d.line((x,130,x,640),fill=(52,64,77))
 d.text((34,22),'SHARED VFX / '+family.upper(),font=title,fill=(240,243,248));d.text((34,65),'OFFLINE COMPOSITING TEST  |  One authored texture per effect + continuous procedural UV motion',font=small,fill=(175,190,208))
 d.text((34,90),'Static poses for occlusion inspection. Not native gameplay capture; no combat damage is simulated.',font=small,fill=(175,190,208))
 # Two independent rings: rear halves, character, front halves.
 rings=[]
 for i in range(2):
  size=350-i*40;spec=catalog[family+'_ring'];spin=local%2;ring=warp(family+'_ring',size,t,spin*math.tau*2/1.2);opacity=max(0,min(1,spin/.1,(1.2-spin)/.167));ring.putalpha(ring.getchannel('A').point(lambda p:int(p*opacity)));pad=round(size*spec.get('render_padding',0));seam=round(size*spec.get('seam',.518))+pad;px=215-size*.5-pad;py=475-i*67-size*spec.get('pivot',[.5,.518])[1]-pad
  rings.append((ring,seam,px,py));paste(im,ring.crop((0,0,ring.width,seam)),px,py)
 actor(im,'ieyasu',215,545)
 for ring,seam,px,py in rings:paste(im,ring.crop((0,seam,ring.width,ring.height)),px,py+seam)
 actor(im,'nobunaga',613,545,True)
 age=(local%1.2)*60-14
 if 0<=age<24:
  fx=warp(family+'_arc',265,age/60);fx=fx.transpose(Image.Transpose.FLIP_LEFT_RIGHT);paste(im,fx,468,282, min(1,(24-age)/5))
 actor(im,'oichi',1010,545)
 age=(local%1.6)*60-22
 if 0<=age<36:
  fx=warp('blue_white_wave' if family=='fire' else family+'_wave',300,age/60);paste(im,fx,920+age*1.2,250-age*1.2,min(1,(36-age)/8))
 # Secondary sparks/snow: supplemental marks only, core image remains artist texture.
 d=ImageDraw.Draw(im)
 for i in range(18):
  age=(t*.6+i*.119)%1;px=215+math.sin(i*2.39+t)*145;py=450-age*130
  color=(255,170,65) if family=='fire' else ((220,240,255) if family=='ice' else (236,240,255))
  r=1+(i%2);d.ellipse((px-r,py-r,px+r,py+r),fill=(*color,int(180*(1-age))))
 d.text((63,601),'2 TURNS / 72 TICKS' if family!='ice' else 'RIGID ICE + SNOW',font=font,fill=(239,213,164));d.text((481,601),'MIRRORED STRIKE',font=font,fill=(239,213,164));d.text((931,601),'RELEASE / RISING WAVE',font=font,fill=(239,213,164))
 d.text((63,634),'Back half > actor > front half',font=small,fill=(175,190,208));d.text((481,634),'Author frame count: 1; tick window',font=small,fill=(175,190,208));d.text((931,634),'Charge 22 ticks, then release',font=small,fill=(175,190,208))
 if frame in [24,144,264]:im.convert('RGB').save(out/f'{family}-preview.png')
 proc.stdin.write(im.convert('RGB').tobytes())
proc.stdin.close();assert proc.wait()==0
print('Wrote offline preview:',out/'shared-vfx-offline-preview.mp4')
