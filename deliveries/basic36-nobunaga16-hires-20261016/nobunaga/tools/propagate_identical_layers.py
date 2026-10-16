from extract_visible_layers import D,sha
from pathlib import Path
import json,shutil
catalog={}
for mp in D.glob('*/layers-visible-manifest.json'):
 for m in json.loads(mp.read_text()):
  if m.get('manual_semantic_refinement') or m.get('native_layer_based'):
   src=D/mp.parent.name/'frames-composite'/f"{m['frame']:03}.png";catalog[sha(src)]=(mp.parent.name,m)
for mp in D.glob('*/layers-visible-manifest.json'):
 rows=json.loads(mp.read_text());key=mp.parent.name;changed=False
 for i,m in enumerate(rows):
  if m.get('manual_semantic_refinement') or m.get('native_layer_based'):continue
  h=sha(D/key/'frames-composite'/f'{i:03}.png')
  if h not in catalog:continue
  sk,sm=catalog[h];si=sm['frame'];out=D/key/'layers-visible';sr=D/sk/'layers-visible'
  for name in ['body','weapon','hand_occlusion']:
   shutil.copy2(sr/name/f'{si:03}.png',out/name/f'{i:03}.png');m[name+'_sha256']=sha(out/name/f'{i:03}.png')
  for name in ['weapon','hand']:shutil.copy2(sr/'masks'/f'{si:03}-{name}.png',out/'masks'/f'{i:03}-{name}.png')
  for attr in ['blade_base_art_px','blade_tip_art_px','blade_projected_angle_clockwise_from_right_deg','grip_art_px','additional_hand_regions','manual_semantic_refinement','manual_review_required']:
   if attr in sm:m[attr]=sm[attr]
  m['identical_master_refinement_source']=[sk,si];changed=True;print(key,i,'copied',sk,si)
 if changed:mp.write_text(json.dumps(rows,indent=2))
