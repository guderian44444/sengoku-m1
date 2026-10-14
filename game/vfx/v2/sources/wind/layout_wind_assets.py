"""Rebuild generated wind base layouts and validate alpha; no effect painting/removal."""
from pathlib import Path
import json, math, hashlib
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parent
KINDS = {'arc': (20, 280), 'ring': (30, 420), 'wave': (28, 320), 'hit': (16, 190)}
manifest, validation = {}, {}
for kind, (ticks, world_size) in KINDS.items():
    name = 'wind_' + kind
    source = ROOT / (name + '_source.png')
    src = Image.open(source)
    assert src.mode == 'RGBA', (source, src.mode)
    im = src.copy()
    im.thumbnail((896,896), Image.Resampling.LANCZOS)
    out = Image.new('RGBA', (1024,1024), (0,0,0,0))
    offset = ((1024-im.width)//2, (1024-im.height)//2)
    out.paste(im, offset)
    out.save(ROOT / (name+'.png'))
    a = np.asarray(out.getchannel('A'))
    y,x = np.nonzero(a)
    bbox = [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]
    pivot = [.5,.51] if kind=='ring' else [.5,.5]
    dx,dy = (x+.5)/1024-pivot[0], (y+.5)/1024-pivot[1]
    radius = float(np.hypot(dx,dy).max())
    edge = max(int(a[:64,:].max()),int(a[-64:,:].max()),int(a[:,:64].max()),int(a[:,-64:].max()))
    assert edge == 0
    metric = [.39,.17] if kind=='ring' else [.35,.35]
    ellipse_x = float(np.hypot(dx,dy*metric[0]/metric[1]).max())
    ellipse_y = float(np.hypot(dy,dx*metric[1]/metric[0]).max())
    entry = {'texture':f'res://vfx/v2/art/{name}.png','cell':[1024,1024], 'columns':1,'rows':1,'row':0,'frames':1,'frame_count':1,'pivot':pivot,'seam':pivot[1] if kind=='ring' else .5,'split_depth':kind=='ring','flow_center':pivot,'flow_radius':metric,'render_padding':.3,'duration_ticks':ticks,'loop':False,'world_size':world_size,'animation_source':'single_generated_texture_plus_runtime_procedural_motion','blend':'mix','source_art':name+'_source.png','layout_operation':'Uniform Lanczos fit complete source within 896x896, center on transparent 1024x1024. Alpha retained; no thresholding, background removal, paint, or recoloring.','alpha_bounds_px':bbox,'origin':'top-left; normalized pivot/seam/flow_center in final 1024 texture coordinates','limitations':'One generated base, not an authored frame sequence or seamless loop. Flow radius is a visual centerline estimate, not alpha bounds. Ring depth split is a planar approximation. render_padding=.3 is a runtime starting value; elliptical UV warp must be validated against full alpha support, including faint dust. Clamp outside original UV; never repeat texture.'}
    manifest[name] = entry
    validation[name]={'mode':out.mode,'source_size':list(src.size),'final_size':list(out.size),'alpha_extrema':[int(a.min()),int(a.max())],'alpha_bounds_px':bbox,'transparent_gutters_ltrb':[bbox[0],bbox[1],1024-bbox[2],1024-bbox[3]],'outer_64px_alpha_max':edge,'transparent_pixel_fraction':float(np.mean(a==0)),'partial_alpha_pixel_fraction':float(np.mean((a>0)&(a<255))),'full_alpha_rotation_radius_uv':radius,'euclidean_rotation_required_total_canvas_scale_for_64px_margin':2*(radius+.0625),'elliptical_rotation_max_extent_from_pivot_uv':[ellipse_x,ellipse_y],'elliptical_rotation_required_total_canvas_scale_for_64px_margin':2*(max(ellipse_x,ellipse_y)+.0625),'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'final_sha256':hashlib.sha256((ROOT/(name+'.png')).read_bytes()).hexdigest(),'validation_note':'Bounds include every nonzero alpha pixel. Rotation extents analytically bound all angles, but actual runtime shader/mesh distortion still requires its own sweep QA.'}

(ROOT/'wind_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
(ROOT/'alpha_validation.json').write_text(json.dumps(validation,indent=2)+'\n')
print(json.dumps(validation,indent=2))
