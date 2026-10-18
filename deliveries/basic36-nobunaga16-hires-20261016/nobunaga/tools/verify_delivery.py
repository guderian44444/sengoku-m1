from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib,sys
D=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def visible_equal(a,b):
 a=np.array(a.convert('RGBA'));b=np.array(b.convert('RGBA'));return a.shape==b.shape and np.array_equal(a[:,:,3],b[:,:,3]) and np.array_equal(a[a[:,:,3]>0],b[a[:,:,3]>0])
def checked(spec):
 p=D/spec['path'];assert p.exists(),p;assert sha(p)==spec['sha256'],f'hash mismatch {p}';return p
M=json.load(open(D/'delivery-manifest.json'));result=[];count=0;total=0
for c in M['clips']:
 gif=Image.open(checked(c['approved_preview']));ds=[]
 for i in range(gif.n_frames):gif.seek(i);ds.append(gif.info.get('duration',0))
 assert ds==c['durations_ms'];assert gif.n_frames==c['frame_count'];assert sum(ds)==c['duration_ms'];rows=json.load(open(D/c['frames_manifest']));assert len(rows)==gif.n_frames;tt=0;rs=[]
 for r in rows:
  i=r['frame'];assert r['start_ms']==tt;tt+=r['duration_ms'];assert r['end_ms']==tt;master=Image.open(checked(r['master'])).convert('RGBA');checked(r['approved_review']);ls=[Image.open(checked(r['layers'][name])).convert('RGBA') for name in r['layer_order_back_to_front']];assert all(x.size==master.size for x in ls)
  occupied=np.zeros((master.height,master.width),np.uint8)
  for l in ls:occupied+=(np.array(l)[:,:,3]>0).astype('uint8')
  assert occupied.max()<=1,(c['key'],i,'ownership overlaps')
  comp=ls[0].copy()
  for l in ls[1:]:comp.alpha_composite(l)
  actor=Image.open(checked(r['actor_without_fx'])).convert('RGBA') if 'actor_without_fx' in r else master
  assert visible_equal(comp,actor),(c['key'],i,'actor recomposition')
  exact4=np.array_equal(np.array(comp),np.array(actor))
  if 'fx_back_front' in r:
   back,front=[Image.open(checked(f)).convert('RGBA') for f in r['fx_back_front']];full=back.copy();full.alpha_composite(comp);full.alpha_composite(front)
  else:full=comp
  assert visible_equal(full,master),(c['key'],i,'full recomposition')
  assert r['layer_transform_native']==[1,0,0,0,1,0];assert not r['preview_translation_is_world_movement'];assert r['runtime_world_displacement'] is None
  for pt in [r['root_art_native_px'],*r['foot_art_native_px']]:
   if pt is not None:assert len(pt)==2 and all(np.isfinite(pt)),(c['key'],i,'bad anchor')
  rs.append({'frame':i,'visible_rgba_exact':True,'alpha_exact':True,'disjoint_layer_ownership':True,'actor_all_rgba_bytes_exact':bool(exact4),'master_dimensions_preserved':True});count+=1
 result.append({'key':c['key'],'frames':len(rs),'duration_ms':tt,'gif_sha256_match':True,'gif_durations_match':True,'frames_validation':rs});total+=tt;print(c['key'],len(rs),'PASS',flush=True)
assert count==232 and total==10520 and len(result)==16
files=[p for p in D.rglob('*') if p.is_file()];largest=max(files,key=lambda p:p.stat().st_size);big=[str(p.relative_to(D)) for p in files if p.stat().st_size>=100_000_000];assert not big
out={'schema':'nobunaga-selfcontained-delivery-verification-v1','status':'passed','clips':16,'frames':count,'duration_ms':total,'all_gif_hashes_and_timing_match':True,'all_visible_rgba_recomposition_exact':True,'all_alpha_recomposition_exact':True,'all_layer_ownership_disjoint':True,'all_native_dimensions_preserved':True,'largest_expanded_file':{'path':str(largest.relative_to(D)),'bytes':largest.stat().st_size},'expanded_files_at_or_over_100MB':big,'socket_collision_world_displacement_runtime_tested':False,'independent_weapon_swap_tested':False,'clip_results':result}
(D/'validation-final.json').write_text(json.dumps(out,indent=2));print('ALL',count,total,'PASS')
