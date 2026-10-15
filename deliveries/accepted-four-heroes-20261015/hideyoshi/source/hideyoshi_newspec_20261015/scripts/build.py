from PIL import Image,ImageDraw
from pathlib import Path
import numpy as np,json,math,hashlib
from scipy.ndimage import label,find_objects
from head_scale import HEADS,shrink_head
P=Path(__file__).resolve().parents[1]
CFG={
'light_1':dict(hands=[(145,165),(416,31),(716,32),(1094,232),(291,587),(565,596),(747,573),(145,165)],feet=[(240,360),(326,371),(843,372),(1129,371),(308,730),(535,731),(822,730),(240,360)],angles=[120,-25,-20,80,120,125,125,120],dur=[90,70,60,50,80,70,70,100],desc='後腳承重舉刀、前跨落地，雙手下切時肩背胸與重心一同向前下方跟進，再跟步回正。',event='contact_push',hit=4),
'light_2':dict(hands=[(125,177),(385,169),(684,169),(1095,165),(273,500),(539,499),(758,571),(125,177)],feet=[(216,369),(546,373),(841,372),(1126,372),(272,750),(546,749),(828,749),(216,369)],angles=[120,-90,-90,90,90,90,105,120],lengths=[1,1,1,.4,1,.65,.8,1],dur=[90,70,60,50,80,70,70,100],desc='雙手由腰側蓄勢，前跨轉髖帶胸肩水平橫斬，側背隨刀旋轉後收勢。',event='contact_push',hit=4),
'light_3':dict(hands=[(109,186),(362,53),(622,116),(1102,128),(329,491),(596,497),(682,533),(109,186)],feet=[(216,375),(569,375),(841,372),(1124,365),(286,735),(605,730),(875,739),(216,375)],angles=[120,-30,-65,45,85,110,130,120],dur=[90,100,70,60,90,80,80,110],desc='雙手持刀跨步轉髖大幅橫掃，肩背帶動最大揮幅，接觸擊飛後制動回正。',event='contact_launch',hit=4),
'air_light':dict(hands=[(97,97),(423,243),(684,29),(1064,176),(277,517),(418,533),(690,610),(97,97)],feet=[(249,378),(499,364),(734,344),(939,352),(261,750),(407,694),(780,733),(249,378)],air=[0,0,55,75,55,25,0,0],angles=[120,120,-30,60,90,125,120,120],dur=[70,80,80,60,70,70,90,100],desc='起跳收腿後雙手近身揮刀，空中接觸，隨動下降落地；判定攻擊與範圍各加20%。',event='air_contact',hit=4),
'air_heavy':dict(hands=[(132,194),(418,239),(693,30),(994,28),(226,571),(471,635),(749,615),(132,194)],feet=[(258,380),(533,377),(719,339),(997,341),(292,731),(564,731),(817,716),(258,380)],air=[0,0,60,75,40,0,0,0],angles=[120,125,-20,-15,100,120,115,120],dur=[80,90,100,80,60,100,90,100],desc='雙手舉刀起跳，下墜時快速下劈，馬步重落地；接觸擊倒，攻擊與範圍各加30%。',event='air_contact_knockdown',hit=4),
'dash_heavy':dict(hands=[(144,195),(401,216),(661,184),(1107,177),(318,502),(553,535),(789,531),(144,195)],feet=[(138,324),(565,348),(824,345),(1120,350),(328,712),(605,717),(841,717),(138,324)],angles=[-70,-65,-45,50,85,110,120,120],dur=[60,70,70,50,70,80,80,100],desc='奔跑末步壓低重心，雙手快速前橫掃，再以前腳制動回站；一般敵人接觸擊飛。',event='dash_contact_launch',hit=4),
'heavy':dict(hands=[(63,162),(396,206),(694,239),(1111,155),(244,438),(511,400),(698,560),(63,162)],feet=[(219,358),(537,354),(833,353),(1101,353),(266,724),(537,723),(830,721),(219,358)],angles=[45,115,115,85,30,0,110,45],dur=[100,110,140,70,70,90,110,100],desc='雙手低位持刀下沉蓄勢，再由腿、腰肩帶動往前上揮，接觸擊飛。',event='contact_launch_up',hit=4)
}
def build(action):
 c=CFG[action];D=P/'actions'/action;D.mkdir(exist_ok=True);src=P/'actions'/f'{action}_source.png';im=Image.open(src).convert('RGBA');arr=np.array(im);labs,n=label(arr[:,:,3]>20);objs=[]
 for j,s in enumerate(find_objects(labs)):
  if (labs[s]==j+1).sum()>3000: objs.append((j+1,s))
 if action=='dash_heavy' and len(objs)==7:
  old=9
  yy,xx=np.indices(labs.shape)
  # The two lower actors touch only at shoe edges near x455/y938.
  boundary=450+np.maximum(yy-925,0)*0.65
  labs[(labs==old)&(xx>boundary)]=n+1
  objs=[]
  for ident in np.unique(labs):
   if ident and (labs==ident).sum()>3000:
    ys,xs=np.where(labs==ident);objs.append((ident,(slice(ys.min(),ys.max()+1),slice(xs.min(),xs.max()+1))))
 objs=sorted(objs,key=lambda q:((q[1][0].start+q[1][0].stop)/2>im.height/2,q[1][1].start))
 assert len(objs)==8,(action,len(objs))
 extra=80 if action.startswith('air') else 0; W,H=520,300+extra; sword=Image.open(P/'reference/sword_uchigatana.png').convert('RGBA');frames=[];records=[]
 for i in range(8):
  j=c.get("order",[0,1,2,3,4,5,6,0])[i];idx,s=objs[j];box=(s[1].start,s[0].start,s[1].stop,s[0].stop);a=arr[s].copy();a[:,:,3]=np.where(labs[s]==idx,a[:,:,3],0);body=Image.fromarray(a)
  if action=='dash_heavy':
   bl,bn=label(a[:,:,3]>20);sizes=np.bincount(bl.ravel());sizes[0]=0;a[:,:,3]=np.where(bl==sizes.argmax(),a[:,:,3],0);body=Image.fromarray(a)
  if action in HEADS: body=shrink_head(body,box,HEADS[action][j],im.width/1152,im.height/768)
  body.save(D/f'body_{i:02}.png');factor=im.width/1152;factor_y=im.height/768;ss=.425/factor_y;fx,fy=c['feet'][i];gx,gy=c['hands'][i];rootx=220+(9*(int(action[-1])-1)+min(i,3)*3 if action.startswith('light') else 0);rooty=250+extra-c.get('air',[0]*8)[i]
  ox=rootx-fx*factor*ss;oy=rooty-fy*factor_y*ss;canvas=Image.new('RGBA',(W,H));tile=body.resize((round(body.width*ss),round(body.height*ss)),Image.Resampling.LANCZOS);canvas.alpha_composite(tile,(round(ox+box[0]*ss),round(oy+box[1]*ss)));canvas.save(D/f'body_canvas_{i:02}.png')
  grip=(ox+gx*factor*ss,oy+gy*factor_y*ss);ang=c['angles'][i];t=math.radians(ang);ws=.145;co=math.cos(t)/ws;si=math.sin(t)/ws;ax,ay=180,710;px,py=grip; length=c.get('lengths',[1]*8)[i]
  wl=sword.transform((W,H),Image.Transform.AFFINE,(co,si,ax-co*px-si*py,-si/length,co/length,ay+(si*px-co*py)/length),Image.Resampling.BICUBIC);wl.save(D/f'weapon_{i:02}.png');comp=canvas.copy();comp.alpha_composite(wl)
  # tight fist mask above grip; never entire forearm
  crop=(round(gx*factor-10),round(gy*factor_y-10),round(gx*factor+10),round(gy*factor_y+10));hand=im.crop(crop).resize((round(20*ss),round(20*ss)),Image.Resampling.LANCZOS);comp.alpha_composite(hand,(round(px-10*ss),round(py-10*ss)));comp.save(D/f'composite_{i:02}.png')
  if (action in ['light_1','light_2','light_3','heavy','air_light','air_heavy'] and i in [0,7]) or (action=='dash_heavy' and i==7):
   base=P/'actions/light_1'; k=7 if action.startswith('light') else 0; delta=0 if not action.startswith('light') else 9*(int(action[-1])-2+(i==7))
   if action=='light_1':base=P/'reference/shared_ready';k=0;delta=0
   for layername in ['body_canvas','weapon','composite']:
    z=Image.open(base/f'{layername}_{k:02}.png'); out=Image.new('RGBA',(W,H)); out.alpha_composite(z,(delta,extra)); out.save(D/f'{layername}_{i:02}.png')
   comp=Image.open(D/f'composite_{i:02}.png')
  bg=Image.new('RGB',(W,H),(42,48,56));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,251+extra,W,251+extra),fill=(68,74,82));dr.text((12,12),f'HIDEYOSHI / {action} / {sum(c["dur"])} ms',fill='white');dr.text((12,280+extra),f'{i+1:02} / 08 - separate body + katana',fill=(170,180,190));frames.append(bg)
  records.append(dict(index=i,source_rect=box,source_component=idx,body_scale=ss,root=[rootx,rooty],source_grip=[gx*factor,gy*factor_y],grip_world=grip,weapon_angle=ang,weapon_angle_convention='0 up, clockwise positive',duration_ms=c['dur'][i],event=c['event'] if i==c['hit'] else None))
 frames[0].save(D/f'{action}.gif',save_all=True,append_images=frames[1:],duration=c['dur'],loop=0,disposal=2);frames[c['hit']].save(D/'representative.png');cs=Image.new('RGB',(W*4,H*2));[cs.paste(f,((i%4)*W,(i//4)*H)) for i,f in enumerate(frames)];cs.save(D/'contact.png');data=dict(head_scale=0.95,action=action,description=c['desc'],duration_ms=sum(c['dur']),frames=records,source_sha256=hashlib.sha256(src.read_bytes()).hexdigest(),limitations=['whole-body transparent frames, not anatomical rig parts','katana flat rotation; perspective variants pending','not runtime integrated']);(D/'metadata.json').write_text(json.dumps(data,ensure_ascii=False,indent=2,default=int));g=Image.open(D/f'{action}.gif');assert g.n_frames==8;assert sum((g.seek(i) or g.info['duration']) for i in range(g.n_frames))==sum(c['dur'])
if __name__=='__main__':
 import sys
 for a in sys.argv[1:] or CFG: build(a)
