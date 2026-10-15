from pathlib import Path
from PIL import Image,ImageDraw
import json,shutil,hashlib,math,copy
P=Path(__file__).resolve().parents[1];G=P/'grabs'
changes={'throw_reverse':{1:.98,4:.97,5:.97,6:.97,9:.97},'throw_forward':{1:.98,3:.98,4:.98,7:.98,10:.98},'air_heavy':{4:.98,6:.98,7:.98},'dash_heavy':{2:.98,5:.98}}
regbackup=G/'registration_before_scale_refine.json'
if not regbackup.exists():shutil.copy2(G/'registration.json',regbackup)
M=json.loads(regbackup.read_text());report={}
def point(p,k,c):return [c[0]+k*(p[0]-c[0]),c[1]+k*(p[1]-c[1])]
def scale(im,k,c):return im.transform(im.size,Image.Transform.AFFINE,(1/k,0,c[0]*(1-1/k),0,1/k,c[1]*(1-1/k)),Image.Resampling.BICUBIC)
def shift(im,dx,dy):return im.transform(im.size,Image.Transform.AFFINE,(1,0,-dx,0,1,-dy),Image.Resampling.BICUBIC)
def backup(D):
 B=D/'before_scale_refine'
 if not B.exists():
  B.mkdir()
  for p in D.iterdir():
   if p.is_file():shutil.copy2(p,B/p.name)
 return B
for name in list(M)+['air_heavy','dash_heavy']:
 grab=name in M;D=(G/name) if grab else P/'actions'/name;B=backup(D);m=M[name] if grab else json.loads((B/'metadata.json').read_text());recs=m['frames'];frames=[];bodyframes=[];rows=[]
 for i,r in enumerate(recs):
  k=changes.get(name,{}).get(i,1.0);pivot=(r['screen_left_foot'] if name=='throw_reverse' else r['screen_right_foot']) if grab else r['root_world'];pivot=list(pivot)
  names=['body','weapon','proxy'] if grab else ['body_canvas','sword','sheath'];ims={n:Image.open(B/f'{n}_{i:02}.png').convert('RGBA') for n in names};old=copy.deepcopy(r)
  if k!=1:
   bn='body' if grab else 'body_canvas';ims[bn]=scale(ims[bn],k,pivot)
   if grab:
    for key in ['right_hand','left_hand','grasp_contact','waist','screen_left_foot','screen_right_foot']:
     if key in r:r[key]=point(r[key],k,pivot)
    dx,dy=[r['waist'][a]-old['waist'][a] for a in (0,1)];ims['weapon']=shift(ims['weapon'],dx,dy)
    if r.get('grasp_active',False):
     dx,dy=[r['grasp_contact'][a]-old['grasp_contact'][a] for a in (0,1)];ims['proxy']=shift(ims['proxy'],dx,dy)
    r['scale']*=k
   else:
    if 'grip_world' not in r:
     gx,gy=r['source_grip'];fx,fy=r['source_foot'];s=r['body_scale'];r['grip_world']=[r['root_world'][0]+(gx-fx)*s,r['root_world'][1]+(gy-fy)*s]
    for key,layer in [('grip_world','sword'),('saya_mouth','sheath')]:
     prev=r[key];r[key]=point(prev,k,pivot);ims[layer]=shift(ims[layer],r[key][0]-prev[0],r[key][1]-prev[1])
    r['body_scale']*=k
   r['post_scale_refinement']={'factor':k,'fixed_support_world':pivot,'basis':'conservative visual head + torso + shin-armor comparison, not bbox height','from_snapshot':'before_scale_refine','weapon_physical_length_preserved':True}
  for n,im in ims.items():im.save(D/f'{n}_{i:02}.png')
  bn='body' if grab else 'body_canvas';r['body_sha256' if grab else 'body_canvas_sha256']=hashlib.sha256((D/f'{bn}_{i:02}.png').read_bytes()).hexdigest()
  if grab:
   r['body_bounds']=list(ims['body'].getbbox());comp=Image.new('RGBA',(480,280));comp.alpha_composite(ims['proxy']);comp.alpha_composite(ims['weapon']);comp.alpha_composite(ims['body'])
   if name.startswith('throw') and not r.get('grasp_active',True):comp.alpha_composite(ims['proxy'])
   clean=Image.new('RGBA',(480,280),(53,62,72,255));clean.alpha_composite(ims['weapon']);clean.alpha_composite(ims['body']);bodyframes.append(clean.convert('RGB'))
  else:
   comp=Image.new('RGBA',(560,400));comp.alpha_composite(ims['sheath']);comp.alpha_composite(ims['body_canvas']);comp.alpha_composite(ims['sword']);grip=r.get('grip_world')
   if grip:
    x,y=map(round,grip);comp.alpha_composite(ims['body_canvas'].crop((x-4,y-4,x+4,y+4)),(x-4,y-4))
   if k==1:comp=Image.open(B/f'composite_{i:02}.png').convert('RGBA')
   comp.save(D/f'composite_{i:02}.png')
  bg=Image.new('RGBA',comp.size,(53,62,72,255) if grab else (47,53,61,255));dr=ImageDraw.Draw(bg);dr.line((0,221 if grab else (370 if name=='air_heavy' else 366),comp.width,221 if grab else (370 if name=='air_heavy' else 366)),fill=(80,91,103));bg.alpha_composite(comp);dr=ImageDraw.Draw(bg);dr.text((10,8),f'Ieyasu06 {name} {i+1}/{len(recs)} | scale refined',fill='white')
  if grab:dr.text((10,24),'Neutral measuring proxy, not final enemy',fill=(180,190,200))
  frames.append(bg.convert('RGB'));rows.append({'frame_1based':i+1,'factor':k,'support_pivot':pivot,'root_preserved':r.get('root_world',r.get('root'))==old.get('root_world',old.get('root'))})
 ds=[r['duration_ms'] for r in recs];opts={} if name.startswith('throw') or name=='air_heavy' else {'loop':0}
 for suffix,mul in [('normal',1),('slow',3)]:frames[0].save(D/(suffix+'.gif' if grab else name+'_'+suffix+'.gif'),save_all=True,append_images=frames[1:],duration=[v*mul for v in ds],disposal=2,**opts)
 cols=3 if grab else 4;w,h=frames[0].size;sheet=Image.new('RGB',(w*cols,h*math.ceil(len(frames)/cols)),(53,62,72));[sheet.paste(f,((i%cols)*w,(i//cols)*h)) for i,f in enumerate(frames)]
 if grab:
  sheet.resize((960,187*math.ceil(len(frames)/3))).save(D/'contact.jpg');bodyframes[0].save(D/'body_only.gif',save_all=True,append_images=bodyframes[1:],duration=ds,disposal=2,**opts)
 else:sheet.save(D/'contact_sheet.png');(D/'metadata.json').write_text(json.dumps(m,indent=2))
 report[name]={'frames':rows,'duration_ms':sum(ds),'frame_count':len(recs),'no_redrawing':True,'visual_contact_review_only':True};(D/'scale_refinement.json').write_text(json.dumps(report[name],indent=2))
(G/'registration.json').write_text(json.dumps(M,indent=2));(P/'scale_refinement_grabs_air_dash.json').write_text(json.dumps(report,indent=2))
# Preserve exact grab handoff and duplicated headbutt visuals.
for n in ['grab_hit_1','grab_hit_2']:
 for j in [0,5]:assert (G/n/f'body_{j:02}.png').read_bytes()==(G/'grab_hold/body_00.png').read_bytes()
for n,j in [('grab_start',5),('throw_forward',0),('throw_reverse',0)]:assert (G/n/f'body_{j:02}.png').read_bytes()==(G/'grab_hold/body_00.png').read_bytes()
print({n:[r for r in x['frames'] if r['factor']!=1] for n,x in report.items()})
