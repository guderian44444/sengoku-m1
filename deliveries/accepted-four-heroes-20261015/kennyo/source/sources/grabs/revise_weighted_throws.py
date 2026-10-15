from pathlib import Path
from PIL import Image,ImageDraw,ImageOps,ImageSequence
import numpy as np,json,math,hashlib
import build_grabs as b
R=b.R;W,H=b.W,b.H;F=b.FLOOR
NEW={n:b.parts(R/'sources'/f'{n}_weight.png') for n in ['throw_forward','throw_reverse']}
V=b.parts(R/'references/victim-forward-weight.png')
NHEAD={'throw_forward':[(310,47),(860,95),(1348,164),(340,523),(842,525),(1335,565)],'throw_reverse':[(290,54),(827,50),(1343,50),(235,532),(678,574),(1225,578)]}
NH={'throw_forward':[(460,101),(960,148),(1430,218),(468,526),(967,513),(1471,526)],'throw_reverse':[(367,105),(851,103),(1382,74),(174,537),(640,602),(1045,626)]}
NH2={'throw_forward':[(381,195),(880,240),(1381,275),(420,608),(932,621),(1460,614)],'throw_reverse':[(345,134),(844,113),(1372,86),(168,548),(635,618),(1076,668)]}
NF={'throw_forward':[66,580,1071,64,545,1031],'throw_reverse':[52,617,1128,55,662,1162]}
NS={'throw_forward':.347,'throw_reverse':163/483}
D={'throw_forward':[80,100,90,70,60,50,60,70,70,80,100,150],'throw_reverse':[80,90,90,90,80,60,60,70,70,80,100,160]}
# Fixed victim source scale and cloth-contact landmarks. A rigid transform maps their midpoint/axis.
VH=[[(180,178),(208,302)],[(664,245),(725,350)],[(1298,157),(1245,233)],[(398,655),(307,717)],[(922,718),(824,776)]]
def rigid_two(im,box,p1,p2,t1,t2,scale):
 p1=np.array(p1)-np.array(box[:2]);p2=np.array(p2)-np.array(box[:2]);t1=np.array(t1);t2=np.array(t2)
 v=p2-p1;w=t2-t1;ang=math.atan2(w[1],w[0])-math.atan2(v[1],v[0]);c=math.cos(ang);s=math.sin(ang);rot=np.array([[c,-s],[s,c]])
 mid=(p1+p2)/2;dest=(t1+t2)/2;tr=dest-scale*rot@mid;inv=rot.T/scale;off=-inv@tr
 layer=im.transform((W,H),Image.Transform.AFFINE,tuple([*inv[0],off[0],*inv[1],off[1]]),Image.Resampling.BICUBIC)
 contacts=[(scale*rot@p1+tr).tolist(),(scale*rot@p2+tr).tolist()];err=[float(np.linalg.norm(np.array(x)-t)) for x,t in zip(contacts,[t1,t2])]
 return layer,{'scale':scale,'rotation_clockwise_deg':math.degrees(ang),'translation':tr.tolist(),'measured_contacts':contacts,'grip_error_px':err}
def placed(im,center,angle=0,scale=.305):
 q=b.rescale(im,scale).rotate(angle,expand=True,resample=Image.Resampling.BICUBIC);vl=Image.new('RGBA',(W,H));xy=[round(center[0]-q.width/2),round(center[1]-q.height/2)];vl.alpha_composite(q,tuple(xy));return vl,{'scale':scale,'rotation_pil_deg':angle,'translation':xy}
def render(name):
 out=R/name;rev=name=='throw_reverse';anchor=350 if rev else 185;durs=D[name];frames=[];bodyframes=[];met=[];lastcarry=None;release=5
 seq=[('new',k) for k in range(6)]+[('old',k) for k in [4,5,6,7,7,7]]
 for j,(kind,k) in enumerate(seq):
  crop,bb=(NEW[name] if kind=='new' else b.P[name])[k];s=NS[name] if kind=='new' else b.S[name];ci=b.rescale(crop,s);_,fy=b.foot(ci);sx=(NF[name][k] if kind=='new' else b.FEET[name][k]);dx=round(anchor-(sx-bb[0])*s);dy=round(F-fy);body=Image.new('RGBA',(W,H));body.alpha_composite(ci,(dx,dy))
  def pt(q):return [round((q[0]-bb[0])*s+dx,3),round((q[1]-bb[1])*s+dy,3)]
  h=pt((NH if kind=='new' else b.HAND)[name][k]);h2=pt((NH2 if kind=='new' else b.SECOND)[name][k]);weapon,_,_=b.wp_layer(anchor,min(j if not rev else round(j*7/11),7),rev)
  attached=j<release;vm={};back=False;events=[];fingers=Image.new('RGBA',(W,H))
  if attached:
   mask=Image.new('L',(W,H));d=ImageDraw.Draw(mask)
   for hx,hy in [h,h2]:d.ellipse([hx-7,hy-8,hx+7,hy+8],fill=255)
   aa=np.array(body);aa[:,:,3]=np.minimum(aa[:,:,3],np.array(mask));fingers=Image.fromarray(aa)
  if not rev and attached:
   vi=j;vc,vb=V[vi];victim,vm=rigid_two(vc,vb,*VH[j],h,h2,.32);lastcarry=victim.getbbox();back=False
   if lastcarry and lastcarry[3]>F:
    shift=F-lastcarry[3];grounded=Image.new('RGBA',(W,H));grounded.alpha_composite(victim,(0,shift));victim=grounded;vm['ground_correction_y']=shift;vm['contact_note']='Lowest loaded pose settles feet at floor; front cloth contacts remain visually overlapped by gripping hands.'
   if j==1:events=['weight_sink']
   if j==2:events=['weight_loaded']
   if j==3:events=['leg_drive']
   if j==4:events=['shoulder_drive_grip_held']
  elif rev and attached:
   if j==0:
    vc,vb=b.VP[0];t=(h[0]-(220-vb[0])*.305,h[1]-(185-vb[1])*.305);victim=Image.new('RGBA',(W,H));victim.alpha_composite(b.rescale(vc,.305),(round(t[0]),round(t[1])));vm={'scale':.305,'translation':t};vi=0
   else:
    vc,vb=b.VP[3];head=pt(NHEAD[name][k]);center=[head[0]+[0,-8,-6,0,-25][j],head[1]-[0,5,10,12,0][j]];victim,vm=placed(vc,center,angle=[0,-20,-10,5,30][j],scale=.305);vi=3;back=True
   lastcarry=victim.getbbox()
   if j==1:events=['turn_under_weight']
   if j==2:events=['weight_transfer']
   if j==3:events=['shoulder_load']
   if j==4:events=['over_shoulder_roll_grip_held']
  else:
   t=sum(durs[release:j])/sum(durs[release:-1]);t=min(1,t)
   if j==release:events=['throw_release_left' if rev else 'throw_release_right']
   # Victim is now independent, with the first free position adjacent to the last held torso.
   if rev:cx0=315;cx1=120;cy0=110
   else:cx0=365;cx1=545;cy0=110
   cx=cx0+(cx1-cx0)*t;cy=cy0+(F-30-cy0)*t-190*t*(1-t)
   if j==len(seq)-1:
    vc=b.VP[5][0];vc=ImageOps.mirror(vc) if not rev else vc;scale=.305;q=b.rescale(vc,scale);victim=Image.new('RGBA',(W,H));xy=[round(cx-q.width/2),F-q.height];victim.alpha_composite(q,tuple(xy));vm={'scale':scale,'translation':xy};vi=5;events=['victim_land']
   else:
    vc=(b.VP[4][0] if rev else V[5][0]);victim,vm=placed(vc,[cx,cy],angle=0,scale=.305 if rev else .32);vi=4 if rev else 5
   vm['trajectory_phase']=t
  # Separate every actor and fingers; shoulders physically obscure loaded victim's lower back.
  comp=weapon.copy()
  if back:comp.alpha_composite(victim);comp.alpha_composite(body)
  else:comp.alpha_composite(body);comp.alpha_composite(victim)
  comp.alpha_composite(fingers)
  for key,img in [('body',body),('victim',victim),('weapon_back',weapon),('fingers_front',fingers),('composite',comp)]:img.save(out/key/f'{j:02d}.png')
  crop.save(out/'source_crops'/f'{j:02d}.png')
  bg=Image.new('RGBA',(W,H),(29,34,42,255));dr=ImageDraw.Draw(bg);dr.line((18,F+1,W-18,F+1),fill=(78,87,99));dr.text((18,14),f'KENNYO 03 | {name} | {j+1}/12 | weighted revision',fill=(224,224,224));dr.text((18,31),'163 px standing-equivalent | 2 extra poses | original total time',fill=(151,162,176));bg.alpha_composite(comp);frames.append(bg.convert('RGB'));bc=Image.new('RGBA',(W,H),(29,34,42,255));bc.alpha_composite(weapon);bc.alpha_composite(body);bodyframes.append(bc.convert('RGB'))
  source=f'sources/{name}'+('_weight' if kind=='new' else '')+'.png';met.append({'index':j,'source':source,'source_frame':k,'source_crop':bb,'source_sha256':b.sha(R/source),'duration_ms':durs[j],'scale':s,'translation':[dx,dy],'root':[anchor,F],'support_foot':[anchor,F],'hands':[h,h2],'grip_attached':attached,'events':events,'victim':{'pose':vi,'back':back,'released':not attached,'source':'references/victim-headbutt.png' if rev else 'references/victim-forward-weight.png',**vm},'weapon':'215px ornate_shakujo back-stowed layer'})
 b.gifwrite(frames,out/f'kennyo03_{name}.gif',durs);b.gifwrite(frames,out/f'kennyo03_{name}-slow.gif',[x*3 for x in durs]);b.gifwrite(bodyframes,out/f'kennyo03_{name}-body-only.gif',durs)
 cs=Image.new('RGB',(W*3,H*4),(29,34,42))
 for j,f in enumerate(frames):cs.paste(f,((j%3)*W,(j//3)*H))
 cs.save(out/f'kennyo03_{name}-contact.png');frames[4].save(out/f'kennyo03_{name}-representative.png')
 info={'action':name,'revision':'Added2 actual imagegen poses, strengthened grounded weight transfer, original total timing preserved','canvas':[W,H],'frame_count':12,'duration_ms':sum(durs),'durations_ms':durs,'body_height_standing_equivalent':163,'source_scale_policy':'Fixed per-source anatomical scale; no per-pose bbox normalization','generator':'image_gen.imagegen','release_frame':release,'frames':met,'interpolation':'None; new generated body poses plus separately transformed independent victim. No optical flow.','limitations':['Imagegen anatomy/costume microdetails can vary.','Victim uses rigid independent actor transforms; grip landmarks are approximate visual registration, not hitboxes.','Runtime is not integrated.']};(out/'metadata.json').write_text(json.dumps(info,indent=2));print(name,len(frames),sum(durs))
if __name__=='__main__':
 import sys
 for n in sys.argv[1:] or D:render(n)
