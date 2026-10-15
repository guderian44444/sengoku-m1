from PIL import Image,ImageDraw
from pathlib import Path
import numpy as np,json
from scipy import ndimage
from weapon_layer import weapon_layer
P=Path(__file__).parent;D=P/'charge_ready';S=Image.open(D/'source-stow.png').convert('RGBA');R=(320,285);SZ=(640,340);sc=163/478
frames=[];records=[]
# Continuous supported hand path into back sling; same full staff is retained.
for i in range(7):
 if i<6:
  a=np.array(S.crop(((i%3)*512,(i//3)*512,(i%3+1)*512,(i//3+1)*512)));lab,n=ndimage.label(a[:,:,3]>32);ct=np.bincount(lab.ravel());ct[0]=0;a[:,:,3]=np.where(ndimage.binary_dilation(lab==ct.argmax(),iterations=2),a[:,:,3],0)
  raw=Image.fromarray(a);origin=(round(R[0]-265*sc),round(R[1]-496*sc));b=Image.new('RGBA',SZ);b.alpha_composite(raw.resize((round(512*sc),)*2,Image.Resampling.LANCZOS),origin)
 else:b=Image.open(D/'body_canvas_04.png').convert('RGBA')
 hands=[(225,232),(320,153),(204,45),(211,65)]
 if i<3:
  hp=(origin[0]+hands[i][0]*sc,origin[1]+hands[i][1]*sc);ang=[72,-56,-35][i];staff=weapon_layer(SZ,hp,ang)
 else:hp=(R[0]-8,R[1]-85);ang=-24;staff=weapon_layer(SZ,hp,ang)
 front=Image.new('RGBA',SZ);back=Image.new('RGBA',SZ);occ=Image.new('RGBA',SZ)
 if i<3:
  front=staff
  for h in ([hands[i]]+([(425,170)] if i==0 else [])):
   xy=(origin[0]+h[0]*sc,origin[1]+h[1]*sc);box=(round(xy[0]-5),round(xy[1]-5),round(xy[0]+5),round(xy[1]+5));occ.alpha_composite(b.crop(box),box[:2])
 else:back=staff
 out=back.copy();out.alpha_composite(b);out.alpha_composite(front);out.alpha_composite(occ)
 for name,im in [('body_stow',b),('weapon_back',back),('weapon_front',front),('hand_occlusion',occ),('composite',out)]:im.save(D/f'{name}_{i+1:02}.png')
 c=Image.new('RGB',SZ,(40,44,48));c.paste(out,mask=out.getchannel('A'));d=ImageDraw.Draw(c);d.line((20,285,620,285),fill=(75,80,85));d.text((14,14),'KENNYO03 | shakujo stow > stationary chant',fill=(235,235,235));frames.append(c);records.append({'frame':i+1,'root':R,'weapon_main_grip':hp,'weapon_angle_clockwise':ang,'weapon_state':'held' if i<3 else 'back sling'})
durs=[130,90,90,100,90,100,1000]
frames[0].save(D/'kennyo03_charge_ready_stow_staff.gif',save_all=True,append_images=frames[1:],duration=durs,loop=0,disposal=2)
frames[-1].save(P/'charge_hold/kennyo03_charge_hold_staff.gif',duration=1000)
Image.open(D/'composite_07.png').save(P/'charge_hold/composite_01.png')
Image.open(D/'weapon_back_07.png').save(P/'charge_hold/weapon_back_01.png')
(D/'stow-metadata.json').write_text(json.dumps({'standing_anatomical_px':163,'scale':sc,'body_hold_static':True,'durations':durs,'frames':records,'weapon_continuity':'same complete shakujo rotates in hand then remains behind body through chanting and necklace release','runtime_integrated':False},indent=2))
cs=Image.new('RGB',(640*4,340*2),(40,44,48))
for i,f in enumerate(frames):cs.paste(f,((i%4)*640,(i//4)*340))
cs.save(D/'stow-contact.jpg')
