from pathlib import Path
import json,hashlib
from PIL import Image,ImageChops
R=Path('nobunaga_impact_v4');m=json.load(open(R/'delivery-manifest-hires.json'));out=[]
for c in m['clips']:
 d=R/c['directory'];g=d/c['normal_gif'];rd=d/'frames-review'
 if c['key'] in ['heavy','dash_heavy','air_light','air_heavy']:rd=d.parent/'frames-review'
 if c['key']=='light_2':rd=d/'candidate-f-frames-review'
 if c['key']=='throw_reverse':d=R/'throw_reverse_planted_v2';g=d/'nobunaga-reverse-throw-planted-16f-800ms.gif';rd=d/'frames-review';c['gif_sha256']='eb9e66deb33d9784ffbd90ad30c9a28162326f6404ab536c135c86de84e3c9ec'
 im=Image.open(g);pal=im.copy();dur=[];eq=[];diff=[]
 for i in range(im.n_frames):
  im.seek(i);dur.append(im.info.get('duration'));png=Image.open(rd/f'{i:03}.png').convert('RGB');q=png.quantize(palette=pal,dither=Image.Dither.NONE).convert('RGB');bb=ImageChops.difference(q,im.convert('RGB')).getbbox();eq.append(bb is None);diff.append(bb)
 row=dict(key=c['key'],gif_path=str(g),gif_sha256=hashlib.sha256(g.read_bytes()).hexdigest(),expected_sha256=c['gif_sha256'],sha256_match=hashlib.sha256(g.read_bytes()).hexdigest()==c['gif_sha256'],frames=im.n_frames,duration_ms=sum(dur),durations_ms=dur,review_directory=str(rd),quantized_review_pixels_equal_gif_by_frame=eq,any_difference_bounds=diff)
 out.append(row);print(row['key'],row['sha256_match'],im.n_frames,sum(dur),'review equal',sum(eq),'/',len(eq),flush=True)
Path('nobunaga_final_approved/review-source-verification.json').write_text(json.dumps(out,indent=2))
