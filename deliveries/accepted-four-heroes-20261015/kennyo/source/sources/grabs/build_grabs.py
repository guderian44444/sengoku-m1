#!/usr/bin/env python3
"""Imagegen keyframes only; alpha cleanup, crop, uniform anatomical scaling,
rigid independent victim registration, separated weapon/fingers and GIF assembly.
No pose synthesis, optical flow, warping, or runtime modifications.
"""
from pathlib import Path
from PIL import Image,ImageDraw
from scipy import ndimage as ndi
import numpy as np,json,hashlib,math,argparse
R=Path(__file__).resolve().parent; W,H=640,320;FLOOR=270
S={'grab_start':163/482,'grab_hit_1':163/505,'grab_hit_2':163/494,'throw_forward':163/425,'throw_reverse':163/423}
# Source-sheet landmarks manually measured from generated anatomy, NOT frame bounding-box normalization.
HAND={
'grab_start':[(327,163),(949,116),(1470,106),(494,588),(863,624),(1445,629)],
'grab_hit_1':[(478,127),(928,148),(1432,143),(484,664),(937,674),(1435,624)],
'grab_hit_2':[(459,139),(952,146),(1417,142),(472,669),(969,675),(1407,658)],
 'throw_forward':[(365,113),(737,165),(1270,35),(1733,62),(420,484),(860,665),(1200,642),(1613,607)],
 'throw_reverse':[(341,112),(764,101),(1119,47),(1506,113),(51,552),(498,578),(1004,555),(1458,578)]}
SECOND={
'grab_start':[(237,162),(833,232),(1405,226),(420,681),(850,684),(1344,701)],
'grab_hit_1':[(381,164),(855,168),(1356,177),(473,679),(908,685),(1348,652)],
'grab_hit_2':[(375,191),(873,200),(1344,189),(449,681),(946,688),(1377,621)],
 'throw_forward':[(318,122),(679,162),(1224,54),(1694,47),(372,490),(803,670),(1073,626),(1549,605)],
 'throw_reverse':[(311,139),(756,114),(1095,43),(1497,129),(75,595),(512,596),(1091,583),(1539,576)]}
FOREHEAD={'grab_hit_1':[(341,40),(760,44),(1322,71),(471,592),(922,604),(1302,551)],'grab_hit_2':[(303,63),(755,45),(1201,41),(460,591),(947,605),(1346,574)]}
FEET={'throw_reverse':[46,541,972,1419,136,628,997,1408], 'throw_forward':[47,505,956,1389,51,505,956,1389]}
A={
'grab_start':('grab_start',[0,1,2,3,5],[100,80,70,80,180]),
'grab_hold':('grab_start',[5],[800]),
'grab_hit_1':('grab_hit_2',[0,1,2,3,4,5],[110,90,80,60,90,170]),
'grab_hit_2':('grab_hit_2',[0,1,2,3,4,5],[110,90,80,60,90,170]),
 'throw_forward':('throw_forward',[0,1,2,3,4,5,6,7,7,7],[100,100,80,50,70,80,80,90,110,220]),
 'throw_reverse':('throw_reverse',[0,1,2,3,4,5,6,7,7,7],[100,100,110,80,60,70,80,90,110,230])}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def parts(p):
 im=Image.open(p).convert('RGBA');a=np.array(im);lab,n=ndi.label(a[:,:,3]>=128);q=[]
 for i,s in enumerate(ndi.find_objects(lab)):
  if s is None or (lab[s]==i+1).sum()<5000:continue
  reg=ndi.binary_dilation(lab==i+1,iterations=1);ar=a.copy();ar[:,:,3]=np.where(reg & (a[:,:,3]>12),a[:,:,3],0)
  ci=Image.fromarray(ar);bb=ci.getbbox();q.append((ci.crop(bb),list(bb)))
 q.sort(key=lambda c:(int(((c[1][1]+c[1][3])/2)//(im.height/2)),c[1][0]));return q
P={n:parts(R/'sources'/f'{n}.png') for n in S}
VP=parts(R/'references/victim-headbutt.png');VOLD=parts(R/'references/victim.png')
def rescale(im,s):return im.resize((round(im.width*s),round(im.height*s)),Image.Resampling.LANCZOS)
def foot(im):
 a=np.array(im)[:,:,3]>100;y=np.where(a)[0].max();xx=np.where(a[max(0,y-6):y+1].any(0))[0];groups=np.split(xx,np.where(np.diff(xx)>10)[0]+1);groups=[g for g in groups if len(g)>3];return float(groups[0].mean()),float(y)
def wp_layer(anchor,srcidx,reverse):
 wp=Image.open(R.parent/'weapons/ornate_shakujo.png').convert('RGBA')
 # Body-back stow, staff stays attached to actor and behind victim. Complete physical length215px.
 ang=[-17,-10,0,12,20,20,20,20][srcidx] if reverse else -17
 rot=wp.rotate(ang,expand=True,resample=Image.Resampling.BICUBIC)
 layer=Image.new('RGBA',(W,H));x=round(anchor+36-rot.width/2);y=round(FLOOR-267);layer.alpha_composite(rot,(x,y));return layer,[x,y],ang

def gifwrite(ff,path,dur):
 montage=Image.new('RGB',(W*len(ff),H));
 for i,f in enumerate(ff):montage.paste(f,(i*W,0))
 pal=montage.quantize(colors=255,method=Image.Quantize.MEDIANCUT);g=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in ff]
 g[0].save(path,save_all=True,append_images=g[1:],duration=dur,loop=0,disposal=2,optimize=False)
def build(name):
 src,seq,durs=A[name];s=S[src];out=R/name;out.mkdir(exist_ok=True)
 dirs=['body','victim','weapon_back','fingers_front','composite','source_crops']
 for d in dirs:(out/d).mkdir(exist_ok=True)
 frames=[];bf=[];meta=[];isrev=name=='throw_reverse';throw=name.startswith('throw');anchor=350 if isrev else 185
 for j,k in enumerate(seq):
  crop,bb=P[src][k];crop.save(out/'source_crops'/f'{j:02d}.png');bodyim=rescale(crop,s);fx,fy=foot(bodyim)
  if src in FEET:fx=(FEET[src][k]-bb[0])*s
  dx=round(anchor-fx);dy=round(FLOOR-fy);body=Image.new('RGBA',(W,H));body.alpha_composite(bodyim,(dx,dy))
  def point(pt):return [round((pt[0]-bb[0])*s+dx,2),round((pt[1]-bb[1])*s+dy,2)]
  h=point(HAND[src][k]);h2=point(SECOND[src][k]);fore=point(FOREHEAD[src][k]) if src in FOREHEAD else None
  weapon,wxy,ang=wp_layer(anchor,k,isrev)
  # Main gripping hands are cut directly from generated body alpha, never redrawn.
  fingers=Image.new('RGBA',(W,H));mask=Image.new('L',(W,H));md=ImageDraw.Draw(mask)
  attached=(name!='grab_start' or j>=3) and (not throw or j<(4 if isrev else 3))
  if attached:
   for hx,hy in [h,h2]:md.ellipse([hx-7,hy-8,hx+7,hy+8],fill=255)
   aa=np.array(body);aa[:,:,3]=np.minimum(aa[:,:,3],np.array(mask));fingers=Image.fromarray(aa)
  vi=0;release=False;events=[];vsource='headbutt';vs=.305
  if name=='grab_start' and j<3:vi=0;vsource='old'
  if name=='grab_start' and j==3:events=['grab_attach']
  if name.startswith('grab_hit'):
   if j==3:events=[name+'_headbutt_contact']
   if j==4:vi=2
  if throw:
   rel=4 if isrev else 3
   if isrev and j in (1,2,3) and j<rel:vi=3
   if not isrev and j==2:vi=4
   if j>=rel:vi=4;release=True
   if j==rel:events=['throw_release_left' if isrev else 'throw_release_right']
   if j==len(seq)-1:vi=5;events=['victim_land']
  vp=VOLD if vsource=='old' else VP;vc,vb=vp[vi];vc=rescale(vc,vs)
  if throw and release:
   rel=4 if isrev else 3;t=(j-rel)/(len(seq)-1-rel);x0=(anchor-28 if isrev else anchor+190);vx_center=x0+(-195 if isrev else 170)*t
   # World trajectory independent of rooted attacker. Parabola is sampled by actual event phase.
   if j==len(seq)-1:vy=FLOOR-vc.height;vx=vx_center-vc.width/2
   else:
    cy=(FLOOR-150)+100*t-105*4*t*(1-t);vx=vx_center-vc.width/2;vy=cy-vc.height/2
  elif throw and not isrev and vi==4:
   vx=h[0]-15;vy=h[1]-vc.height*.55
  elif throw and vi==3:
   # Hanging body has its upper back resting on actor shoulder, then rotates across behind actor.
   vx=(anchor+47 if not isrev else anchor+40)-vc.width/2;vy=FLOOR-190-(j-1)*8
  elif vsource=='old':vx=anchor+140;vy=FLOOR-vc.height
  else:
   # Separately registered collar and victim feet; attached victim follows gripping hand.
   collar=[(220,185),(745,169),(1263,159)][min(vi,2)];vx=h[0]-(collar[0]-vb[0])*vs;vy=h[1]-(collar[1]-vb[1])*vs
   if name.startswith('grab_hit') and j==3:
    # Actual forehead-to-forehead contact uses the victim's planted grabbed pose.
    vhead=(170,120);vx=fore[0]-(vhead[0]-vb[0])*vs+1;vy=fore[1]-(vhead[1]-vb[1])*vs
  vy=min(vy,FLOOR-vc.height)
  victim=Image.new('RGBA',(W,H));victim.alpha_composite(vc,(round(vx),round(vy)))
  # During shoulder load victim is behind body; on release it becomes a separate foreground body.
  victim_back=isrev and not release and j in (1,2,3)
  comp=weapon.copy()
  if victim_back:comp.alpha_composite(victim);comp.alpha_composite(body)
  else:comp.alpha_composite(body);comp.alpha_composite(victim)
  comp.alpha_composite(fingers)
  for d,im in [('body',body),('victim',victim),('weapon_back',weapon),('fingers_front',fingers),('composite',comp)]:im.save(out/d/f'{j:02d}.png')
  bg=Image.new('RGBA',(W,H),(29,34,42,255));dd=ImageDraw.Draw(bg);dd.line((18,FLOOR+1,W-18,FLOOR+1),fill=(78,87,99));dd.text((18,14),f'KENNYO 03 | {name} | {j+1}/{len(seq)}',fill=(224,224,224));dd.text((18,31),'163 px standing-equivalent | isolated body / staff / opponent',fill=(151,162,176));bg.alpha_composite(comp);frames.append(bg.convert('RGB'))
  bc=Image.new('RGBA',(W,H),(29,34,42,255));bc.alpha_composite(weapon);bc.alpha_composite(body);bf.append(bc.convert('RGB'))
  meta.append({'index':j,'source_frame':k,'source_crop':bb,'source_sha256':sha(R/'sources'/f'{src}.png'),'uniform_sheet_scale':s,'body_translation':[dx,dy],'root':[anchor,FLOOR],'support_foot':[anchor,FLOOR],'hands':[h,h2],'forehead':fore,'duration_ms':durs[j],'events':events,'victim':{'source':vsource,'pose':vi,'scale':vs,'translation':[round(vx),round(vy)],'released':release,'layer':'back' if victim_back else 'front','bbox':list(victim.getbbox()) if victim.getbbox() else None},'weapon':{'asset':'../weapons/ornate_shakujo.png','layer':'back','length_px':215,'rotation_pil_deg':ang,'translation':wxy},'finger_mask':'tight hand-only elliptical alpha intersection, 14x16px per hand','attached':attached})
 gifwrite(frames,out/f'kennyo03_{name}.gif',durs);gifwrite(frames,out/f'kennyo03_{name}-slow.gif',[d*3 for d in durs]);gifwrite(bf,out/f'kennyo03_{name}-body-only.gif',durs)
 contact=Image.new('RGB',(W*3,H*math.ceil(len(frames)/3)),(29,34,42))
 for j,f in enumerate(frames):contact.paste(f,((j%3)*W,(j//3)*H))
 contact.save(out/f'kennyo03_{name}-contact.png');frames[3 if len(frames)>3 else 0].save(out/f'kennyo03_{name}-representative.png')
 info={'action':name,'canvas':[W,H],'body_height_standing_equivalent':163,'anatomical_scale_policy':'Fixed one scale per source sheet from its neutral upright frame and visually cross-checked head/torso; no per-frame bounding-box scaling; crouches remain shorter.','source':f'sources/{src}.png','source_sha256':sha(R/'sources'/f'{src}.png'),'source_size':Image.open(R/'sources'/f'{src}.png').size,'fixed_sheet_scale':s,'runtime_loop':name=='grab_hold','duration_ms':sum(durs),'frame_count':len(seq),'interpolation':'none, generated keyframes; later repeated recovery frames allow separately tracked victim flight','generator':'image_gen.imagegen','identity':'approved-concept03.png and idle-body.png','compositing':['weapon_back','victim_back if shoulder-loaded','body','victim_front otherwise','fingers_front'],'frames':meta,'limitations':['Keyframe prototype; no interpolation or optical flow.','Grip landmarks are manually measured visual anchors with roughly 3px game-scale uncertainty, not runtime hitboxes.','Static grab_hold intentionally reuses the exact final grab_start pose for seamless hold.','Independent victim and weapon layers included; no enemy baked into Kennyo body.','No game runtime, website or repository changes.']}
 (out/'metadata.json').write_text(json.dumps(info,ensure_ascii=False,indent=2));print(json.dumps({'action':name,'frames':len(seq),'gif':str(out/f'kennyo03_{name}.gif')}))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('actions',nargs='*');a=p.parse_args()
 for n in a.actions or A:
  if n in ['throw_forward','throw_reverse']:
   from revise_weighted_throws import render
   render(n)
  else:build(n)
