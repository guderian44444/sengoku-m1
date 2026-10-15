from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,hashlib,math
from scipy.ndimage import label,find_objects,binary_dilation
ROOT=Path(__file__).parent
ACTIONS={'grab_start':[100]*6,'grab_hold':[100]*6,'grab_hit_1':[100,120,70,70,100,140],'grab_hit_2':[100,120,70,70,100,140],'throw_forward':[120,120,100,100,100,70,70,100,100,120],'throw_reverse':[120,120,100,120,110,80,70,100,130,150]}
meta={}
for name,durs in ACTIONS.items():
 if not (ROOT/'sources'/f'{name}.png').exists():continue
 im=Image.open(ROOT/'sources'/f'{name}.png').convert('RGBA');a=np.array(im.getchannel('A'));lab,n=label(a>12);objs=find_objects(lab);boxes=[]; component_ids={}
 for i,s in enumerate(objs):
  if s is not None and np.count_nonzero(lab[s]==i+1)>3000:
   b=(s[1].start,s[0].start,s[1].stop,s[0].stop);boxes.append(b);component_ids[b]=i+1
 boxes.sort(key=lambda b:(round(b[1]/(im.height/2)),b[0]))
 print(name,len(boxes),boxes)
 if len(boxes)!=len(durs):raise ValueError(name)
 scale=152/(boxes[0][3]-boxes[0][1]);out=ROOT/name;out.mkdir(exist_ok=True);frames=[];fm=[]
 for i,b in enumerate(boxes):
  crop=im.crop(b);aa=np.array(crop.getchannel('A'));mask=binary_dilation(lab[b[1]:b[3],b[0]:b[2]]==component_ids[b],iterations=2);aa[~mask]=0;crop.putalpha(Image.fromarray(aa));feet=np.argwhere(aa[-int(aa.shape[0]*.15):]>100);footx=float((feet[:,1].min()+feet[:,1].max())/2);ground=b[3]-b[1]-1
  sz=(round(crop.width*scale),round(crop.height*scale));crop=crop.resize(sz,Image.Resampling.LANCZOS)
  ox=round(150-footx*scale);oy=round(220-ground*scale)
  frame=Image.new('RGBA',(480,280));frame.alpha_composite(crop,(ox,oy));frame.save(out/f'body_{i:02}.png');frames.append(frame)
  fm.append({'frame':i,'source_crop':b,'scale':scale,'translation':[ox-b[0]*scale,oy-b[1]*scale],'root':[150,220],'support':'both feet / pivot as pose','right_hand':None,'left_hand':None,'duration_ms':durs[i],'weapon_state':'sheathed separate layer'})
 contact=Image.new('RGB',(480*3,280*math.ceil(len(frames)/3)),(78,88,99));d=ImageDraw.Draw(contact)
 for i,f in enumerate(frames):contact.paste(f,(i%3*480,i//3*280),f);d.text((i%3*480+8,i//3*280+8),f'{name} {i}',fill='white')
 contact.resize((960,187*math.ceil(len(frames)/3))).save(out/'contact_body.jpg')
 meta[name]={'source':f'sources/{name}.png','source_sha256':hashlib.sha256((ROOT/'sources'/f'{name}.png').read_bytes()).hexdigest(),'body_height':152,'body_height_basis':'first full standing-equivalent pose, fixed scale per source; crouch frames not individually scaled','duration_ms':sum(durs),'frames':fm,'count':len(frames)}
(ROOT/'registration.json').write_text(json.dumps(meta,indent=2))
