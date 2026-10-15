from PIL import Image,ImageDraw
from pathlib import Path
import numpy as np,math,json,hashlib
from scipy.ndimage import label,find_objects
from build import CFG
from head_scale import HEADS,shrink_head
P=Path(__file__).resolve().parents[1];D=P/'actions/heavy_edgeup_v2';D.mkdir(exist_ok=True)
W,H=520,300;sw=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA')
def pieces(path):
 im=Image.open(path).convert('RGBA');a=np.array(im);l,n=label(a[:,:,3]>20);out=[]
 for idx,s in enumerate(find_objects(l)):
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
def build():
 stages=[('ready',original('light_1',0),120,1,100),('low_neutral',original('heavy',1),115,1,110),('wrist_half_turn',wrist(0),115,.16,80),('edge_up_set',wrist(1),115,-1,80),('load',original('heavy',2),115,-1,140),('rise',original('heavy',3),85,-1,70),('contact',original('heavy',4),30,-1,70),('follow',original('heavy',5),0,-1,90),('recover',original('heavy',6),110,-.25,110),('ready',original('light_1',0),120,1,100)]
 frames=[];records=[]
 for i,(phase,(body,grip,rec),angle,roll,dur) in enumerate(stages):
  weapon=sword(grip,angle,roll);body.save(D/f'body_{i:02}.png');weapon.save(D/f'weapon_{i:02}.png');comp=body.copy();comp.alpha_composite(weapon);x,y=map(round,grip);hand=body.crop((x-4,y-4,x+4,y+4));comp.alpha_composite(hand,(x-4,y-4));comp.save(D/f'composite_{i:02}.png');bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,251,W,251),fill=(68,74,82));dr.text((12,12),'HIDEYOSHI / heavy / edge-up / 950ms',fill='white');dr.text((12,280),f'{i+1:02}/10  {phase}',fill=(180,190,200));frames.append(bg);rec.update(index=i,phase=phase,grip_world=grip,blade_angle=angle,blade_roll_scale=roll,duration_ms=dur,blade_edge='upper/leading' if roll<0 else 'turning' if roll<.5 else 'neutral',event='contact_launch_up' if phase=='contact' else None);records.append(rec)
 ds=[r['duration_ms'] for r in records];frames[0].save(D/'heavy_edgeup.gif',save_all=True,append_images=frames[1:],duration=ds,loop=0,disposal=2);frames[6].save(D/'representative.png');contact=Image.new('RGB',(W*5,H*2));[contact.paste(f,((i%5)*W,(i//5)*H)) for i,f in enumerate(frames)];contact.save(D/'contact.png');(D/'metadata.json').write_text(json.dumps(dict(action='heavy',revision='edgeup_v2',head_scale=.95,head_approval='candidate_pending',duration_ms=sum(ds),frames=records,description='雙手低位持刀，明確翻腕轉刃向上後，再下沉上撩；刀鋒先行，接觸擊飛。'),ensure_ascii=False,indent=2));g=Image.open(D/'heavy_edgeup.gif');assert g.n_frames==10;assert sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==950
if __name__=='__main__':build()
