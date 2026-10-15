from pathlib import Path
from PIL import Image,ImageDraw
import numpy as np,json,shutil,copy
from scipy.ndimage import label,binary_dilation
from build_rest import transform
P=Path(__file__).resolve().parents[1];D=P/'actions/charge_ready';S=P/'actions/charge_release';H=P/'actions/charge_hold'
B=D/'before_single_hand';
if not B.exists():
 B.mkdir()
 for f in D.glob('*'):
  if f.is_file():shutil.copy(f,B/f.name)
m=json.load(open(B/'metadata.json'));recs=[];out=[];ds=[100,100,110,110,120,130]
a=np.array(Image.open(D/'entry_source.png'));l,k=label(a[:,:,3]>30);sizes=np.bincount(l.ravel());qs=np.argsort(sizes[1:])[-3:]+1;qs=sorted(qs,key=lambda q:np.where(l==q)[1].mean());sw=Image.open(P/'reference/tachi.png');sa=Image.open(P/'reference/saya.png')
for i in range(6):
 if i<2:
  rec=copy.deepcopy(m['frames'][i]);rec['root_world']=[205,365]
  for kind in ['body_canvas','sword','sheath','composite']:
   im=Image.open(B/f'{kind}_{i:02}.png');n=Image.new('RGBA',im.size);n.alpha_composite(im,(78,0));n.save(D/f'{kind}_{i:02}.png')
  shutil.copy(B/f'body_{i:02}.png',D/f'body_{i:02}.png')
 elif i==5:
  rec=copy.deepcopy(json.load(open(S/'metadata.json'))['frames'][0])
  for kind in ['body','body_canvas','sword','sheath','composite']:shutil.copy(S/f'{kind}_00.png',D/f'{kind}_{i:02}.png')
 else:
  j=i-2;ar=a.copy();ar[:,:,3]=np.where(binary_dilation(l==qs[j],iterations=2),a[:,:,3],0);ys,xs=np.where(ar[:,:,3]>0);box=(int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1));body=Image.fromarray(ar).crop(box);s=152/675;rx,ry=[(65,695),(765,695),(1490,695)][j];gx,gy=[(278,411),(688,207),(1401,183)][j];ox=205-rx*s;oy=365-ry*s;layer=Image.new('RGBA',(560,400));layer.alpha_composite(body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS),(round(ox+box[0]*s),round(oy+box[1]*s)));grip=(ox+gx*s,oy+gy*s);weapon=transform(sw,(100,1080),grip,[-80,-90,-90][j],.085);sheath=transform(sa,(87,22),(ox+(box[0]+body.width*.5)*s,oy+(box[1]+body.height*.5)*s),65,.07);comp=Image.new('RGBA',(560,400));comp.alpha_composite(sheath);comp.alpha_composite(layer);comp.alpha_composite(weapon);patch=Image.fromarray(ar).crop((gx-14,gy-14,gx+14,gy+14)).resize((7,7));comp.alpha_composite(patch,(round(grip[0]-3.5),round(grip[1]-3.5)))
  for kind,im in [('body',body),('body_canvas',layer),('sword',weapon),('sheath',sheath),('composite',comp)]:im.save(D/f'{kind}_{i:02}.png')
  rec=dict(source='entry_source.png',source_pose=j,source_crop=box,source_grip=[gx,gy],support_foot=[rx,ry],root_world=[205,365],body_scale=s)
 rec.update(frame=i,duration_ms=ds[i],event='hold_enter' if i==5 else None);recs.append(rec)
 comp=Image.open(D/f'composite_{i:02}.png');bg=Image.new('RGB',comp.size,(47,53,61));bg.paste(comp,mask=comp.getchannel('A'));dr=ImageDraw.Draw(bg);dr.line((0,366,560,366),fill=(80,86,93));dr.text((12,10),f'IEYASU 06 charge ready -> single right hand / {i+1}/6 / 670ms',fill='white');out.append(bg)
for suf,v in [('normal',1),('slow',3)]:out[0].save(D/f'charge_ready_{suf}.gif',save_all=True,append_images=out[1:],duration=[x*v for x in ds],disposal=2)
cs=Image.new('RGB',(560*3,800),(47,53,61))
for i,f in enumerate(out):cs.paste(f,((i%3)*560,(i//3)*400))
cs.save(D/'contact_sheet.png');json.dump(dict(action='charge_ready',frames=recs,total_ms=670,revision='left hand releases and right arm extends before holding'),open(D/'metadata.json','w'),indent=2)
for kind in ['body','body_canvas','sword','sheath','composite']:shutil.copy(D/f'{kind}_05.png',H/f'{kind}_00.png')
b=out[-1];b.save(H/'charge_hold_normal.gif',duration=760,loop=0);b.save(H/'charge_hold_slow.gif',duration=2280,loop=0);b.save(H/'contact_sheet.png');q=copy.deepcopy(recs[-1]);q.update(frame=0,duration_ms=760,event='full_charge_hold');json.dump(dict(action='charge_hold',frames=[q],total_ms=760,source='exact ready final = release first'),open(H/'metadata.json','w'),indent=2)
assert all((H/f'{k}_00.png').read_bytes()==(S/f'{k}_00.png').read_bytes() for k in ['body','body_canvas','sword','sheath','composite'])
