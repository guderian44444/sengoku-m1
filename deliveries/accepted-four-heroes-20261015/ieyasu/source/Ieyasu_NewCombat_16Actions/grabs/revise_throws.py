from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,find_objects,binary_dilation
import numpy as np,json,copy,hashlib,math,shutil
R=Path(__file__).parent;B=R/'before_throw_expansion';B.mkdir(exist_ok=True)
if not (B/'registration.json').exists():
 shutil.copyfile(R/'registration.json',B/'registration.json')
 for n in ['throw_forward','throw_reverse']:shutil.copytree(R/n,B/n,dirs_exist_ok=True)
base=json.loads((B/'registration.json').read_text());M=json.loads((R/'registration.json').read_text())
extra={}
for n,source,cols in [('F','forward_transitions.png',3),('R','reverse_transitions_fixed.png',2)]:
 p=R/'sources'/source;im=Image.open(p).convert('RGBA');a=np.array(im.getchannel('A'));labs,c=label(a>12);bb=[];ids={}
 for j,s in enumerate(find_objects(labs)):
  if s and (labs[s]==j+1).sum()>3000:
   b=(s[1].start,s[0].start,s[1].stop,s[0].stop);bb.append(b);ids[b]=j+1
 bb.sort(key=lambda b:(0 if cols==3 else int((b[1]+b[3])/2>=im.height/2),b[0]));assert len(bb)==(3 if n=='F' else 4)
 scale=152/(bb[0][3]-bb[0][1]);extra[n]=[]
 for j,b in enumerate(bb):
  crop=im.crop(b);alpha=np.array(crop.getchannel('A'));keep=binary_dilation(labs[b[1]:b[3],b[0]:b[2]]==ids[b],iterations=2);alpha[~keep]=0;crop.putalpha(Image.fromarray(alpha));feet=np.argwhere(alpha[-int(alpha.shape[0]*.15):]>100);footx=(feet[:,1].min()+feet[:,1].max())/2
  ox=round(150-footx*scale);oy=round(220-(crop.height-1)*scale);crop=crop.resize((round(crop.width*scale),round(crop.height*scale)),Image.Resampling.LANCZOS);frame=Image.new('RGBA',(480,280));frame.alpha_composite(crop,(ox,oy))
  extra[n].append((frame,{'source':'sources/'+source,'source_crop':b,'scale':scale,'translation':[ox-b[0]*scale,oy-b[1]*scale],'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'new_transition':True,'transition_source_frame':j,'body_height':152}))
seqs={'throw_forward':[0,1,2,3,('F',0),4,5,('F',1),6,7,('F',2),8,9],'throw_reverse':[0,1,2,3,('R',0),('R',1),('R',2),6,7,('R',3),8,9]}
durs={'throw_forward':[100,90,80,80,70,70,70,60,60,70,70,80,100],'throw_reverse':[110,100,90,90,90,80,70,70,80,90,110,120]}
for name,seq in seqs.items():
 assert sum(durs[name])==(1000 if name=='throw_forward' else 1100)
 a=copy.deepcopy(base[name]);a['frames']=[];a['count']=len(seq);a['revision']='13/12 frame genuine transition expansion';frames=[]
 for i,ref in enumerate(seq):
  if isinstance(ref,int):
   frame=Image.open(B/name/f'body_{ref:02}.png').convert('RGBA');f=copy.deepcopy(base[name]['frames'][ref]);f['baseline_frame']=ref
  else:frame,f=extra[ref[0]][ref[1]];frame=frame.copy();f=copy.deepcopy(f)
  # Lock the left supporting toe during loaded left-facing reversal; shift entire pose only for registration, never as new motion.
  shift=0
  if name=='throw_reverse' and i>=3:
   arr=np.array(frame.getchannel('A'));yy,xx=np.where(arr[:,:150]>100);floor=yy.max();fx=round(float(np.median(xx[yy>=floor-2])));shift=94-fx;canvas=Image.new('RGBA',frame.size);canvas.alpha_composite(frame,(shift,0));frame=canvas
  f.update(frame=i,duration_ms=durs[name][i],registration_shift_x=shift,root=[150+shift,220]);frame.save(R/name/f'body_{i:02}.png');frames.append(frame);a['frames'].append(f)
 a['duration_ms']=sum(durs[name]);a['playback_loop']='one-shot; left-facing throw recovery must not snap directly to right-facing grab';M[name]=a
 sheet=Image.new('RGB',(1440,280*math.ceil(len(frames)/3)),(78,88,99));d=ImageDraw.Draw(sheet)
 for i,frame in enumerate(frames):sheet.paste(frame,(i%3*480,i//3*280),frame);d.text((i%3*480+8,i//3*280+8),f'{name} {i+1}',fill='white')
 sheet.resize((960,187*math.ceil(len(frames)/3))).save(R/name/'contact_body.jpg')
(R/'registration.json').write_text(json.dumps(M,indent=2))
