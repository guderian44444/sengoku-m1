from PIL import Image,ImageDraw
from pathlib import Path
import numpy as np,math,json,hashlib
from scipy.ndimage import label,find_objects
from build import CFG
from head_scale import HEADS,shrink_head
P=Path(__file__).resolve().parents[1];D=P/'actions/heavy_step_v3';D.mkdir(exist_ok=True)
W,H=520,300;sw=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
def pieces(path):
 im=Image.open(path).convert('RGBA');a=np.array(im);l,n=label(a[:,:,3]>20);out=[]
 if path.name=='heavy_step_source.png':
  yy,xx=np.indices(l.shape);l[(l==8)&(xx>=436)]=n+1
 for idx,s in enumerate(find_objects(l)):
  if s is None: continue
  if (l[s]==idx+1).sum()>3000:
   b=a[s].copy();b[:,:,3]=np.where(l[s]==idx+1,b[:,:,3],0);out.append(((s[1].start,s[0].start,s[1].stop,s[0].stop),Image.fromarray(b)))
 return im,sorted(out,key=lambda q:((q[0][1]+q[0][3])/2>im.height/2,q[0][0]))
def original(action,j):
 if action=='light_1':
  b=P/'reference/shared_ready';m=json.loads((b/'metadata.json').read_text())['frames'][0]
  return Image.open(b/'body_canvas_00.png').convert('RGBA'),tuple(m['grip_world']),{'shared_ready':True,'head_scale':.95}
 im,objs=pieces(P/'actions'/f'{action}_source.png');box,b=objs[j];fx,fy=im.width/1152,im.height/768;b=shrink_head(b,box,HEADS[action][j],fx,fy,.95);sc=.425/fy;hx,hy=CFG[action]['hands'][j];px,py=CFG[action]['feet'][j];ox=220-px*fx*sc;oy=250-py*fy*sc;can=Image.new('RGBA',(W,H));can.alpha_composite(b.resize((round(b.width*sc),round(b.height*sc)),Image.Resampling.LANCZOS),(round(ox+box[0]*sc),round(oy+box[1]*sc)));return can,(ox+hx*fx*sc,oy+hy*fy*sc),{'source':str(P/'actions'/f'{action}_source.png'),'source_rect':box,'head_scale':.95,'source_pose':j}
def sword(grip,angle,roll):
 t=math.radians(angle);co,si=math.cos(t),math.sin(t);s=.145;gx,gy=grip;ax,ay=180,710
 return sw.transform((W,H),Image.Transform.AFFINE,(co/(s*roll),si/(s*roll),ax-(co*gx+si*gy)/(s*roll),-si/s,co/s,ay+(si*gx-co*gy)/s),Image.Resampling.BICUBIC)
# Wrists are new image-generated poses; positions measured after inspecting source.
def wrist(j):
 im,objs=pieces(P/'actions/heavy_wrist_source.png');box,b=objs[j];cfg=json.loads((P/'actions/heavy_wrist_landmarks.json').read_text())[j];hx,hy=cfg['grip'];px,py=cfg['foot'];hs=cfg['head'];sc=cfg['scale'];b=shrink_head(b,box,hs,1,1,.95);ox=220-px*sc;oy=250-py*sc;can=Image.new('RGBA',(W,H));can.alpha_composite(b.resize((round(b.width*sc),round(b.height*sc)),Image.Resampling.LANCZOS),(round(ox+box[0]*sc),round(oy+box[1]*sc)));return can,(ox+hx*sc,oy+hy*sc),{'source':str(P/'actions/heavy_wrist_source.png'),'source_rect':box,'head_scale':.95,'source_pose':j,'new_wrist_pose':True}

def step(j,advance=0):
 im,objs=pieces(P/'actions/heavy_step_source.png');box,b=objs[j]
 heads=[(165,48,260,155),(550,65,645,170),(918,70,1016,172),(1300,67,1414,168),(225,553,326,634),(596,542,690,630),(966,549,1064,651),(1295,544,1399,653)]
 hands=[(163,293),(523,293),(874,273),(1476,224),(402,581),(741,538),(950,760),(1322,778)]
 feet=[(64,477),(448,475),(835,478),(1150,478),(36,954),(464,962),(860,963),(1230,963)]
 b=shrink_head(b,box,heads[j],1,1,.95);sc=.31875;hx,hy=hands[j];px,py=feet[j]
 ox=170+advance-px*sc;oy=250-py*sc
 can=Image.new('RGBA',(W,H));can.alpha_composite(b.resize((round(b.width*sc),round(b.height*sc)),Image.Resampling.LANCZOS),(round(ox+box[0]*sc),round(oy+box[1]*sc)))
 return can,(ox+hx*sc,oy+hy*sc),{'source':str(P/'actions/heavy_step_source.png'),'source_rect':box,'head_scale':.95,'source_pose':j,'root_advance':advance}

def build():
 stages=[('ready',original('light_1',0),120,1,100),('wrist_half_turn',wrist(0),115,.16,80),('edge_up_set',wrist(1),115,-1,80),('lift_front_foot',step(2,0),115,-1,110),('plant_and_drive',step(3,6),85,-1,90),('contact',step(4,12),30,-1,80),('follow',step(5,12),0,-1,100),('recover',step(6,8),90,-1,100),('settle',step(7,2),115,-.25,100),('ready',original('light_1',0),120,1,110)]
 frames=[];records=[]
 for i,(phase,(body,grip,rec),angle,roll,dur) in enumerate(stages):
  weapon=sword(grip,angle,roll);body.save(D/f'body_{i:02}.png');weapon.save(D/f'weapon_{i:02}.png');comp=body.copy();comp.alpha_composite(weapon);x,y=map(round,grip);hand=body.crop((x-4,y-4,x+4,y+4));comp.alpha_composite(hand,(x-4,y-4));comp.save(D/f'composite_{i:02}.png');bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,251,W,251),fill=(68,74,82));dr.text((12,12),'HIDEYOSHI / heavy / edge-up / 950ms',fill='white');dr.text((12,280),f'{i+1:02}/10  {phase}',fill=(180,190,200));frames.append(bg);rec.update(index=i,phase=phase,grip_world=grip,blade_angle=angle,blade_roll_scale=roll,duration_ms=dur,blade_edge='upper/leading' if roll<0 else 'turning' if roll<.5 else 'neutral',event='contact_launch_up' if phase=='contact' else None);records.append(rec)
 ds=[r['duration_ms'] for r in records];frames[0].save(D/'heavy_edgeup.gif',save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2);frames[5].save(D/'representative.png');contact=Image.new('RGB',(W*5,H*2));[contact.paste(f,((i%5)*W,(i//5)*H)) for i,f in enumerate(frames)];contact.save(D/'contact.png');(D/'metadata.json').write_text(json.dumps(dict(action='heavy',revision='step_edgeup_v3',head_scale=.95,head_approval='approved',duration_ms=sum(ds),frames=records,description='雙手翻腕轉刃向上，抬前腳跨步踏實，後腿推地、腰肩前送上撩，刀鋒先行擊飛。'),ensure_ascii=False,indent=2));g=Image.open(D/'heavy_edgeup.gif');assert g.n_frames==10;assert sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==950
if __name__=='__main__':build()
