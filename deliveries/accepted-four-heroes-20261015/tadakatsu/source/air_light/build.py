from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
import numpy as np,json,math,hashlib
ROOT=Path(__file__).resolve().parent
W,H=640,340; FLOOR=296
LAYERS=['character','weapon_back','weapon_front','hand_occlusion','composite']
DUR=[70,50,50,50,50,50,70,50,60,60,70,90]
POSES=[
 ('A',0,[320,335],[300,180],[293,385],'forward_guard'),
 ('A',1,[808,333],[304,168],[767,872],'tighten_grip'),
 ('A',2,[1322,335],[308,158],[1331,1447],'forward_push_start'),
 ('A',3,[323,813],[312,151],[343,473],'forward_thrust_acceleration'),
 ('A',4,[835,809],[316,148],[879,992],'forward_thrust_extend'),
 ('A',5,[1340,804],[320,148],[1393,1498],'near_full_reach'),
 ('B',0,[325,300],[324,151],[435,541],'forward_thrust_contact_preview'),
 ('B',1,[835,310],[328,157],[877,996],'early_withdrawal'),
 ('B',2,[1333,334],[332,166],[1323,1432],'mid_withdrawal'),
 ('B',3,[355,785],[336,178],[357,434],'late_withdrawal'),
 ('B',4,[840,791],[340,190],[841,912],'forward_guard_return'),
 ('B',5,[1333,797],[344,200],[1328,1388],'airborne_descent_exit')]
SCALE={'A':.43,'B':.43}
GUIDE_Y=[270,270,264,733,732,733,225,231,238,706,706,706]
def largest(im):
 a=np.array(im.convert('RGBA'));l,n=ndi.label(a[:,:,3]>=96);c=np.bincount(l.ravel());c[0]=0;k=ndi.binary_dilation(l==c.argmax(),iterations=2);a[:,:,3]=np.where(k&(a[:,:,3]>=10),a[:,:,3],0);return Image.fromarray(a)
def load_sheet(letter):
 a=np.array(Image.open(ROOT/f'source-{letter}.png').convert('RGBA'));l,n=ndi.label(a[:,:,3]>=96);parts=[]
 for k,sl in enumerate(ndi.find_objects(l)):
  if (l[sl]==k+1).sum()>5000:parts.append((sl[0].start//512,sl[1].start,k+1))
 parts.sort();assert len(parts)==6,(letter,parts)
 return a,l,[p[2]for p in parts]
def build():
 for d in LAYERS+['source_crops']:(ROOT/d).mkdir(exist_ok=True)
 sheets={k:load_sheet(k)for k in SCALE};spear=largest(Image.open(ROOT/'spear_suyari.png'));md=[];previews=[];start=0
 for i,(letter,j,hip,pos,handxs,event)in enumerate(POSES):
  ar,l,parts=sheets[letter];lab=parts[j];a=ar.copy();k=ndi.binary_dilation(l==lab,iterations=2);a[:,:,3]=np.where(k&(a[:,:,3]>=10)&((l==lab)|(l==0)),a[:,:,3],0)
  rr,gg,bb,aa=np.moveaxis(a.astype('int16'),2,0);pink=(rr>100)&(bb>80)&(rr-gg>50)&(bb-gg>50)&(aa>80)
  qy,qx=np.indices(pink.shape);fit=pink&(abs(qy-GUIDE_Y[i])<10)&(qx>=min(handxs)-25)&(qx<=max(handxs)+60)
  yy,xx=np.where(fit);slope,intercept=np.polyfit(xx,yy,1);hands=[[x,float(slope*x+intercept)]for x in handxs]
  a[:,:,3]=np.where(ndi.binary_dilation(pink,iterations=1),0,a[:,:,3]);body=largest(Image.fromarray(a));box=body.getbbox();body=body.crop(box);body.save(ROOT/'source_crops'/f'{i:02}.png')
  S=SCALE[letter];scaled=body.resize((round(body.width*S),round(body.height*S)),Image.Resampling.LANCZOS);dx=round(pos[0]-(hip[0]-box[0])*S);dy=round(pos[1]-(hip[1]-box[1])*S);char=Image.new('RGBA',(W,H));char.alpha_composite(scaled,(dx,dy));cv=lambda p:[dx+(p[0]-box[0])*S,dy+(p[1]-box[1])*S]
  gx,gy=cv(hands[0]);theta=math.atan2(1,-slope);co,si=math.cos(theta),math.sin(theta);s=285/962
  A,B=co/s,si/s;D,E=-si/s,co/s
  weapon=spear.transform((W,H),Image.Transform.AFFINE,(A,B,188-A*gx-B*gy,D,E,740-D*gx-E*gy),Image.Resampling.BICUBIC)
  back=Image.new('RGBA',(W,H));front=weapon;occ=Image.new('RGBA',(W,H))
  for hand in hands:
   hx,hy=cv(hand);r=8;occ.alpha_composite(char.crop((round(hx-r),round(hy-r),round(hx+r),round(hy+r))),(round(hx-r),round(hy-r)))
  comp=Image.alpha_composite(char,weapon);comp=Image.alpha_composite(comp,occ)
  layers={'character':char,'weapon_back':back,'weapon_front':front,'hand_occlusion':occ,'composite':comp}
  for lay,im in layers.items():im.save(ROOT/lay/f'{i:02}.png')
  tip=[gx+733*s*si,gy-733*s*co];butt=[gx-229*s*si,gy+229*s*co]
  md.append({'index':i,'duration_ms':DUR[i],'start_ms':start,'event':event,'source_file':f'source-{letter}.png','source_pose':j,'source_rect':list(box),'source_sha256':hashlib.sha256((ROOT/f'source-{letter}.png').read_bytes()).hexdigest(),'scale':S,'hip_source':hip,'root_canvas':pos,'translation':[dx,dy],'hands_source':hands,'hands_canvas':[cv(h)for h in hands],'gripping_hands':['anatomical_right_rear','anatomical_left_forward'],'weapon_grip_source':[188,740],'weapon_tip_canvas':tip,'weapon_butt_canvas':butt,'weapon_length_px':285,'weapon_angle_degrees':math.degrees(theta),'weapon_projection':1,'character_bbox':char.getbbox(),'contact_status':'preview event only; collision and runtime unverified'})
  start+=DUR[i]
  bg=Image.new('RGBA',(W,H),(37,43,52,255));bg=Image.alpha_composite(bg,comp);d=ImageDraw.Draw(bg);d.line((20,FLOOR,620,FLOOR),fill=(65,72,80));d.text((15,12),'TADAKATSU | air_light v5 | forward thrust | 12 real poses',fill=(215,220,225));d.text((15,320),f'{i+1}/12  {DUR[i]} ms  {event}',fill=(165,174,184));previews.append(bg.convert('RGB'))
 cs=Image.new('RGB',(W*4,H*3),(37,43,52))
 for i,fr in enumerate(previews):cs.paste(fr,((i%4)*W,(i//4)*H))
 cs.save(ROOT/'contact.png');pal=cs.quantize(colors=255,method=Image.Quantize.MEDIANCUT);gs=[fr.quantize(palette=pal,dither=Image.Dither.NONE)for fr in previews]
 for fac,n in [(1,'normal.gif'),(3,'slow.gif')]:gs[0].save(ROOT/n,save_all=True,append_images=gs[1:],duration=[x*fac for x in DUR],loop=0,disposal=2,optimize=False)
 request={'source_message':'Sentinel_fcf9acb655148191b5ba708f50b698c3','verbatim':'這招應該從握持到前戳就可以了，不用把槍頭轉到後面','supersedes':'Earlier air_light horizontal sweep/body turn directions, including old generic specification.','accepted_action':'forward holding -> direct forward thrust -> withdrawal and airborne descent; spear points forward throughout'}
 config={'action':'air_light','version':5,'user_override':request,'canvas':[W,H],'floor':FLOOR,'frame_count':12,'duration_ms':sum(DUR),'all_twelve_new_cloud_keyposes':True,'source_scale':SCALE,'weapon_length_px':285,'weapon_projection':1,'runtime_integrated':False,'events':[{'at_ms':sum(DUR[:6]),'type':'contact_preview','verified_collision':False}]}
 (ROOT/'config.json').write_text(json.dumps(config,indent=2,ensure_ascii=False))
 meta=dict(config,frames=md,limits=['No opponent collision, damage/range or game-runtime verification.','Whole-body image layers, not per-limb skeletal rigs.','Magenta guide was masked beneath the original complete weapon; fullbody wrist overlap pixels are not independently repaintable.','No optical flow, translated duplicate frames, mirrored playback or spear-length scaling.'])
 (ROOT/'metadata.json').write_text(json.dumps(meta,indent=2,ensure_ascii=False))
 manifest={'schema':'sprite-frame-manifest/v1','action':'air_light','version':5,'canvas':{'width':W,'height':H},'duration_ms':sum(DUR),'frame_count':12,'loop':False,'facing':'right','background':'transparent','root_reference':'pixel coordinates in each640x340frame; root path included per frame','preview_gif':'normal.gif','contact_sheet':'contact.png','frames':[{'index':i,'src':f'composite/{i:02}.png','duration_ms':DUR[i],'start_ms':r['start_ms'],'root':r['root_canvas'],'hands':r['hands_canvas'],'weapon_tip':r['weapon_tip_canvas'],'event':r['event'],'layers':{lay:f'{lay}/{i:02}.png'for lay in LAYERS if lay!='composite'}}for i,r in enumerate(md)]}
 (ROOT/'frames-manifest.json').write_text(json.dumps(manifest,indent=2))
 print(json.dumps({'frames':12,'duration':sum(DUR),'hands':[r['hands_canvas']for r in md],'tips':[r['weapon_tip_canvas']for r in md]}))
if __name__=='__main__':build()
