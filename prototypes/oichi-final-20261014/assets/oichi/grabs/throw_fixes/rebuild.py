from PIL import Image,ImageDraw
from scipy.ndimage import label,find_objects,distance_transform_edt
from pathlib import Path
import numpy as np,json,hashlib
P=Path(__file__).parent;S=P.parent

def isolate(file,name):
 im=Image.open(S/file).convert('RGBA');a=np.array(im);lab,num=label(a[:,:,3]>32);objs=find_objects(lab);major=[]
 for k,sl in enumerate(objs):
  if np.sum(lab[sl]==k+1)>20000:major.append((k+1,sl))
 major.sort(key=lambda t:(0 if t[1][0].start<500 else 1,t[1][1].start));assert len(major)==8
 core=np.zeros(lab.shape,np.int16)
 for i,(k,sl) in enumerate(major):core[lab==k]=i+1
 inds=distance_transform_edt(core==0,return_distances=False,return_indices=True);owner=core[tuple(inds)];total=np.zeros(a.shape[:2],np.uint16);out=[]
 for i,(k,sl) in enumerate(major):
  mask=owner==i+1;b=a.copy();b[:,:,3]=np.where(mask,a[:,:,3],0);total+=b[:,:,3];ys,xs=np.where(b[:,:,3]>0);rect=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)];crop=Image.fromarray(b).crop(rect);d=P/name;d.mkdir(exist_ok=True);crop.save(d/f'body_{i:02}.png');out.append(dict(file=f'{name}/body_{i:02}.png',rect=rect,core_label=k))
 assert np.array_equal(total,a[:,:,3].astype(np.uint16));return out

def build(name,src):
 crops=isolate(src,name);meta=json.loads((S/(name+'.json')).read_text());frames=[];records=[];bow=Image.open(S/'bow_azusa.png').convert('RGBA');bow.thumbnail((44,133));bow=bow.rotate(18,expand=True,resample=Image.Resampling.BICUBIC);s=148/490
 for i,c in enumerate(crops):
  old=meta['frames'][i];cx,cy=old['source_rect'][:2];rx,ry=old['root'];gx,gy=c['rect'][:2];body=Image.open(P/c['file']);small=body.resize((round(body.width*s),round(body.height*s)),Image.Resampling.LANCZOS);off=(round(155+(gx-cx-rx)*s),round(194+(gy-cy-ry)*s));canvas=Image.new('RGBA',(400,240),'#313845');victim=Image.open(P/name/f'victim_{i:02}.png');canvas.alpha_composite(victim);victim.save(P/name/f'victim_{i:02}.png');weapon=Image.new('RGBA',canvas.size);weapon.alpha_composite(bow,(round(155+(170-rx)*s),round(194+(100-ry)*s)));weapon.save(P/name/f'weapon_{i:02}.png');canvas.alpha_composite(weapon);canvas.alpha_composite(small,off);d=ImageDraw.Draw(canvas);d.text((10,8),name+' | isolated edges | 148px',fill='white');d.text((10,220),'Prototype / neutral victim separately layered',fill='#bdc8d8');frames.append(canvas.convert('RGB'));records.append(dict(frame=i,isolated_file=c['file'],source_rect=c['rect'],root_full_sheet=[cx+rx,cy+ry],preview_offset=off,duration_ms=old['duration_ms'],events=old['events'],isolation='Nearest complete figure core ownership; all source alpha conserved across 8 outputs'))
 frames[0].save(P/(name+'_clean_148px.gif'),save_all=True,append_images=frames[1:],duration=[r['duration_ms'] for r in records],loop=0,disposal=2)
 # Contact sheet of exactly the actual composited preview frames for visual edge check.
 sheet=Image.new('RGB',(800,960))
 for i,f in enumerate(frames):sheet.paste(f,(i%2*400,i//2*240))
 sheet.save(P/(name+'_qa.jpg'));(P/(name+'_metadata.json')).write_text(json.dumps(dict(clip=name,prototype=True,source=src,source_sha256=hashlib.sha256((S/src).read_bytes()).hexdigest(),alpha_union_verified=True,frames=records),indent=2))
if __name__=='__main__':
 import sys
 for n in sys.argv[1:] or ['throw_forward','throw_reverse']:build(n,'throw_forward.png' if n=='throw_forward' else 'throw_reverse_v2.png')
