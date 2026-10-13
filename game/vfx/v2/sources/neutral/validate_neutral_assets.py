"""Analysis only. No generated image is edited by this script."""
from pathlib import Path
import json, hashlib
from PIL import Image
import numpy as np
root=Path(__file__).parent
spec={
 'neutral_slash_arc':([.5,.5],12,170,[.8,1.25],.55,'hand-to-tip rotation; neutral blade path, not an energy projectile'),
 'neutral_thrust_cone':([.834,.516],10,140,[1.5,3.5],.45,'rightmost tip attaches to spear tip; cone opens toward left'),
 'neutral_trail_strip':([.802,.504],9,160,[8,24],.45,'right head follows projectile; tail fades left; velocity determines angle'),
 'neutral_hit_burst':([.5,.5],8,95,[.8,1.2],.65,'impact center; compact short physical scratch burst'),
 'neutral_dust':([.5,.766],18,130,[1.3,2.5],.35,'bottom ground contact; small upward dust puff')
}
manifest={};report={}
for name,(pivot,ticks,size,ratio,opacity,note) in spec.items():
 p=root/(name+'.png');s=root/'sources'/(name+'.png');im=Image.open(p);a=np.array(im.getchannel('A'));bbox=im.getchannel('A').getbbox();x0,y0,x1,y1=bbox
 gutter=min(x0,y0,1024-x1,1024-y1)
 assert im.mode=='RGBA' and im.size==(1024,1024) and gutter>=64
 def sha(q):return hashlib.sha256(q.read_bytes()).hexdigest()
 report[name]={'size':list(im.size),'mode':im.mode,'alpha_bounds_px':list(bbox),'transparent_gutter_min_px':gutter,'fully_transparent_pixel_fraction':float(np.mean(a==0)),'partially_transparent_pixel_fraction':float(np.mean((a>0)&(a<255))),'sha256':sha(p),'source_sha256':sha(s),'source_size':list(Image.open(s).size),'passed':True}
 manifest[name]={'texture':f'res://vfx/v2/art/{name}.png','cell':[1024,1024],'columns':1,'rows':1,'row':0,'frames':1,'frame_count':1,'pivot':pivot,'seam':.5,'split_depth':False,'render_padding':.3,'duration_ticks':ticks,'ticks_per_second':60,'loop':False,'world_size':size,'animation_source':'single_generated_texture_plus_runtime_procedural_motion','blend':'mix','recommended_opacity':opacity,'source_art':f'sources/{name}.png','layout_operation':'Uniform Lanczos fit complete source within 896x896, center on transparent 1024x1024. Preserve generated alpha without threshold, painting, or background removal.','alpha_bounds_px':list(bbox),'origin':'top-left texture coordinates; pivot normalized to final 1024 image','placement_note':note,'recommended_visible_aspect_ratio_range':ratio,'limitations':'Single authored base, not frame-by-frame animation. Visible aspect ratio guidance refers to occupied mark, not square texture dimensions. Pivots are visually measured on generated art. Clamp UV; alpha-mix only, no additive glow.'}
(root/'neutral_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(root/'alpha_validation.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({n:r['transparent_gutter_min_px'] for n,r in report.items()}))
