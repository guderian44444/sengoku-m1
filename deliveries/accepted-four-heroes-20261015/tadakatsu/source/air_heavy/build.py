from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
import numpy as np,json,math,hashlib
ROOT=Path(__file__).resolve().parent
W,H=640,420;FLOOR=376;S=.235
ORDER=[('old',0),('old',1),('new',0),('old',2),('old',3),('old',4),('old',5),('new',1)]
DUR=[80,90,70,80,70,80,80,170]
OLD_Y=[163,86,180,235,260,278]
OLD_GRIP=[900,900,900,900,700,621]
EVENTS=['jump_tail_grip','apex_tail_grip','added_forward_downswing','full_length_downstroke','full_length_contact','airborne_regrip_700','airborne_regrip_621','added_landing_safe_recovery']
LAYERS=['character','weapon_back','weapon_front','hand_occlusion','effect','composite']
def largest(im):
 a=np.array(im.convert('RGBA'));l,n=ndi.label(a[:,:,3]>=96);c=np.bincount(l.ravel());c[0]=0;k=ndi.binary_dilation(l==c.argmax(),iterations=2);a[:,:,3]=np.where(k&(a[:,:,3]>=10),a[:,:,3],0);return Image.fromarray(a)
def additions():
 im=Image.open(ROOT/'source-added-two-poses.png').convert('RGBA');ar=np.array(im);lab,n=ndi.label(ar[:,:,3]>=96);parts=[]
 for k,sl in enumerate(ndi.find_objects(lab)):
  if (lab[sl]==k+1).sum()>5000:parts.append((sl[1].start,k+1))
 parts.sort();out=[]
 for j,(_,label) in enumerate(parts):
  a=ar.copy();mask=ndi.binary_dilation(lab==label,iterations=2);a[:,:,3]=np.where(mask&(a[:,:,3]>=10),a[:,:,3],0);r,g,b,al=np.moveaxis(a.astype('int16'),2,0);pink=(r>100)&(b>80)&(r-g>50)&(b-g>50)&(al>80);yy,xx=np.where(pink);slope,intercept=np.polyfit(xx,yy,1);xs=([500,680]if j==0 else [1585,1920]);hands=[[x,float(slope*x+intercept)]for x in xs]
  a[:,:,3]=np.where(ndi.binary_dilation(pink,iterations=1),0,a[:,:,3]);body=largest(Image.fromarray(a));box=body.getbbox();body=body.crop(box);body.save(ROOT/'added_crops'/f'{j:02}.png');sc=body.resize((round(body.width*S),round(body.height*S)),Image.Resampling.LANCZOS)
  if j==0:dx=round(250-(hands[0][0]-box[0])*S);dy=round(115-(hands[0][1]-box[1])*S)
  else:
   aa=np.array(sc)[:,:,3]>96;ys,xxs=np.where(aa);bottom=ys.max();xx=np.where(aa[max(0,bottom-6):bottom+1].any(axis=0))[0];groups=np.split(xx,np.where(np.diff(xx)>12)[0]+1);groups=[g for g in groups if len(g)>4];left=groups[0];fx=(left.min()+left.max())/2;dx=round(180-fx);dy=round(FLOOR-bottom)
  char=Image.new('RGBA',(W,H));char.alpha_composite(sc,(dx,dy));h=[[dx+(q[0]-box[0])*S,dy+(q[1]-box[1])*S]for q in hands]
  out.append((char,h,{'source_file':'source-added-two-poses.png','source_frame':j,'source_rect':list(box),'scale':S,'translation':[dx,dy],'guide_fit_slope':float(slope),'source_hands':hands,'generation':'new cloud-generated pose'}))
 return out

def build():
 for d in LAYERS+['added_crops']:(ROOT/d).mkdir(exist_ok=True)
 old=json.loads((ROOT/'base_metadata.json').read_text());news=additions();spear=largest(Image.open(ROOT/'spear_suyari.png'));frames=[];md=[]
 for i,(kind,j)in enumerate(ORDER):
  if kind=='old':
   f=old['frames'][j];base=Image.open(ROOT/'base_frames'/f'body_canvas_{j+1:02}.png').convert('RGBA');s=f['render_scale'];ox,oy=f['render_origin'];h=[[ox+p[0]*s,oy+p[1]*s]for p in f['hands']];dy=round(OLD_Y[j]-h[0][1]);char=Image.new('RGBA',(W,H));char.alpha_composite(base,(0,dy));hands=[[x,y+dy]for x,y in h];grip=OLD_GRIP[j];record={'source_file':'source-original-six.png','source_frame':j,'scale':s,'translation_from_old_canvas':[0,dy],'generation':'retained original pose with adjusted airborne trajectory','original_metadata':f}
  else:char,hands,record=news[j];grip=900 if j==0 else 621
  clean=np.array(char);rr,gg,bb,aa=np.moveaxis(clean.astype('int16'),2,0);residue=(rr>100)&(bb>80)&(rr-gg>50)&(bb-gg>50)&(aa>0);clean[:,:,3]=np.where(residue,0,clean[:,:,3]);char=Image.fromarray(clean)
  gx,gy=hands[0];vx=hands[1][0]-gx;vy=hands[1][1]-gy;theta=math.atan2(vx,-vy);ws=270/962;co,si=math.cos(theta),math.sin(theta);A,B=co/ws,si/ws;D,E=-si/ws,co/ws
  weapon=spear.transform((W,H),Image.Transform.AFFINE,(A,B,188-A*gx-B*gy,D,E,grip-D*gx-E*gy),Image.Resampling.BICUBIC)
  occ=Image.new('RGBA',(W,H))
  for x,y in hands:
   r=8;occ.alpha_composite(char.crop((round(x-r),round(y-r),round(x+r),round(y+r))),(round(x-r),round(y-r)))
  effect=Image.open(ROOT/'base_frames/effect_05.png').convert('RGBA') if i==7 else Image.new('RGBA',(W,H));comp=Image.alpha_composite(effect,char);comp=Image.alpha_composite(comp,weapon);comp=Image.alpha_composite(comp,occ)
  imgs={'character':char,'weapon_back':Image.new('RGBA',(W,H)),'weapon_front':weapon,'hand_occlusion':occ,'effect':effect,'composite':comp}
  for lay,im in imgs.items():im.save(ROOT/lay/f'{i:02}.png')
  wa=np.array(weapon)[:,:,3];ca=np.array(char)[:,:,3];wy,wx=np.where(wa>64);cy,cx=np.where(ca>96);assert not(wa[0].any()or wa[-1].any()or wa[:,0].any()or wa[:,-1].any());assert wy.max()<=FLOOR+1,(i,wy.max());assert cy.max()<=FLOOR+1,(i,cy.max());assert cx.min()>0 and cx.max()<W-1 and cy.min()>0
  # Verified source tip and butt coordinates transformed with the same full-length rig.
  def wp(px,py):return [gx+ws*(co*(px-188)-si*(py-grip)),gy+ws*(si*(px-188)+co*(py-grip))]
  tip=wp(188,7);butt=wp(188,969);hand_distance=math.hypot(vx,vy);front_grip=grip-hand_distance/ws
  record.update(index=i,duration=DUR[i],event=EVENTS[i],hands_canvas=hands,weapon_grip_source=[188,grip],second_hand_grip_source_y=front_grip,weapon_angle_degrees=math.degrees(theta),weapon_tip_canvas=tip,weapon_butt_canvas=butt,weapon_full_length_px=270,weapon_alpha_max_y=int(wy.max()),body_alpha_max_y=int(cy.max()),ground_clearance_px=FLOOR-int(cy.max()),contact_status='preview marker only; enemy collision and gameplay unverified');md.append(record)
  bg=Image.new('RGBA',(W,H),(37,43,52,255));bg=Image.alpha_composite(bg,comp);d=ImageDraw.Draw(bg);d.line((20,FLOOR,620,FLOOR),fill=(65,72,80));d.text((15,12),'TADAKATSU | air_heavy v2 | full spear / tail grip',fill=(215,220,225));d.text((15,400),f'{i+1}/8 {DUR[i]}ms  {EVENTS[i]}',fill=(165,174,184));frames.append(bg.convert('RGB'))
 cs=Image.new('RGB',(W*4,H*2),(37,43,52))
 for i,fr in enumerate(frames):cs.paste(fr,((i%4)*W,(i//4)*H))
 cs.save(ROOT/'contact.png');pal=cs.quantize(colors=255,method=Image.Quantize.MEDIANCUT);gf=[fr.quantize(palette=pal,dither=Image.Dither.NONE)for fr in frames]
 for fac,n in [(1,'normal.gif'),(3,'slow.gif')]:gf[0].save(ROOT/n,save_all=True,append_images=gf[1:],duration=[x*fac for x in DUR],loop=0,disposal=2,optimize=False)
 m={'action':'air_heavy','version':2,'frame_count':8,'duration_ms':sum(DUR),'canvas':[W,H],'floor_y':FLOOR,'frames':md,'new_cloud_keyframes':2,'added_at_one_based_frames':[3,8],'retained_original_pose_count':6,'weapon_length_px':270,'grip_sequence_source_y':[f['weapon_grip_source'][1]for f in md],'airborne_strategy':'Tail-held downstroke and contact occur high in the jump. Source poses5 and6 become descending regrip transitions; new frame8 supplies grounded recovery with an almost horizontal spear.','scale_reference':'Original source render scale160/430 is preserved. New source sheet uses a constant .235 checked on helmet/antler/chest size; no per-pose bbox resizing.','source_original_sha256':hashlib.sha256((ROOT/'source-original-six.png').read_bytes()).hexdigest(),'source_added_sha256':hashlib.sha256((ROOT/'source-added-two-poses.png').read_bytes()).hexdigest(),'limits':['Preview contact only; enemy collision, damage/range and game runtime unverified.','Whole-character layers are not articulated per-limb rigs.','Guide removal pixels are covered by the registered spear; repaint may be needed for other grip layouts.','Regripping is a sampled eight-keyframe depiction, not a fully simulated continuous hand slide.','No optical flow, no added duplicate pose, no spear truncation or scaling to hide ground penetration.']}
 (ROOT/'metadata.json').write_text(json.dumps(m,indent=2));print(json.dumps({'frames':8,'duration_ms':sum(DUR),'grips':m['grip_sequence_source_y'],'weapon_ymax':[f['weapon_alpha_max_y']for f in md],'body_ymax':[f['body_alpha_max_y']for f in md]}))
if __name__=='__main__':build()
