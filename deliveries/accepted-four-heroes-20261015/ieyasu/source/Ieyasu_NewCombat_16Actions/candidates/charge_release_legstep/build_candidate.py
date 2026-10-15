from pathlib import Path
from PIL import Image,ImageDraw
from scipy.ndimage import label,binary_dilation
import numpy as np,json,hashlib,sys,math
P=Path(__file__).resolve().parents[2];sys.path.insert(0,str(P/'scripts'));from build_rest import transform
D=Path(__file__).parent;O=D/'original';m=json.loads((O/'metadata.json').read_text());hands={r['frame']:r for r in json.loads((P/'qa/charge_release_hand_candidate/metadata.json').read_text())};sources={}
for name,num,rows in [('lower16',16,4),('bridges8',8,2)]:
 a=np.array(Image.open(D/'sources'/f'{name}.png').convert('RGBA'));l,k=label(a[:,:,3]>30);sz=np.bincount(l.ravel());ids=np.argsort(sz[1:])[-num:]+1;ids=sorted(ids,key=lambda q:(int(np.where(l==q)[0].mean()//(a.shape[0]/rows)),np.where(l==q)[1].mean()));sources[name]=(a,l,ids)
# source, index, scale, anatomical right support, left sole, waist center
seq=[None,('lower16',1,.36,(518,238),(673,231),(584,28)),('lower16',2,.36,(940,238),(987,212),(954,27)),('lower16',3,.36,(1361,238),(1317,211),(1327,27)),('bridges8',0,.235,(234,415),(184,426),(198,72)),('bridges8',1,.235,(625,415),(405,420),(549,76)),('bridges8',2,.235,(1038,415),(775,415),(931,74)),('bridges8',3,.235,(1475,415),(1182,415),(1325,75)),('lower16',8,.36,(335,730),(91,730),(188,515)),('lower16',9,.36,(677,726),(509,726),(570,516)),('lower16',10,.36,(997,715),(929,736),(951,518)),('lower16',11,.36,(1372,715),(1331,736),(1350,518)),('bridges8',4,.212,(133,881),(203,930),(185,546)),('bridges8',5,.212,(483,930),(594,919),(528,545)),('bridges8',6,.212,(767,925),(1035,923),(897,546)),('bridges8',7,.212,(1160,925),(1483,920),(1299,546)),None]
oldhips=[241,234,227,169.5,157.5,156.5,153,150,163,160,160.5,156,251.5,246,245,245.5,241];sw=Image.open(P/'reference/tachi.png').convert('RGBA');frames=[];legs=[];recs=[]
for i,item in enumerate(seq):
 old=Image.open(O/f'body_canvas_{i:02}.png').convert('RGBA');handbody=D/'sources'/f'body_canvas_{i:02}.png'
 if i in hands:old=Image.open(handbody).convert('RGBA')
 if item is None:
  body=old;upper=old.copy();arr=np.array(upper);arr[308:,:,3]=0;upper=Image.fromarray(arr);lower=old.copy();arr=np.array(lower);arr[:308,:,3]=0;lower=Image.fromarray(arr);dx=dy=0;R=[205,365];L=[279,356]
 else:
  n,j,s,r,l,w=item;a,labs,ids=sources[n];ar=a.copy();ar[:,:,3]=np.where(binary_dilation(labs==ids[j],iterations=2),a[:,:,3],0);y,x=np.where(ar[:,:,3]>0);box=[x.min(),y.min(),x.max()+1,y.max()+1];cr=Image.fromarray(ar).crop(box);lower=Image.new('RGBA',(560,400));ox=205-r[0]*s;sy=83/(r[1]-w[1]);oy=365-r[1]*sy;lower.alpha_composite(cr.resize((round(cr.width*s),round(cr.height*sy)),Image.Resampling.LANCZOS),(round(ox+box[0]*s),round(oy+box[1]*sy)));dx=round(ox+w[0]*s-oldhips[i]);dy=0;arr=np.array(old);arr[308:,:,3]=0;upper=Image.new('RGBA',(560,400));upper.alpha_composite(Image.fromarray(arr),(dx,dy));arr=np.array(lower);arr[:306+dy,:,3]=0;lower=Image.fromarray(arr);body=lower.copy();body.alpha_composite(upper);R=[205,365];L=[round(ox+l[0]*s,1),round(oy+l[1]*sy,1)]
 grip=list(hands[i]['grip_world'] if i in hands else m['frames'][i]['grip_world']);grip=[grip[0]+dx,grip[1]+dy];weapon=transform(sw,(100,1080),grip,m['frames'][i]['blade_angle_deg'],.085,m['frames'][i]['blade_projection']);sh=Image.new('RGBA',(560,400));sh.alpha_composite(Image.open(O/f'sheath_{i:02}.png'),(dx,dy));comp=Image.new('RGBA',(560,400));comp.alpha_composite(sh)
 if m['frames'][i]['weapon_behind']:comp.alpha_composite(weapon)
 comp.alpha_composite(body)
 if not m['frames'][i]['weapon_behind']:comp.alpha_composite(weapon)
 x,y=map(round,grip);comp.alpha_composite(body.crop((x-3,y-3,x+4,y+4)),(x-3,y-3))
 for name,im in [('upper',upper),('lower',lower),('body_canvas',body),('sword',weapon),('sheath',sh),('composite',comp)]:im.save(D/f'{name}_{i:02}.png')
 r={'frame':i,'frame_1based':i+1,'upper_translation':[dx,dy],'upper_source':str(handbody.relative_to(P)) if i in hands else 'original/body_canvas_'+f'{i:02}.png','upper_cut_y_original':308,'lower_source':item,'right_support':[205,365],'left_sole_estimate':L,'grip_world':grip,'duration_ms':m['frames'][i]['duration_ms'],'candidate_only':True,'lower_vertical_registration_scale':None if item is None else sy,'waist_world_y':282};recs.append(r)
 bg=Image.new('RGBA',(560,400),(47,53,61,255));bg.alpha_composite(comp);dr=ImageDraw.Draw(bg);dr.line((0,366,560,366),fill=(80,90,100));dr.text((10,10),f'LEG STEP CANDIDATE {i+1}/17 | 1300ms',fill='white');dr.text((10,28),f'upper shift {dx},{dy}; not final',fill='white');frames.append(bg.convert('RGB'));bg=Image.new('RGBA',(560,400),(47,53,61,255));bg.alpha_composite(lower);legs.append(bg.convert('RGB'))
ds=[r['duration_ms'] for r in recs]
for name,fs,f in [('normal',frames,1),('slow',frames,3),('legs_only',legs,1)]:fs[0].save(D/f'{name}.gif',save_all=True,append_images=fs[1:],duration=[t*f for t in ds],disposal=2)
cs=Image.new('RGB',(2240,2000),(47,53,61));[cs.paste(f,((i%4)*560,(i//4)*400)) for i,f in enumerate(frames)];cs.save(D/'contact_sheet.jpg',quality=95)
steps=[round(math.dist(recs[i]['left_sole_estimate'],recs[i-1]['left_sole_estimate']),1) for i in range(1,17)];json.dump({'candidate':True,'not_final':True,'frames':recs,'left_foot_frame_steps':steps,'max_left_foot_step':max(steps),'original_worst_left_foot_step':130.1,'limitations':['Generated candidate lower-body orientations and seam require visual review','Left step is staged, not mathematically uniform circular trajectory','No realtime playback review']},open(D/'metadata.json','w'),indent=2);print('steps',steps,'max',max(steps));print('upper shifts',[r['upper_translation'] for r in recs])
