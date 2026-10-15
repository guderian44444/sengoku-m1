from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,math,hashlib
from scipy.ndimage import label,binary_dilation
from build_rest import transform
P=Path(__file__).resolve().parents[1];D=P/'actions/charge_release'
feet=[[(88,470),(502,469),(882,474),(1450,461),(310,950),(675,940),(880,940),(1235,959)],[(106,475),(498,480),(887,480),(1440,468),(315,943),(682,950),(856,938),(1240,953)]]
hands=[[(35,138),(441,142),(1038,147),(1497,147),(375,638),(737,641),(870,638),(1164,635)],[(88,134),(499,144),(978,149),(1477,148),(349,629),(732,631),(847,624),(1214,625)]]
files=['pivot_views.png','pivot_between.png'];images=[];ids=[]
for fn in files:
 a=np.array(Image.open(D/'sources'/fn).convert('RGBA'));l,k=label(a[:,:,3]>30);size=np.bincount(l.ravel());qs=np.argsort(size[1:])[-8:]+1;objs=[]
 for q in qs:
  y,x=np.where(l==q);objs.append((int(y.mean()>512),x.mean(),q))
 images.append((a,l));ids.append([q[2] for q in sorted(objs)])
seq=[(b,j) for j in [1,2,3,4,5,6,7,0] for b in [0,1]]+[(0,1)]
ds=[80]*11+[70]*6;assert sum(ds)==1300
sw=Image.open(P/'reference/tachi.png').convert('RGBA');sa=Image.open(P/'reference/saya.png').convert('RGBA');out=[];recs=[]
for i,(b,j) in enumerate(seq):
 a,l=images[b];ar=a.copy();ar[:,:,3]=np.where(binary_dilation(l==ids[b][j],iterations=2),a[:,:,3],0);yy,xx=np.where(ar[:,:,3]>0);box=(int(xx.min()),int(yy.min()),int(xx.max()+1),int(yy.max()+1));body=Image.fromarray(ar).crop(box);s=152/440;rx,ry=feet[b][j];ox=205-rx*s;oy=365-ry*s;layer=Image.new('RGBA',(560,400));layer.alpha_composite(body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS),(round(ox+box[0]*s),round(oy+box[1]*s)));gx,gy=hands[b][j];grip=(ox+gx*s,oy+gy*s)
 # Blade follows anatomical right hand; foreshortened near profile views.
 right= gx>(box[0]+box[2])/2;angle=90 if right else -90;proj=.38 if j in [2,6] else (.72 if j in [1,3,5,7] else 1)
 weapon=transform(sw,(100,1080),grip,angle,.085,proj);sheath=transform(sa,(87,22),(ox+(box[0]+body.width*.5)*s,oy+(box[1]+body.height*.5)*s),65,.07)
 comp=Image.new('RGBA',(560,400));comp.alpha_composite(sheath)
 behind=j in [3,4,5]
 if behind:comp.alpha_composite(weapon)
 comp.alpha_composite(layer)
 if not behind:comp.alpha_composite(weapon)
 patch=Image.fromarray(ar).crop((gx-13,gy-13,gx+13,gy+13)).resize((9,9));comp.alpha_composite(patch,(round(grip[0]-4.5),round(grip[1]-4.5)))
 for n,im in [('body',body),('body_canvas',layer),('sword',weapon),('sheath',sheath),('composite',comp)]:im.save(D/f'{n}_{i:02}.png')
 bg=Image.new('RGB',(560,400),(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,366,560,366),fill=(80,86,93));dr.text((12,10),f'IEYASU 06 / single right-hand spin / {i+1:02}/17 / 1300ms',fill='white');out.append(bg)
 recs.append(dict(frame=i,source=str(Path('sources')/files[b]),source_pose=j,source_crop=box,source_grip=[gx,gy],support_foot=[rx,ry],support_side='anatomical_right',root_world=[205,365],pivot_world=[205,365],body_scale=s,grip_world=grip,blade_angle_deg=angle,blade_projection=proj,weapon_behind=behind,spin_accumulated_deg=i*22.5,duration_ms=ds[i],event='single_spin_contact' if i==8 else None))
for suf,m in [('normal',1),('slow',3)]:out[0].save(D/f'charge_release_{suf}.gif',save_all=True,append_images=out[1:],duration=[x*m for x in ds],disposal=2)
cs=Image.new('RGB',(560*4,400*5),(47,53,61))
for i,f in enumerate(out):cs.paste(f,((i%4)*560,(i//4)*400))
cs.save(D/'contact_sheet.png');json.dump(dict(action='charge_release',candidate=True,total_ms=1300,unique_source_poses=16,frames=recs,rotation_degrees=360,weapon_hand='right',pivot='right foot fixed at [205,365]',limitations=['17 playback frames including repeated endpoint;16 unique authored poses','2D perspective approximation; visual contact review only','charge hold uses two-handed waist grip; transition into outstretched single-hand needs runtime blend or future entry pose']),open(D/'metadata.json','w'),indent=2)
