from PIL import Image,ImageDraw,ImageFont,ImageFilter
from pathlib import Path
import numpy as np, math, json, hashlib
from scipy import ndimage
from weapon_layer import weapon_layer
P=Path(__file__).parent;D=P/'charge_release_v3';W,H=800,400;ROOT=(400,320)
font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',13)
# Fixed anatomical scale per source sheet, not pose alpha box height.
scales={'cycle':163/469,'transfer':163/473,'prayer':163/457,'overhead':163/469}
sources={k:Image.open(v).convert('RGBA') for k,v in {'cycle':D/'source-cycle.png','transfer':D/'source-transfer.png','prayer':P/'charge_ready/source.png','overhead':D/'source-overhead-v3.png'}.items()}
bead=Image.open(D/'bead-source.png').convert('RGBA');aa=np.array(bead.getchannel('A'));yy,xx=np.where(aa>64);bead=bead.crop((int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1)));bead.save(D/'bead.png')
roots={'overhead':[(264,505)]*3+[(264,480)]*3,'cycle':[(260,486),(260,486),(260,486),(260,480),(260,480),(260,480)],'transfer':[(280,505),(280,505),(280,505),(280,482),(280,482),(280,482)],'prayer':[(277,474)]*3+[(277,477)]*3}
# Source hands measured from generated frames, never inferred from crop dimensions.
hands={'overhead':[(76,276),(186,27),(268,26),(516,128),(255,14),(68,288)],'cycle':[(130,67),(264,190),(474,136),(139,55),(263,187),(45,122)],'transfer':[(315,170),(224,130),(178,34),(368,192),(139,57),(240,155)]}
def body(kind,i):
 x,y=(i%3)*512,(i//3)*512; im=sources[kind].crop((x,y,x+(552 if kind=='overhead' and i==3 else 512),y+512));a=np.array(im); lab,n=ndimage.label(a[:,:,3]>32);counts=np.bincount(lab.ravel());counts[0]=0;keep=ndimage.binary_dilation(lab==counts.argmax(),iterations=2);a[:,:,3]=np.where(keep,a[:,:,3],0);im=Image.fromarray(a)
 s=scales[kind];r=roots[kind][i];origin=(round(ROOT[0]-r[0]*s),round(ROOT[1]-r[1]*s));out=Image.new('RGBA',(W,H));sz=round(512*s);out.alpha_composite(im.resize((round(im.width*s),sz),Image.Resampling.LANCZOS),origin)
 hand=hands.get(kind,[(277,180)]*6)[i];hp=(origin[0]+hand[0]*s,origin[1]+hand[1]*s)
 return out,hp,origin,im

def beadloop(grip,extent,width,angle,size,n=32,phase=0):
 # Two flexible splines form a continuous necklace. Every control point changes,
 # including local curvature and trailing endpoint: never a rigid rotating ellipse.
 g=np.array(grip,dtype=float);a=math.radians(angle);u=np.array([math.cos(a),math.sin(a)]);v=np.array([-u[1],u[0]])
 lag=math.sin(phase*1.35);bend=math.cos(phase*.9)
 tip=g+u*extent+v*(22*lag)
 c1=g+u*(extent*.28)+v*(width*2.0*bend+22)
 c2=g+u*(extent*.72)+v*(-width*1.8*lag-28)
 c3=g+u*(extent*.70)+v*(-width*2.1*lag+12)
 c4=g+u*(extent*.25)+v*(width*1.4*bend-12)
 def bez(p0,p1,p2,p3,t):return (1-t)**3*p0+3*(1-t)**2*t*p1+3*(1-t)*t*t*p2+t**3*p3
 dense=np.array([bez(g,c1,c2,tip,t) for t in np.linspace(0,1,120,endpoint=False)]+[bez(tip,c3,c4,g,t) for t in np.linspace(0,1,120)])
 dist=np.concatenate(([0],np.cumsum(np.linalg.norm(np.diff(dense,axis=0),axis=1))))
 pts=np.array([[np.interp(x,dist,dense[:,k]) for k in range(2)] for x in np.linspace(0,dist[-1],n,endpoint=False)])
 back=Image.new('RGBA',(W,H));front=Image.new('RGBA',(W,H));db=ImageDraw.Draw(back);df=ImageDraw.Draw(front)
 for j,p in enumerate(pts):
  q=pts[(j+1)%n];dr=db if p[1]<g[1] else df;dr.line([tuple(p),tuple(q)],fill=(74,49,29,240),width=max(1,round(size*.20)))
 tile=bead.resize((size,size),Image.Resampling.LANCZOS)
 for p in pts:
  lay=back if p[1]<g[1] else front;lay.alpha_composite(tile,(round(p[0]-size/2),round(p[1]-size/2)))
 return back,front,[(round(float(x),2),round(float(y),2)) for x,y in pts]

particles=[]
def fxfield(grip,angle,now,impact):
 # Spawn ONCE at each strike. After emission only world velocity/gravity/age matters.
 if impact:
  for k in range(6):
   direction=1 if math.cos(math.radians(angle))>=0 else -1
   particles.append(dict(x=grip[0]+direction*(55+(k*31)%135),y=grip[1]-42+((k*29)%79),born=now,vx=direction*(65+(k%4)*33),vy=-100-(k%3)*38,text=['南無','阿弥陀仏','南無阿弥陀仏'][k%3]))
 fx=Image.new('RGBA',(W,H));d=ImageDraw.Draw(fx)
 for p in particles:
  age=(now-p['born'])/1000
  if 0<=age<.5:
   x=p['x']+p['vx']*age;y=p['y']+p['vy']*age+110*age*age
   d.text((x,y),p['text'],font=ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc',9),fill=(238,198,107,round(245*(1-age/.5))))
 return fx

seq=[]
def add(kind,i,duration,event,shape=None,impact=False,roundno=0):seq.append(dict(kind=kind,index=i,duration=duration,event=event,shape=shape,impact=impact,round=roundno))
add('prayer',3,180,'charged prayer hold')
# Normal-size necklace positions for an explicit take-off over the hood.
add('transfer',1,110,'grasp necklace at collar',{'custom':[(-19,-129),42,26,0,7,20]})
add('transfer',2,110,'lift necklace above hood',{'custom':[(-35,-162),43,23,0,7,20]})
add('transfer',3,100,'lower necklace into hands',{'params':[54,18,90,8,24]})
add('transfer',4,100,'draw necklace left and enlarge',{'params':[115,26,160,10,28]})
# 26 active body playback keys +12 transfer/recovery keys =38, five more than33.
# Six new authored body poses supply visible shoulder/chest/waist force.
for rnd in range(1,4):
 steps=[('overhead',0,50,'pull left low',[145,25,165,11,32],False)]
 if rnd<3:steps.append(('cycle',0,50,'lift from left shoulder',[150,28,155,11,32],False))
 else:steps[0]=('overhead',0,60,'pull left low',[145,25,165,11,32],False)
 steps += [
 ('overhead',1,50 if rnd<3 else 60,'pull upward above left of head',[145,28,145,11,32],False),
 ('overhead',2,40 if rnd<3 else 50,'carry over head toward right',[160,32,-40,12,34],False),
 ('overhead',3,80,'right strike with waist drive',[215,27,-5,13,36],True),
 ('cycle',2,40 if rnd<3 else 50,'rightward followthrough',[190,30,18,12,34],False),
 ('overhead',4,50 if rnd<3 else 60,'pull back over head toward left',[155,30,-135,12,34],False),
 ('overhead',5,70,'left strike with shoulder drive',[215,26,185,13,36],True),
 ('overhead',0,40,'left low followthrough',[165,28,165,11,32],False)]
 for kind,i,dur,ev,shape,hit in steps:add(kind,i,dur,f'round {rnd} '+ev,{'params':shape},hit,rnd)
add('transfer',5,140,'gather necklace back to normal',{'params':[65,20,90,8,24]})
add('transfer',2,110,'lift loop back over hood',{'custom':[(-35,-162),43,23,0,7,20]})
add('transfer',1,110,'settle necklace at collar',{'custom':[(-19,-129),42,26,0,7,20]})
add('prayer',3,220,'necklace restored; prayer recovery')
add('prayer',2,120,'release palms')
add('prayer',1,110,'return hands')
add('prayer',0,350,'return ready')
for ix,f in enumerate(seq):f['shape_phase']=ix*.65
records=[];previews=[];no_fx=[];frames_rgba=[];elapsed=0
for j,f in enumerate(seq):
 b,hp,org,raw=body(f['kind'],f['index']);back=Image.new('RGBA',(W,H));front=back.copy();occl=back.copy();fx=back.copy();pts=[];angle=0
 if f['shape']:
  if 'custom' in f['shape']:
   off,extent,width,angle,size,n=f['shape']['custom'];hp=(ROOT[0]+off[0],ROOT[1]+off[1])
  else:extent,width,angle,size,n=f['shape']['params']
  back,front,pts=beadloop(hp,extent,width,angle,size,n,f['shape_phase'])
  if f['kind'] in ('cycle','overhead') or f['event'].startswith('draw'):
   # Local finger cap from original body only, not a whole arm pasted above the chain.
   rad=5;bb=(round(hp[0]-rad),round(hp[1]-rad),round(hp[0]+rad),round(hp[1]+rad));occl.alpha_composite(b.crop(bb),(bb[0],bb[1]))
  fx=fxfield(hp,angle,elapsed,f['impact'])
 staff=weapon_layer((W,H),(ROOT[0]-8,ROOT[1]-85),-24)
 comp=staff.copy();comp.alpha_composite(back);comp.alpha_composite(b);comp.alpha_composite(front);comp.alpha_composite(occl)
 for name,im in [('weapon_back',staff),('body',b),('beads_back',back),('beads_front',front),('hand_occlusion',occl),('effect',fx),('composite_no_fx',comp)]:im.save(D/f'{name}_{j+1:02}.png')
 full=comp.copy();full.alpha_composite(fx);full.save(D/f'composite_{j+1:02}.png');frames_rgba.append(full)
 for dest,im in [(no_fx,comp),(previews,full)]:
  c=Image.new('RGB',(W,H),(40,44,48));c.paste(im,mask=im.getchannel('A'));d=ImageDraw.Draw(c);d.line((20,ROOT[1],780,ROOT[1]),fill=(75,80,85));d.text((15,14),'KENNYO03 | prayer-bead ultimate | 3 rounds / 6 strikes',fill=(230,232,234));d.text((15,375),f['event'],fill=(185,192,200));dest.append(c)
 records.append(dict(f,frame=j+1,start_ms=elapsed,root=list(ROOT),scale=scales[f['kind']],source_origin=org,grip=[round(v,2) for v in hp],bead_path=pts));elapsed+=f['duration']
for name,fs,mult in [('normal',previews,1),('slow',previews,3),('no-fx',no_fx,1)]:
 fs[0].save(D/f'{name}.gif',save_all=True,append_images=fs[1:],duration=[f['duration']*mult for f in seq],loop=0,disposal=2)
previews[7].save(D/'poster.png')
select=list(range(0,len(seq),3))
cs=Image.new('RGB',(W*4,H*math.ceil(len(select)/4)),(40,44,48))
for n,i in enumerate(select):cs.paste(previews[i],((n%4)*W,(n//4)*H))
cs.save(D/'contact.jpg',quality=91)
(D/'metadata.json').write_text(json.dumps({'action':'charge_release','identity':'approved sohei candidate03','body_playback_key_count':38,'previous_body_playback_key_count':33,'added_body_playback_keys':5,'new_authored_overhead_source_poses':6,'standing_anatomical_px':163,'scale_basis':'fixed per source-sheet anatomical crown/sole reference; crouch poses never bbox normalized','total_ms':elapsed,'rounds':3,'strike_events':[{'frame':r['frame'],'start_ms':r['start_ms'],'round':r['round'],'event':r['event']} for r in records if r['impact']],'user_override':'standing chant, enlarged elongated necklace left/right three rounds, Buddhist chant glyph spray','damage_and_status_not_invented':True,'weapon_state':'shakujo stowed diagonally on back throughout necklace special; separate continuous layer','bead_motion':'flexible closed twin spline, time-varying curvature and lag, arc-length bead spacing','buddha_particles':'world-space ballistic emission on six strike events; independent velocity, 500ms fade','layers':['weapon_back','body','beads_back','beads_front','hand_occlusion','effect'],'glyph_text':'南無阿弥陀仏','runtime_integrated':False,'frames':records},indent=2))
print('frames',len(seq),'duration',elapsed,'strikes',sum(x['impact'] for x in seq))
