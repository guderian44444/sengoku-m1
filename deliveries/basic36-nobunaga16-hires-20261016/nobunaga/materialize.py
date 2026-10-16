from pathlib import Path
from PIL import Image
from scipy import ndimage
import numpy as np,json,hashlib,math,shutil,ast,os
R=Path('nobunaga_impact_v4');O=Path('nobunaga_final_approved');BG=(37,39,43);A=json.load(open(O/'inventory.json'));C={c['key']:c for c in A['clips']};CACHE={}
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def normpath(p):
 try:return str(Path(p).relative_to(Path.cwd()))
 except:return str(p)
def imageinfo(p):
 im=Image.open(p);return {'path':str(p),'sha256':sha(p),'dimensions':list(im.size),'mode':im.mode,'alpha_extrema':list(im.getchannel('A').getextrema()) if im.mode=='RGBA' else None}
def equal_metrics(a,b):
 a=np.asarray(a.convert('RGB')).astype('int16');b=np.asarray(b.convert('RGB')).astype('int16');d=np.abs(a-b)
 return {'pixel_exact':not bool(d.max()),'max_channel_difference':int(d.max()),'mean_absolute_channel_difference':round(float(d.mean()),8),'different_pixel_count':int(np.any(d,axis=2).sum()),'compared_pixel_count':int(d.shape[0]*d.shape[1])}
def composite_bg(im):
 o=Image.new('RGBA',im.size,BG+(255,));o.alpha_composite(im.convert('RGBA'));return o.convert('RGB')
def rgba_from_flat(im):
 a=np.array(im.convert('RGB'));alpha=np.where(np.all(a==BG,axis=2),0,255).astype('uint8');return Image.fromarray(np.dstack((a,alpha)))
def clean_rgb(path,kind):
 a=np.array(Image.open(path).convert('RGB'))
 if kind=='light_2':
  ai=a.astype(int);v=ai.max(2);sat=v-ai.min(2);bg=(sat<27)&(v<80)&(ai[:,:,2]>ai[:,:,0])&(ai[:,:,1]>=ai[:,:,0]);lab,c=ndimage.label(~bg);counts=np.bincount(lab.ravel());counts[0]=0;j=counts.argmax();mask=ndimage.binary_dilation(ndimage.binary_fill_holes(lab==j),iterations=1);a[~mask]=BG
 elif kind=='light_3':
  v=a.max(2).astype(int);mi=a.min(2).astype(int);r,g,b=[a[:,:,i].astype(int) for i in range(3)];bg=(v-mi<28)&(v<90)&(b>=r+1)&(g>=r+1);lab,n=ndimage.label(bg);ct=np.bincount(lab.ravel());keep=ct>120;keep[0]=False;a[keep[lab]]=BG
 elif kind!='already_composited':
  v=a.max(2);sat=v-a.min(2);cand=(sat<28)&(v<95)&(a[:,:,2]>=a[:,:,0]);labs,n=ndimage.label(cand);ids=np.unique(np.r_[labs[0],labs[-1],labs[:,0],labs[:,-1]]);a[np.isin(labs,ids[ids>0])]=BG
 return Image.fromarray(a)
def clean_alpha(path):
 a=np.array(Image.open(path).convert('RGBA'))
 if a[:,:,3].min()==255:
  v=a[:,:,:3].max(2);sat=v-a[:,:,:3].min(2);cand=(sat<28)&(v<95)&(a[:,:,2]>=a[:,:,0]);lab,n=ndimage.label(cand);ids=np.unique(np.r_[lab[0],lab[-1],lab[:,0],lab[:,-1]]);a[np.isin(lab,ids[ids>0]),3]=0
 else:
  lab,n=ndimage.label(a[:,:,3]>70);ct=np.bincount(lab.ravel());good=ct>80;good[0]=False;a[:,:,3]=np.where(good[lab],a[:,:,3],0)
 return Image.fromarray(a)
def draw_native(im,scale,offset,size,mode='rgba'):
 z=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
 if mode=='rgb':out=Image.new('RGB',size,BG);out.paste(z.convert('RGB'),tuple(offset));return out
 out=Image.new('RGBA',size,BG+(255,));out.alpha_composite(z.convert('RGBA'),tuple(offset));return out.convert('RGB')
def link(src,dst):
 dst.parent.mkdir(parents=True,exist_ok=True)
 if dst.exists():return
 try:os.link(src,dst)
 except OSError:shutil.copy2(src,dst)
def save(k,i,im,source,transform,cleaned=None,reference_render=None,note=None,layers=None):
 d=O/k;path=d/'frames-composite'/f'{i:03}.png';path.parent.mkdir(parents=True,exist_ok=True);im.save(path,compress_level=3)
 r={'frame':i,'duration_ms':C[k]['approved_preview']['durations_ms'][i],'output':imageinfo(path),'original_sources':[normpath(x) for x in source],'source_to_review':transform,'method_note':note,'source_art_changed':False}
 if cleaned is not None:r['native_reconstruction_on_approved_background']=equal_metrics(composite_bg(im),cleaned)
 target=Image.open(Path(C[k]['approved_preview']['review_directory'])/f'{i:03}.png').convert('RGB')
 if transform:
  rendered=draw_native(im,transform['scale'],transform['offset'],target.size)
  r['transparent_master_render_vs_approved_review']=equal_metrics(rendered,target)
 if reference_render is not None:r['exact_approved_recipe_reconstruction_vs_review']=equal_metrics(reference_render,target)
 if layers:r['layers']=layers
 CACHE.setdefault(k,[]).append(r)
 (d/'source-mapping.json').write_text(json.dumps({'key':k,'frames':CACHE[k],'approved_preview':C[k]['approved_preview'],'background_rgb':BG,'warning':'Advisory art mapping, not runtime hitboxes, weapon sockets or world-space events.'},indent=2))
def finish(k):
 rs=CACHE[k];ex=sum(r.get('exact_approved_recipe_reconstruction_vs_review',{}).get('pixel_exact',False) for r in rs);print(k,len(rs),'materialized; exact recipe',ex,flush=True)
# Existing, final high-resolution RGBA grab-family actor composites.
for k in ['grab_hold','grab_hit_1','grab_hit_2']:
 for i,item in enumerate(C[k]['original_resolution_sources']):
  p=Path(item['path']);im=Image.open(p).convert('RGBA');tr={'scale':.55,'offset':[390,210]};ref=draw_native(im,.55,[390,210],(1440,1200));save(k,i,im,[p],tr,composite_bg(im),ref,'Existing RGBA actor composite copied without pixel changes; body, held sword and hands are fused.')
 finish(k)
# Rebuild the same approved native body/canonical sword composition used in grab_start candidate-b.
k='grab_start';root=R/'grab_start_hires';old=json.load(open(root/'frame-manifest.json'));tmpl=Image.open(R/'charge_ready_hires/source/shortened-blade.png').convert('RGBA')
bp=[((568,517),(418,96)),((697,440),(691,47)),((687,414),(936,37)),((738,456),(1080,79)),((748,529),(1168,206)),((734,571),(1189,304)),((720,579),(1206,429)),((720,637),(1211,577))]
def erase(im,base,tip):
 a=np.array(im);h,w=a.shape[:2];y,x=np.mgrid[:h,:w];dx,dy=tip[0]-base[0],tip[1]-base[1];ln=math.hypot(dx,dy);al=((x-base[0])*dx+(y-base[1])*dy)/ln;cr=(-(x-base[0])*dy+(y-base[1])*dx)/ln;v=a[:,:,:3].max(2);sat=v-a[:,:,:3].min(2);m=(al>0)&(al<ln+12)&(abs(cr)<45)&(v>78)&(sat<76);m=ndimage.binary_dilation(ndimage.binary_fill_holes(m),iterations=2)&(al>0);a[m,3]=0;return Image.fromarray(a)
def blade_at(size,scale,base,tip,pos):
 b=np.array(base)*scale+pos;ang=math.atan2(base[1]-tip[1],tip[0]-base[0])-math.atan2(29,441);c,s=math.cos(ang),math.sin(ang);tr=(c/scale,-s/scale,(-c*b[0]+s*b[1])/scale,s/scale,c/scale,49+(-s*b[0]-c*b[1])/scale);return tmpl.transform(size,Image.Transform.AFFINE,tr,Image.Resampling.BICUBIC)
for i in range(8):
 row=old[i];p=Path(row['native_source']);body=erase(clean_alpha(p),*bp[i]);weapon=blade_at(body.size,1,*bp[i],np.array([0.,0.]));im=body.copy();im.alpha_composite(weapon);off=np.array([1086,1218])-np.array(row['source_support'])*1.18;pos=np.array([390,210])+off*.55;scale=.55*1.18;tr={'scale':scale,'offset':np.rint(pos).astype(int).tolist(),'unrounded_position':pos.tolist(),'recipe':'Body is resized with LANCZOS; weapon is separately affine transformed to output canvas. Rounded layer positions cause native-composite render differences.'};ref=Image.new('RGBA',(1440,1200),BG+(255,));ref.alpha_composite(body.resize((round(body.width*scale),round(body.height*scale)),Image.Resampling.LANCZOS),tuple(np.rint(pos).astype(int)));ref.alpha_composite(blade_at(ref.size,scale,*bp[i],pos))
 layers={}
 for name,layer in [('body',body),('weapon',weapon)]:q=O/k/'layers-native'/name/f'{i:03}.png';q.parent.mkdir(parents=True,exist_ok=True);layer.save(q,compress_level=3);layers[name]=str(q)
 save(k,i,im,[p,R/'charge_ready_hires/source/shortened-blade.png'],tr,composite_bg(im),ref,'Approved candidate-b native composition reconstructed at original donor dimensions; 004/005 use corrected canonical blade roots.',layers)
conf=json.load(open(R/'grab_start_swordheld/native-registration.json'))
for i,item in enumerate(conf,8):
 p=Path(item['path']);im=clean_alpha(p);scale=.55*item.get('anatomical_scale',1);off=np.array([1086,1218])-np.array(item['front_foot'])*item.get('anatomical_scale',1);pos=np.rint(np.array([390,210])+off*.55).astype(int).tolist();tr={'scale':scale,'offset':pos};ref=draw_native(im,scale,pos,(1440,1200));save(k,i,im,[p],tr,composite_bg(im),ref,'Approved source component-alpha cleanup copied from grab_start_swordheld/build.py; no new image generation.')
finish(k)
k='throw_forward';rows=C[k]['source_records']
for i,row in enumerate(rows):
 if i<9:
  p=R/f'throw_forward_swordheld/frames-native/{i:03}.png';im=Image.open(p).convert('RGBA');tr={'scale':.55,'offset':[390,210]}
 else:
  j=row['reuse_grab_start_frame'];q=CACHE['grab_start'][j];p=Path(q['output']['path']);im=Image.open(p).convert('RGBA');tr=q['source_to_review']
 ref=draw_native(im,tr['scale'],tr['offset'],(1440,1200));save(k,i,im,[p],tr,composite_bg(im),ref if i<9 or j>=8 else None,'Native approved forward frames000–008; recovery reuses original-resolution reconstructed grab-start masters, never review upscaling.')
finish(k)
# Native RGB masters: reproduce each build's existing background cleanup, then expose exact flat BG as alpha.
for k in ['light_1','light_2','light_3','heavy','dash_heavy','air_light','air_heavy','charge_ready','charge_hold']:
 rows=C[k]['source_records']
 for i,item in enumerate(C[k]['original_resolution_sources']):
  p=Path(item['path']);kind='already_composited' if k in ['charge_ready','charge_hold'] else k;rgb=clean_rgb(p,kind);im=rgba_from_flat(rgb);row=rows[i]
  if k in ['light_2','light_3','air_light','air_heavy']:tr={kk:row['review'][kk] for kk in ['scale','offset']}
  elif k=='light_1':sc=.58;sup=row['support_sole_native'];tr={'scale':sc,'offset':[round(630-sup[0]*sc),round(1020-sup[1]*sc)]}
  elif k in ['heavy','dash_heavy']:sc=.58;sup=row['front_sole_native'];tr={'scale':sc,'offset':[round(830-sup[0]*sc),round(1020-sup[1]*sc)]}
  else:tr={'scale':.58,'offset':[-66,237],'mapping_status':'affine relationship between independently rendered native and review canvases; resampling differs'}
  target=Image.open(Path(C[k]['approved_preview']['review_directory'])/f'{i:03}.png');ref=draw_native(rgb,tr['scale'],tr['offset'],target.size,mode='rgb') if k not in ['charge_ready','charge_hold'] else None
  save(k,i,im,[p],tr,rgb,ref,'Original native/composited dimensions retained. Exact approved background-normalization rule; pixels equal to approved flat BG become transparent. Reconstruction on BG is exact; alpha-resizing can differ at edges from approved RGB-resize pipeline.')
 finish(k)
# Charge release: reconstruct full native transparent layers using only definitions and assets from approved builder.
k='charge_release';d=R/'charge_release_hires_range150';tree=ast.parse((d/'build_preview.py').read_text());env={'Image':Image,'np':np,'math':math,'BG':BG}
for node in tree.body:
 if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id in ['DUR','YAWS','keys','CONF','LAYERS'] for t in node.targets):exec(compile(ast.Module(body=[node],type_ignores=[]),str(d/'build_preview.py'),'exec'),env)
 if isinstance(node,ast.FunctionDef) and node.name in ['blade','fx']:exec(compile(ast.Module(body=[node],type_ignores=[]),str(d/'build_preview.py'),'exec'),env)
env['TEMPLATE']=tmpl;oldfx=Path('nobunaga_impact_v3/charge_release/source');env['TEX']=Image.open(oldfx/'silver_blade_orbit_topdown.png').convert('RGBA');shards=[Image.open(oldfx/f'silver_shard_{i}.png').convert('RGBA') for i in range(3)];shards[2]=shards[2].rotate(-57,Image.Resampling.BICUBIC,expand=True);shards[2]=shards[2].crop(shards[2].getbbox());env['SHARDS']=shards
for i,(key,yaw) in enumerate(zip(env['keys'],env['YAWS'])):
 p=d/f'frames-composited/{i:03}.png';rgb=Image.open(p).convert('RGB');layers={};sz=(4000,1800);sc=1;anchor=(2000,1500)
 if i==0:im=rgba_from_flat(rgb)
 else:
  conf=env['CONF'][key];body=Image.open(d/f'layers/body-native/{key}.png').convert('RGBA');target=np.array(anchor,float)
  if i>=21:target[0]+=70*(sc*2.25/.58)
  off=target-np.array(conf['support'])*sc;bo=Image.new('RGBA',sz);bo.alpha_composite(body,tuple(np.rint(off).astype(int)));base=np.array(conf['base'])*sc+off;wp=env['blade'](sz,sc,base,yaw,key);behind=yaw is not None and 20<yaw%360<165;actor=Image.new('RGBA',sz)
  if behind:actor.alpha_composite(wp)
  actor.alpha_composite(bo)
  if not behind:actor.alpha_composite(wp)
  back,front,_=env['fx'](sz,i,yaw,anchor,sc);im=back.copy();im.alpha_composite(actor);im.alpha_composite(front)
  for name,layer in [('actor',actor),('body',bo),('weapon',wp),('fx_back',back),('fx_front',front)]:
   q=O/k/'layers-native'/name/f'{i:03}.png';q.parent.mkdir(parents=True,exist_ok=True);layer.save(q,compress_level=3);layers[name]=str(q)
 tr={'scale':.58,'offset':[-50,150],'mapping_status':'independently rendered native versus review; exact review actor uses preserved original layers'}
 save(k,i,im,[p],tr,rgb,None,'Native transparent full composition reconstructed using approved build definitions and full native sources; review layers retained separately byte-for-byte.',layers)
finish(k)
# Preserve existing layer assets without resampling or changing content.
for k,clip in C.items():
 if k=='throw_reverse':continue
 for item in clip['existing_layers']:
  src=Path(item['path']);root=Path(clip['selected_root']);name=src.relative_to(root) if src.is_relative_to(root) else Path('shared')/src.name;dst=O/k/'existing-layers'/name;link(src,dst)
manifest={'schema':'nobunaga-transparent-source-materialization-v1','source_art_unmodified':True,'new_art_generated':False,'runtime_site_git_modified':False,'background_rgb':BG,'clips':{k:{'frames':len(rows),'mapping':str(O/k/'source-mapping.json'),'frame_directory':str(O/k/'frames-composite')} for k,rows in CACHE.items()},'limitations':['RGB matte is lossless on approved BG at native size; RGBA resampling is not mathematically identical to original RGB resampling. Per-frame measured differences are provided.','Grab-start first8, forwarded recovery, and charge composites preserve original donor/template sources and rendering recipe; precomposing then resizing can differ from independently transformed layers.','No runtime weapon sockets, hitboxes, victim attachment or event contract is invented.']}
(O/'materialization.json').write_text(json.dumps(manifest,indent=2))
for k,rows in CACHE.items():C[k]['transparent_materialization']={'source_mapping':str(O/k/'source-mapping.json'),'frame_directory':str(O/k/'frames-composite'),'frames':len(rows)}
(O/'inventory.json').write_text(json.dumps(A,ensure_ascii=False,indent=2));print('ALL DONE',sum(len(x) for x in CACHE.values()),flush=True)
