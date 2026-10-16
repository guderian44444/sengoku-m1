from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
P=Path(__file__).resolve().parents[1];ROOT=P.parents[1];A=['walk','run','hurt','stunned','jump','launched','down','recovering','victory'];L=['body','weapon','hand_occlusion'];out={'scope':'Technical validation only; artwork remains candidate pending user review','actions':{},'transitions':{},'existing_combat':{}}
def eq(a,b):return bool(np.array_equal(np.array(a),np.array(b)))
for act in A:
 D=P/act;m=json.loads((D/'metadata.json').read_text());n=m['frame_count'];errors=[];transparent=True;edge_nonzero=[];partial=[]
 for i in range(n):
  ims=[Image.open(D/'frames'/f'{l}_{i:02}.png').convert('RGBA') for l in L];comp=ims[0].copy()
  for im in ims[1:]:comp.alpha_composite(im)
  if not eq(comp,Image.open(D/'frames'/f'composite_{i:02}.png').convert('RGBA')):errors.append(i)
  for lname,im in zip(L,ims):
   a=np.array(im)[:,:,3];transparent &= bool(a.min()==0)
   if (a[0]>0).any() or (a[-1]>0).any() or (a[:,0]>0).any() or (a[:,-1]>0).any():edge_nonzero.append([i,lname])
   partial.append(int(((a>0)&(a<255)).sum()))
 gif=Image.open(D/f'hideyoshi_{act}_review.gif');dur=sum((gif.seek(i) or gif.info.get('duration',0)) for i in range(gif.n_frames))
 out['actions'][act]={'frames':n,'metadata_duration_ms':m['duration_ms'],'sum_frame_durations_ms':sum(f['duration_ms'] for f in m['frames']),'gif_decoded_frames':gif.n_frames,'gif_decoded_duration_ms':dur,'three_layer_recompose_mismatch_frames':errors,'all_layers_have_transparency':transparent,'nonzero_canvas_edge':edge_nonzero,'partial_alpha_pixel_counts':partial,'world_preview_separate':all(('world_root_translation' in f and 'preview_translation' in f) or ('root_world' in f and 'preview_displacement' in f) for f in m['frames']),'runtime_tested':False}
for a,i,b,j,name in [('launched',5,'down',0,'launched_to_down'),('down',3,'recovering',0,'down_to_recovering')]:
 out['transitions'][name]={l:eq(Image.open(P/a/'frames'/f'{l}_{i:02}.png'),Image.open(P/b/'frames'/f'{l}_{j:02}.png')) for l in L+['composite']}
for act in A:
 m=json.loads((P/act/'metadata.json').read_text())
 for i,f in enumerate(m['frames']):
  if f.get('source')=='approved_idle':
   good={}
   for l,fn in [('body','body_exact_00.png'),('weapon','weapon_exact_00.png'),('hand_occlusion','hand_occlusion_exact_00.png'),('composite','composite_00.png')]:
    im=Image.open(P/act/'frames'/f'{l}_{i:02}.png').convert('RGBA');z=Image.new('RGBA',im.size);z.alpha_composite(Image.open(P/'idle'/fn).convert('RGBA'),(35,80) if im.size==(520,380) else (35,0));good[l]=eq(im,z)
   out['transitions'][act+'_idle_'+str(i)]=good
combat=json.loads((ROOT/'hideyoshi_newspec_20261015/review_manifest.json').read_text());baseline=json.loads((P/'existing_combat_readonly_sha256.json').read_text());changed=[];checked=0
for a in combat['actions']:
 for key in ['gif','representative','metadata']:
  k=a['id']+'/'+key
  if k in baseline:
   checked+=1;actual=hashlib.sha256((ROOT/a[key]).read_bytes()).hexdigest()
   if actual!=baseline[k]:changed.append(k)
out['existing_combat']={'checks':checked,'changed':changed,'unchanged':not changed};out['frame_total']=sum(d['frames'] for d in out['actions'].values());out['technical_pass']=all(not d['three_layer_recompose_mismatch_frames'] and d['all_layers_have_transparency'] and not d['nonzero_canvas_edge'] and d['gif_decoded_frames']==d['frames'] and d['gif_decoded_duration_ms']==d['metadata_duration_ms']==d['sum_frame_durations_ms'] and d['world_preview_separate'] for d in out['actions'].values()) and all(all(v.values()) for v in out['transitions'].values()) and not changed
(P/'technical_audit.json').write_text(json.dumps(out,ensure_ascii=False,indent=2));print(json.dumps(out,ensure_ascii=False,indent=2))
