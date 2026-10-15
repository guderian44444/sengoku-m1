from PIL import Image,ImageDraw,ImageSequence
from pathlib import Path
import numpy as np,json,hashlib,math,shutil
from scipy.ndimage import label,find_objects,binary_dilation
R=Path(__file__).parent; W,H=800,420;FLOOR=360;S=.55
HEAD={
'grab_start_rgba':[(215,9,315,134),(779,24,881,148),(1276,26,1382,151),(216,520,326,656),(762,524,873,666),(1252,515,1368,655)],
'knee':[(204,16,309,145),(714,14,821,145),(1216,16,1327,146),(201,525,326,683),(717,519,830,663),(1207,526,1321,666)],
'throw_forward':[(229,19,327,147),(781,26,883,151),(1200,40,1324,165),(277,528,416,681),(790,542,943,707),(1254,515,1364,652)],
'throw_reverse':[(254,13,359,142),(807,16,903,144),(1222,19,1321,139),(176,503,287,645),(612,497,733,637),(1200,492,1309,627)]}
# Hand anchors, visually measured in generated source pixels.
HANDS={'grab_start_rgba':[(330,233),(985,134),(1480,130),(440,617),(849,674),(1425,621)],'knee':[(443,125),(913,128),(1456,126),(396,663),(917,642),(1425,634)],'throw_forward':[(487,126),(975,148),(1293,63),(518,687),(1017,744),(1353,733)],'throw_reverse':[(487,125),(740,91),(1220,80),(75,734),(620,784),(1118,627)]}
def getparts(n):
 im=Image.open(R/'sources'/f'{n}.png').convert('RGBA');a=np.array(im);lab,num=label(a[:,:,3]>30);q=[]
 for i,s in enumerate(find_objects(lab)):
  if s and (lab[s]==i+1).sum()>5000:
   b=[s[1].start,s[0].start,s[1].stop,s[0].stop];q.append((b,i+1))
 q.sort(key=lambda v:(v[0][1]+v[0][3])/2);q=sorted(q[:3],key=lambda v:v[0][0])+sorted(q[3:],key=lambda v:v[0][0]);out=[]
 for k,(b,cid) in enumerate(q):
  ar=a.copy(); ar[:,:,3]=np.where(binary_dilation(lab==cid,iterations=2),ar[:,:,3],0);c=Image.fromarray(ar)
  if n in HEAD:
   x0,y0,x1,y1=HEAD[n][k];mask=Image.new('L',im.size);d=ImageDraw.Draw(mask);d.polygon([(x0,y0),(x1,y0),(x1,y1-24),((x0+x1)/2+17,y1),((x0+x1)/2-17,y1),(x0,y1-25)],fill=255)
   ma=np.array(mask);orig=np.array(c);hp=orig.copy();hp[:,:,3]=np.minimum(hp[:,:,3],ma);orig[:,:,3]=np.where(ma>0,0,orig[:,:,3]);c=Image.fromarray(orig)
   # Neck anchor fixed. Local head and topknot uniformly 95%, body untouched.
   head=Image.fromarray(hp).crop((x0,y0,x1,y1));head=head.resize((round(head.width*.95),round(head.height*.95)),Image.Resampling.LANCZOS);c.alpha_composite(head,(round((x0+x1)/2-head.width/2),y1-head.height))
  c=c.crop(b);out.append((c,b))
 return out
P={n:getparts(n) for n in ['grab_start_rgba','knee','throw_forward','throw_reverse','victim']}
# Knee source frame 2 is a kick and intentionally rejected. Contact is source frame 3.
A={'grab_start':('grab_start_rgba',[0,1,2,3,5],[100,90,80,90,160]),'grab_hold':('grab_start_rgba',[5],[600]),'grab_hit_1':('knee',[0,1,3,4,5],[100,80,70,90,150]),'grab_hit_2':('knee',[0,1,3,4,5],[90,70,70,80,170]),'throw_forward':('throw_forward',[0,1,2,3,4,5,5,5],[100,90,110,70,80,90,100,180]),'throw_reverse':('throw_reverse',[0,1,2,3,4,5,5,5],[100,100,120,70,80,90,100,180])}
weapon=Image.open(R/'sources/sheathed_weapon.png').convert('RGBA').resize((30,150),Image.Resampling.LANCZOS)
M={}
for name,(src,seq,durs) in A.items():
 out=R/name;out.mkdir(exist_ok=True);frames=[];bodyframes=[];meta=[]
 for j,k in enumerate(seq):
  c,b=P[src][k]; c=c.resize((round(c.width*S),round(c.height*S)),Image.Resampling.LANCZOS)
  aa=np.array(c)[:,:,3];yy,xx=np.where(aa>80);bottom=yy.max();footxs=np.where((aa[max(0,bottom-6):bottom+1]>80).any(axis=0))[0];groups=np.split(footxs,np.where(np.diff(footxs)>10)[0]+1);groups=[g for g in groups if len(g)>2];foot=float(np.mean(groups[0]));anchor=260 if name!='throw_reverse' else 390
  
  if src=='throw_reverse': foot=([104,692,1127,184,688,1126][k]-b[0])*S
  if src=='throw_forward': foot=([147,620,1127,74,575,1178][k]-b[0])*S
  dx=round(anchor-foot);dy=int(FLOOR-bottom);body=Image.new('RGBA',(W,H));body.alpha_composite(c,(dx,dy));hand=[round((HANDS[src][k][0]-b[0])*S+dx),round((HANDS[src][k][1]-b[1])*S+dy)]
  waist=(dx+c.width*.48,dy+c.height*.48);wp=weapon.rotate(55 if name=='throw_reverse' and j>=3 else -55,expand=True,resample=Image.Resampling.BICUBIC);wl=Image.new('RGBA',(W,H));wl.alpha_composite(wp,(round(waist[0]-wp.width*.65),round(waist[1]-wp.height*.3)))
  vi=0 if name=='grab_start' and j<3 else 1;release=False;events=[]
  if name=='grab_start' and j==3:events=['grab_attach']
  if name.startswith('grab_hit') and j==2:vi=2;events=[name+'_knee_contact']
  if name.startswith('throw'):
   if j in (1,2):vi=3
   if j>=3:vi=4;release=True
   if j==3:events=['throw_release']
   if j>=7:vi=5;events=['victim_land']
  vc,vb=P['victim'][vi];vs=.55;vc=vc.resize((round(vc.width*vs),round(vc.height*vs)),Image.Resampling.LANCZOS)
  if name.startswith('throw') and j>=3:
   reverse=name=='throw_reverse';destx=(260-25*(j-3)) if reverse else (470+35*(j-3));desty=120+12*(j-3)**2
   if j>=7:desty=FLOOR-vc.height
   vx=round(destx-vc.width/2);vy=min(round(desty),FLOOR-vc.height)
  elif vi==3:vx=hand[0]-vc.width//2;vy=hand[1]-vc.height//2
  else:
   # Collar landmark on isolated generated victim. Translation only; feet are grounded.
   collar=[(38,55),(38,55),(40,65)][vi];vx=round(hand[0]-collar[0]);vy=FLOOR-vc.height
   if vi==1:vy=hand[1]-55
   if vi==2:vx=round((375-b[0])*S+dx-62);vy=round((745-b[1])*S+dy-90)
   if name=='grab_start' and j<3:vx=480
  vl=Image.new('RGBA',(W,H));vl.alpha_composite(vc,(vx,vy))
  body.save(out/f'body_{j:02}.png');wl.save(out/f'weapon_{j:02}.png');vl.save(out/f'victim_{j:02}.png')
  bg=Image.new('RGBA',(W,H),(45,50,60,255));d=ImageDraw.Draw(bg);d.line((0,FLOOR+1,W,FLOOR+1),fill=(85,95,110));d.text((15,15),f'Hideyoshi | {name} | {j+1}/{len(seq)} | head 95%',fill='white');bg.alpha_composite(vl);bg.alpha_composite(wl);bg.alpha_composite(body)
  if release:bg.alpha_composite(vl)
  frames.append(bg.convert('RGB'));bc=Image.new('RGBA',(W,H),(45,50,60,255));bc.alpha_composite(wl);bc.alpha_composite(body);bodyframes.append(bc.convert('RGB'))
  meta.append({'index':j,'source_frame':k,'source_crop':b,'scale':S,'translation':[dx,dy],'support_foot':[anchor,FLOOR],'hand_contact':hand,'hand_measurement':'manual visual source landmarks; +/- 6 source px','duration_ms':durs[j],'events':events,'head_scale':.95,'head_neck_anchor_source':[(HEAD[src][k][0]+HEAD[src][k][2])/2,HEAD[src][k][3]],'victim_pose':vi,'victim_translation':[vx,vy],'victim_released':release,'weapon':'separate sheathed back layer','yaw_deg':([0,75,180,225,180,180,180,180][j] if name=='throw_reverse' else [0,35,100,35,20,0,0,0][j] if name=='throw_forward' else 0)})
 for label,ff in [('normal',frames),('body_only',bodyframes)]:ff[0].save(out/f'{label}.gif',save_all=True,append_images=ff[1:],duration=durs,loop=0,disposal=2)
 contact=Image.new('RGB',(W*3,H*math.ceil(len(seq)/3)),(45,50,60))
 for j,fr in enumerate(frames):contact.paste(fr,(W*(j%3),H*(j//3)))
 contact.resize((1200,round(contact.height*.5))).save(out/'contact.jpg');frames[min(2,len(frames)-1)].save(out/'representative.png')
 info={'action':name,'source':f'sources/{src}.png','source_sha256':hashlib.sha256((R/'sources'/f'{src}.png').read_bytes()).hexdigest(),'head_scale':.95,'head_edit':'neck-anchored local rescale including topknot; body and feet not scaled by head edit','body_scale':S,'body_height_standing_equivalent':266,'body_height_basis':'first standing source 484 px at .55; constant factor for every action','frames':meta,'duration_ms':sum(durs),'runtime_loop':name=='grab_hold','limitations':['Keyframe animation without interpolation.','Hand contacts are approximate visual annotations, not engine collision registration.','Neutral victim is a separate generated preview actor.','Not runtime integrated.']};(out/'metadata.json').write_text(json.dumps(info,indent=2));M[name]=info
(R/'manifest.json').write_text(json.dumps(M,indent=2));(R/'preview.html').write_text('<body style="background:#333;color:white">'+''.join(f'<h3>{n}</h3><img src="{n}/normal.gif"><img src="{n}/body_only.gif">' for n in M))
print('Built',list(M))
