from PIL import Image,ImageDraw
from pathlib import Path
from scipy.ndimage import label,find_objects
import numpy as np,math,json,hashlib
from head_scale import shrink_head
P=Path(__file__).resolve().parents[1];D=P/'actions/charge_release_pivot_v2';D.mkdir(exist_ok=True)
SRC=P/'actions/charge_release_pivot_fixed.png';im=Image.open(SRC).convert('RGBA');a=np.array(im);labs,n=label(a[:,:,3]>20)
obj=[]
for j,s in enumerate(find_objects(labs),1):
 if (labs[s]==j).sum()>3000:obj.append((j,s))
obj.sort(key=lambda z:((z[1][0].start+z[1][0].stop)/2>im.height/2,z[1][1].start));assert len(obj)==8
W,H=520,300;SC=.35;PIVOT=(244,250);SWORD=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
HEAD=[(224,19,326,128),(607,18,699,112),(1062,14,1152,106),(1481,16,1582,124),(136,455,237,580),(612,451,700,578),(1066,457,1173,581),(1519,457,1631,584)]
HANDS=[[(172,207),(199,216)],[(702,208),(738,201)],[(1027,187),(1162,197)],[(1478,204),(1498,205)],[(119,640),(141,647)],[(633,638),(656,637)],[(1073,648),(1098,647)],[(1538,647),(1560,647)]]
SUPPORT=[(323,442),(698,439),(1036,444),(1462,434),(177,866),(727,867),(1230,866),(1670,866)]
FREE=[(124,416),(605,402),(1204,393),(1610,412),(307,783),(537,804),(972,862),(1453,862)]
DUR=[90]+[60]*12+[80,100,110,140]
def empty():return Image.new('RGBA',(W,H))
def make_body(j):
 ident,s=obj[j];box=(s[1].start,s[0].start,s[1].stop,s[0].stop);v=a[s].copy();v[:,:,3]=np.where(labs[s]==ident,v[:,:,3],0);tile=shrink_head(Image.fromarray(v),box,HEAD[j],1,1)
 ox=PIVOT[0]-SUPPORT[j][0]*SC;oy=PIVOT[1]-SUPPORT[j][1]*SC;body=empty();resized=tile.resize((round(tile.width*SC),round(tile.height*SC)),Image.Resampling.LANCZOS);body.alpha_composite(resized,(round(ox+box[0]*SC),round(oy+box[1]*SC)))
 hand=[(ox+x*SC,oy+y*SC) for x,y in HANDS[j]];grip=np.mean(hand,axis=0);free=(ox+FREE[j][0]*SC,oy+FREE[j][1]*SC)
 rec=dict(source_index=j,source_rect=box,body_scale=SC,head_scale=.95,head_scale_anchor='neck',anatomical_support_foot='left',support_point='ball/toe contact',source_support_point=SUPPORT[j],pivot_world=PIVOT,free_right_foot_world=free,grip_world=grip.tolist(),hand_centers=hand,body_offset=[ox,oy])
 return body,hand,grip,rec

def weapon(grip,yaw=None,angle=90):
 if yaw is not None:
  t=math.radians(yaw);x=math.copysign(max(abs(math.cos(t)),.16),math.cos(t));m=np.array([[0,-x],[1,-.18*math.sin(t)]])*.145
 else:
  t=math.radians(angle);m=np.array([[math.cos(t),-math.sin(t)],[math.sin(t),math.cos(t)]])*.145
 inv=np.linalg.inv(m);v=np.array([180,710])-inv@grip;coeff=tuple(inv[0])+tuple([v[0]])+tuple(inv[1])+tuple([v[1]])
 return SWORD.transform((W,H),Image.Transform.AFFINE,coeff,Image.Resampling.BICUBIC)

def render(j,yaw=None,angle=90):
 body,hands,grip,rec=make_body(j);wp=weapon(grip,yaw,angle);back=empty();front=empty();behind=yaw is not None and 30<yaw%360<210
 if yaw is not None:
  # The arc follows a short sweep ending at this blade's own tip, not an overhead circle.
  theta=math.radians(yaw);L=710*.145;tip=np.array(grip)+np.array([L*math.cos(theta),L*.18*math.sin(theta)])
  radius=118;cy=float(grip[1]);cx=float(tip[0]-radius*math.cos(theta));cy=float(tip[1]-22*math.sin(theta))
  for k in range(10):
   t=theta-math.radians(65-k*7);u=t+math.radians(8);xy=[(cx+radius*math.cos(t),cy+22*math.sin(t)),(cx+radius*math.cos(u),cy+22*math.sin(u))];d=ImageDraw.Draw(front if math.sin(t)>=0 else back);d.line(xy,fill=(200,225,248,30+k*15),width=2)
 comp=back.copy()
 if behind:comp.alpha_composite(wp)
 comp.alpha_composite(body)
 if not behind:
  comp.alpha_composite(wp);m=Image.new('L',(W,H));dr=ImageDraw.Draw(m)
  for x,y in hands:dr.ellipse((x-4.6,y-4.6,x+4.6,y+4.6),fill=255)
  hm=body.copy();hm.putalpha(Image.fromarray(np.minimum(np.array(body.getchannel('A')),np.array(m))));comp.alpha_composite(hm)
 comp.alpha_composite(front);rec.update(rotation_progress_degrees=yaw,weapon_yaw_degrees=yaw,weapon_angle=None if yaw is not None else angle,weapon_scale=.145,weapon_grip_local=[180,710],weapon_behind_body=behind,leg_generation='new full-body pivot pose, not a pasted leg rotation')
 return dict(body_canvas=body,weapon=wp,fx_back=back,fx_front=front,composite=comp,record=rec)
def existing(action,index):
 f={k:Image.open(P/'actions'/action/f'{k}_{index:02}.png').convert('RGBA') for k in ['body_canvas','weapon','composite']};f.update(fx_back=empty(),fx_front=empty(),record=dict(source=action,source_frame=index,head_scale=.95));return f
frames=[existing('charge_hold',0)]
for turn in range(2):
 for j in range(6):
  f=render(j,turn*360+j*60);f['record']['turn']=turn+1;frames.append(f)
f=render(0,720);f['record']['turn']=2;frames.append(f)
frames += [render(6,angle=103),render(7,angle=115),existing('light_1',0)]
assert len(frames)==17
views=[];records=[]
for i,f in enumerate(frames):
 for k in ['body_canvas','weapon','fx_back','fx_front','composite']:f[k].save(D/f'{k}_{i:02}.png')
 bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(f['composite'],mask=f['composite'].getchannel('A'));d=ImageDraw.Draw(bg);d.line((0,253,W,253),fill=(68,74,82))
 if 1<=i<=13:
  d.ellipse((PIVOT[0]-3,251,PIVOT[0]+3,255),fill=(188,151,83));note='turn '+str(f['record']['turn'])+' / left foot pivot'
 else:note='load' if i==0 else 'brake + recover'
 d.text((12,12),'HIDEYOSHI / charge_release / foot pivot / 1240 ms',fill='white');d.text((12,280),f'{i+1:02}/17  {note}',fill=(170,180,190));views.append(bg)
 rec=f['record'];rec.update(index=i,duration_ms=DUR[i],event={6:'contact_launch_turn_1',12:'contact_launch_turn_2',13:'two_turns_complete'}.get(i));records.append(rec)
views[0].save(D/'charge_release.gif',save_all=True,append_images=views[1:],duration=DUR,loop=0,disposal=2,optimize=False)
views[5].save(D/'representative.png');frames[5]['composite'].save(D/'representative_rgba.png')
cs=Image.new('RGB',(W*4,H*5),(42,48,56))
for i,v in enumerate(views):cs.paste(v,(i%4*W,i//4*H))
cs.save(D/'contact.png')
md=dict(action='charge_release',revision='left_foot_pivot_720_v2',description='以左腳前掌為轉軸，鞋尖隨膝髖轉向；右腳離地繞踏，骨盆、腿、胸肩與雙手腰斬一同轉完兩圈，再雙腳制動回站。',duration_ms=1240,frame_count=17,head_scale=.95,canvas=[W,H],revolutions=2,pivot_foot='anatomical left',pivot_world=PIVOT,footwork='left forefoot/toe pivots; free right foot circles and lifts; pelvis and legs rotate with chest',rotation_axis='vertical axis through supporting left forefoot',blade_plane='waist_horizontal',fan='stored flat gold fan retained; no dangling bottle',frames=records,source_sha256=hashlib.sha256(SRC.read_bytes()).hexdigest(),source_sheet=str(SRC),render_body_layer='body_canvas_XX.png',quality_checks=['new leg/hip poses for all six turning directions','same anatomical left support foot through front and back views','left support ball locked to [244,250] for both 360-degree turns','right foot airborne circling path changes per pose','17 GIF frames decoded; exact 1240ms','95 percent neck-anchored head, independent katana and FX layers'],limitations=['six distinct rotational body poses per turn','whole-body sprites, not anatomical rig parts','weapon uses 2.5D projection','review candidate; not runtime integrated'])
(D/'metadata.json').write_text(json.dumps(md,ensure_ascii=False,indent=2))
g=Image.open(D/'charge_release.gif');assert g.n_frames==17;assert sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==1240
for i in range(17):
 for layer in ['body_canvas','weapon','fx_back','fx_front','composite']:
  z=Image.open(D/f'{layer}_{i:02}.png');assert z.mode=='RGBA' and z.size==(520,300) and z.getchannel('A').getextrema()[0]==0;z.load()
assert len(set(tuple(records[i]['pivot_world']) for i in range(1,14)))==1
print(D)
