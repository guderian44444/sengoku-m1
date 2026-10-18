from pathlib import Path
from PIL import Image
import numpy as np,json,hashlib
P=Path(__file__).resolve().parents[1];D=P/'idle';L=['body','weapon','hand_occlusion']
b=Image.open(D/'body_canvas_00.png').convert('RGBA');w=Image.open(D/'weapon_00.png').convert('RGBA');c=Image.open(D/'composite_00.png').convert('RGBA');ba=np.array(b);wa=np.array(w);ca=np.array(c);mask=np.any(np.array(Image.alpha_composite(b,w))!=ca,axis=2)
ha=np.zeros_like(ca);ha[mask]=ca[mask];ba[mask]=0;wa[mask]=0
for name,a in [('body',ba),('weapon',wa),('hand_occlusion',ha)]:Image.fromarray(a).save(D/(name+'_exact_00.png'))
r=Image.alpha_composite(Image.alpha_composite(Image.fromarray(ba),Image.fromarray(wa)),Image.fromarray(ha));assert np.array_equal(np.array(r),ca)
m=json.loads((D/'metadata.json').read_text());m['canonical_registered_files_unchanged']=True;m['frame'].update({l:l+'_exact_00.png' for l in L});m['runtime_layer_export']={'split_method':'At only pixels where body+weapon differs from approved composite, remove lower layers and place exact canonical composite pixels in hand occlusion. This avoids duplicate semi-transparent hand alpha.','affected_pixels':int(mask.sum()),'canonical_composite_pixel_exact':True,'original_registered_pngs_retained':True,'render_order':L};m['note']='Canonical composite byte-for-byte copy. Original registered PNGs retained. Exact runtime layer exports re-split existing pixels without redraw.';(D/'metadata.json').write_text(json.dumps(m,ensure_ascii=False,indent=2))
for act in ['hurt','jump','launched','recovering','victory']:
 M=P/act/'metadata.json';m=json.loads(M.read_text())
 for i,f in enumerate(m['frames']):
  if f.get('source')!='approved_idle':continue
  size=tuple(m['canvas']);shift=(35,80) if size==(520,380) else (35,0)
  for layer in L:
   im=Image.new('RGBA',size);im.alpha_composite(Image.open(D/(layer+'_exact_00.png')).convert('RGBA'),shift);im.save(P/act/'frames'/f'{layer}_{i:02}.png')
  f['idle_runtime_layer_export']='../idle/*_exact_00.png';f['composite_unchanged']=True
 m['quality_notes'].append('Approved idle entry/exit composite unchanged; runtime three-layer split repaired to exact recomposition with no double-alpha hand overlay.')
 M.write_text(json.dumps(m,ensure_ascii=False,indent=2))
print('idle hand patch pixels',int(mask.sum()))
