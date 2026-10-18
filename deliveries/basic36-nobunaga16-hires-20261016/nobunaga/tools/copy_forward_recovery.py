from extract_visible_layers import D,sha
import json,shutil
src=json.load(open(D/'grab_start/layers-visible-manifest.json'));dst=json.load(open(D/'throw_forward/layers-visible-manifest.json'));inv=json.load(open(D/'inventory.json'));rows=next(c for c in inv['clips'] if c['key']=='throw_forward')['source_records']
for i in range(9,19):
 j=rows[i]['reuse_grab_start_frame'];assert sha(D/'grab_start/frames-composite'/f'{j:03}.png')==sha(D/'throw_forward/frames-composite'/f'{i:03}.png')
 old=dst[i];m={**src[j]};m.update({'frame':i,'duration_ms':old['duration_ms'],'source':old['source'],'source_sha256':old['source_sha256'],'identical_master_refinement_source':['grab_start',j]})
 for name in ['body','weapon','hand_occlusion']:
  a=D/'grab_start/layers-visible'/name/f'{j:03}.png';b=D/'throw_forward/layers-visible'/name/f'{i:03}.png';shutil.copy2(a,b);m[name+'_path']=str(b.relative_to(D));m[name+'_sha256']=sha(b)
 for name in ['weapon','hand']:shutil.copy2(D/'grab_start/layers-visible/masks'/f'{j:03}-{name}.png',D/'throw_forward/layers-visible/masks'/f'{i:03}-{name}.png')
 dst[i]=m
(D/'throw_forward/layers-visible-manifest.json').write_text(json.dumps(dst,indent=2));print('copied 10 exact identical recovery frames')
