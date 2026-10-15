from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
from scipy.ndimage import label, find_objects
import numpy as np, math, json, hashlib
from head_scale import shrink_head
P=Path(__file__).resolve().parents[1]
W,H=520,300; ROOT=(184,251)
SWORD=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
CFG={
 'ready':dict(file='charge_ready_cutout.png',scale=.30,
  center=[285,790,1292,271,772,1277],ground=[515,516,516,990,990,990],
  hands=[[(160,272),(400,286)],[(734,229),(806,256)],[(1288,257),(1312,267)],[(275,750),(296,761)],[(747,751),(773,762)],[(1254,754),(1278,766)]],
  head=[(238,8,344,123),(728,22,836,140),(1218,33,1334,151),(218,526,330,642),(718,535,834,652),(1217,534,1340,651)]),
 'release':dict(file='charge_release_clean.png',scale=.36,
  center=[246,674,1109,1546,208,663,1104,1562],ground=[430,426,427,430,858,864,865,862],
  hands=[[(166,205),(193,213)],[(735,208),(773,201)],[(1027,187),(1162,197)],[(1478,204),(1498,205)],[(88,627),(105,634)],[(676,640),(691,642)],[(1091,639),(1115,639)],[(1517,639),(1533,642)]],
  head=[(224,20,326,127),(646,18,733,108),(1054,18,1143,103),(1481,17,1581,122),(151,466,248,577),(642,460,739,570),(1064,452,1139,574),(1514,462,1618,582)])}
def load_source(key):
 c=CFG[key];im=Image.open(P/'actions'/c['file']).convert('RGBA');a=np.array(im);l,n=label(a[:,:,3]>20);objects=[]
 for j,s in enumerate(find_objects(l)):
  if (l[s]==j+1).sum()>3000:objects.append((j+1,s))
 objects.sort(key=lambda z:((z[1][0].start+z[1][0].stop)/2>im.height/2,z[1][1].start))
 assert len(objects)==(6 if key=='ready' else 8)
 c['objects']=objects;c['image']=im;c['array']=a;c['labels']=l
for key in CFG:load_source(key)
def empty():return Image.new('RGBA',(W,H))
def body_frame(key,index):
 c=CFG[key];idx,s=c['objects'][index];a=c['array'][s].copy();a[:,:,3]=np.where(c['labels'][s]==idx,a[:,:,3],0);box=(s[1].start,s[0].start,s[1].stop,s[0].stop);body=Image.fromarray(a)
 body=shrink_head(body,box,c['head'][index],1,1)
 sc=c['scale'];ox=ROOT[0]-c['center'][index]*sc;oy=ROOT[1]-c['ground'][index]*sc
 tile=body.resize((round(body.width*sc),round(body.height*sc)),Image.Resampling.LANCZOS);canvas=empty();canvas.alpha_composite(tile,(round(ox+box[0]*sc),round(oy+box[1]*sc)))
 hands=[(ox+x*sc,oy+y*sc) for x,y in c['hands'][index]]
 # At the true back view both hands are hidden around the waist. The katana stays behind the torso.
 grip=tuple(np.mean(hands,axis=0))
 return canvas,grip,dict(source=key,source_index=index,source_rect=box,body_scale=sc,hand_centers=hands,grip_world=grip,foot_ground=ROOT[1],center_world=ROOT[0]),hands

def sword_layer(grip,angle=90,yaw=None):
 # A projected 3D yaw around a vertical axis: all blade tips remain at waist height.
 ax,ay=180,710;px,py=grip;ws=.145
 if yaw is None:
  t=math.radians(angle);M=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]])*ws
 else:
  p=math.radians(yaw);x=math.cos(p);x=math.copysign(max(abs(x),.16),x)
  # Original sword points up. Its length rotates only in the horizontal XZ plane.
  # The shallow vertical component is camera projection of depth, never an overhead swing.
  M=np.array([[0,-x],[1,-.18*math.sin(p)]])*ws
 inv=np.linalg.inv(M);v=np.array([ax,ay])-inv@np.array([px,py]);coef=tuple(inv[0])+tuple([v[0]])+tuple(inv[1])+tuple([v[1]])
 return SWORD.transform((W,H),Image.Transform.AFFINE,coef,Image.Resampling.BICUBIC)

def fists_mask(canvas,hands):
 m=Image.new('L',(W,H));d=ImageDraw.Draw(m)
 for x,y in hands:d.ellipse((x-4.7,y-4.7,x+4.7,y+4.7),fill=255)
 a=np.minimum(np.array(canvas.getchannel('A')),np.array(m));r=canvas.copy();r.putalpha(Image.fromarray(a));return r

def effects(kind,phase=0,y=177):
 back=empty();front=empty()
 if kind=='hold':
  # Stored fan does not move. A quiet waist-height charge cue is isolated in the FX layer.
  alpha=int(40+phase*75);d=ImageDraw.Draw(back);d.ellipse((ROOT[0]-72,y-12,ROOT[0]+72,y+12),outline=(239,200,93,alpha),width=1)
  d=ImageDraw.Draw(front);d.arc((ROOT[0]-72,y-12,ROOT[0]+72,y+12),0,180,fill=(255,217,112,alpha),width=2)
 elif kind=='release':
  yaw=phase;r=134;ry=22
  for j in range(14):
   t=math.radians(yaw-75+j*6);tn=t+math.radians(7)
   xy=[(ROOT[0]+r*math.cos(t),y+ry*math.sin(t)),(ROOT[0]+r*math.cos(tn),y+ry*math.sin(tn))]
   target=front if math.sin(t)>=0 else back;d=ImageDraw.Draw(target)
   d.line(xy,fill=(200,225,248,int(35+j*12)),width=2)
 return back,front

def assembled(key,index,angle=90,yaw=None,fx=None,phase=0):
 body,grip,record,hands=body_frame(key,index);weapon=sword_layer(grip,angle,yaw)
 back,front=effects(fx,phase,grip[1]) if fx else (empty(),empty())
 comp=back.copy();behind=yaw is not None and 30<yaw%360<210
 if behind:comp.alpha_composite(weapon)
 comp.alpha_composite(body)
 if not behind:comp.alpha_composite(weapon);comp.alpha_composite(fists_mask(body,hands))
 comp.alpha_composite(front)
 record.update(weapon_angle=angle if yaw is None else None,weapon_yaw_degrees=yaw,weapon_scale=.145,weapon_grip_local=[180,710],weapon_behind_body=behind,weapon_plane='waist_horizontal' if yaw is not None else 'waist_safe',head_scale=.95)
 return dict(body_canvas=body,weapon=weapon,fx_back=back,fx_front=front,composite=comp,record=record)

def shared_ready():
 b=P/'actions/light_1';r={k:Image.open(b/f'{k}_00.png').convert('RGBA') for k in ['body_canvas','weapon','composite']};r.update(fx_back=empty(),fx_front=empty(),record=dict(source='shared_light_1_ready',head_scale=.95,foot_ground=ROOT[1],weapon_plane='shared_ready'));return r

def preview(layer,action,i,total,duration,note=''):
 bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(layer,mask=layer.getchannel('A'));d=ImageDraw.Draw(bg);d.line((0,253,W,253),fill=(68,74,82));d.text((12,12),f'HIDEYOSHI / {action} / {duration} ms',fill='white');d.text((12,280),f'{i+1:02} / {total:02}  {note}',fill=(170,180,190));return bg

def save(action,frames,durations,desc,eventmap=None,loop=False):
 D=P/'actions'/action;D.mkdir(exist_ok=True);records=[];views=[];eventmap=eventmap or {};duration=sum(durations)
 for i,(f,dur) in enumerate(zip(frames,durations)):
  for name in ['body_canvas','weapon','fx_back','fx_front','composite']:f[name].save(D/f'{name}_{i:02}.png')
  rec=f['record'].copy();rec.update(index=i,duration_ms=dur,event=eventmap.get(i));records.append(rec)
  note='hold loop' if loop else ('turn '+str(rec['turn'])+' / waist' if 'turn' in rec else 'body + katana + FX')
  views.append(preview(f['composite'],action,i,len(frames),duration,note))
 views[0].save(D/f'{action}.gif',save_all=True,append_images=views[1:],duration=durations,loop=0,disposal=2,optimize=False)
 k=next(iter(eventmap),len(frames)//2);views[k].save(D/'representative.png');frames[k]['composite'].save(D/'representative_rgba.png')
 cols=4;rows=math.ceil(len(views)/cols);cs=Image.new('RGB',(W*cols,H*rows),(42,48,56))
 for i,v in enumerate(views):cs.paste(v,(i%cols*W,i//cols*H))
 cs.save(D/'contact.png')
 md=dict(action=action,description=desc,canvas=[W,H],head_scale=.95,head_scale_method='neck-anchored original head pixels; no replacement face',duration_ms=duration,frame_count=len(frames),loopable=loop,fan='stored flat gold fan retained; no dangling bottle',layers=['body_canvas','weapon','fx_back','fx_front','composite'],frames=records,source_sha256={c['file']:hashlib.sha256((P/'actions'/c['file']).read_bytes()).hexdigest() for c in CFG.values()},limitations=['whole-body frames, not anatomical rig parts','katana uses 2.5D projection of approved weapon reference','review candidate; not runtime integrated'])
 if action=='charge_release':md.update(revolutions=2,rotation_axis='vertical through hips',blade_plane='waist horizontal; no overhead circle',contact_events=[dict(frame=i,event=e) for i,e in eventmap.items()])
 (D/'metadata.json').write_text(json.dumps(md,ensure_ascii=False,indent=2))
 g=Image.open(D/f'{action}.gif');assert g.n_frames==len(frames),(g.n_frames,len(frames));assert sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==duration
 for i in range(len(frames)):
  for name in ['body_canvas','weapon','fx_back','fx_front','composite']:
   im=Image.open(D/f'{name}_{i:02}.png');assert im.mode=='RGBA' and im.size==(W,H);assert im.getchannel('A').getextrema()[0]==0;im.load()
 print(action,len(frames),duration,D/'contact.png')

if __name__=='__main__':
 ready=[shared_ready()]+[assembled('ready',j,ang) for j,ang in [(1,112),(2,102),(3,95),(4,90),(5,90)]]
 save('charge_ready',ready,[120,110,100,100,100,150],'雙手近身收刀，雙腳逐步開馬步下沉；腰前金扇收納，刀留在腰側安全位置。')
 hold=[assembled('ready',5,90,fx='hold',phase=p) for p in [0,.25,.6,1,.75,.4,.15,0]]
 save('charge_hold',hold,[110]*8,'低馬步保持，雙手握點與腳點固定；腰部集氣提示輕微明暗循環，金扇始終收納。',loop=True)
 release=[assembled('ready',5,90)]
 order=[0,1,2,3,4,6]
 for turn in range(2):
  for step,j in enumerate(order):
   yaw=turn*360+step*60;f=assembled('release',j,yaw=yaw,fx='release',phase=yaw);f['record'].update(turn=turn+1,rotation_progress_degrees=yaw);release.append(f)
 f=assembled('release',0,yaw=720,fx='release',phase=720);f['record'].update(turn=2,rotation_progress_degrees=720);release.append(f)
 release += [assembled('release',7,90),assembled('release',5,100),shared_ready()]
 save('charge_release',release,[90]+[60]*12+[80,100,110,140],'滿蓄腰部水平旋斬兩整圈；第一圈與第二圈各有獨立接觸擊飛，隨後制動並回站。',{1:'turn_1_start',6:'contact_launch_turn_1',7:'turn_2_start',12:'contact_launch_turn_2',13:'two_turns_complete'})
